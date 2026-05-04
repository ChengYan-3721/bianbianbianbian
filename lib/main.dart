import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'app/app.dart';
import 'data/local/providers.dart';
import 'features/settings/settings_providers.dart';
import 'features/sync/attachment/attachment_orphan_sweeper.dart';
import 'features/sync/attachment/attachment_providers.dart';
import 'features/trash/trash_gc_service.dart';
import 'features/trash/trash_providers.dart';

Future<void> main() async {
  // path_provider / flutter_secure_storage 在 runApp 前就会被 AppDatabase 打开，
  // 必须先初始化绑定。
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1.5 + 1.7：bootstrap 路径走 Riverpod。独立 ProviderContainer 先于 runApp
  // 存在——我们用它预热 defaultSeedProvider.future，连锁触发：
  //   defaultSeedProvider → deviceIdProvider → appDatabaseProvider →
  //   AppDatabase() 构造 → SQLCipher PRAGMA key + cipher_version smoke test →
  //   LocalDeviceIdStore.loadOrCreate() → DefaultSeeder.seedIfEmpty()。
  // 任一环抛错都冒泡到 catch，由兜底页展示 stack trace。
  //
  // 若首帧顺利，container 直接交给 UncontrolledProviderScope——main 里初始化
  // 的 provider 状态（AppDatabase 实例 + 已 cache 的 deviceId / seed AsyncData）
  // 会被 Widget 树复用，而不是被 ProviderScope 再建一次、重开一次 DB。
  final container = ProviderContainer();
  try {
    await container.read(defaultSeedProvider.future);
    // Step 8.3：fire-and-forget 触发汇率刷新。每日节流 + 失败静默；不阻塞首帧。
    // 成功后 invalidate fxRates / fxRateRows 让任何已 mount 的页面拿到新值。
    unawaited(
      container
          .read(fxRateRefreshServiceProvider)
          .refreshIfDue()
          .then((ok) {
        if (!ok) return;
        container.invalidate(fxRatesProvider);
        container.invalidate(fxRateRowsProvider);
      }).catchError((_) {/* 静默降级 */}),
    );
    // Step 12.3：垃圾桶定时清理。冷启动时跑一次"硬删 deleted_at < now-30d 的
    // 全部软删项 + 清流水附件目录"。失败静默——不影响首帧。
    unawaited(
      container.read(trashGcServiceProvider.future).then((service) async {
        final report = await service.gcExpired(now: DateTime.now());
        if (report.isEmpty) return;
        // GC 真实清理了数据 → invalidate 受影响 provider 让首屏拿到最新视图。
        container.invalidate(trashedTransactionsProvider);
        container.invalidate(trashedCategoriesProvider);
        container.invalidate(trashedAccountsProvider);
        container.invalidate(trashedLedgersProvider);
        container.invalidate(trashedBudgetsProvider);
      }).catchError((_) {/* 静默降级 */}),
    );
    // Step 11.3：附件缓存淘汰。冷启动跑一次 LRU prune（500MiB 软上限），
    // 失败静默——cache 目录不存在或 IO 错误不影响首帧。pruner 内部保留 7 天
    // 内访问过的文件，即便仍超上限也不再清。
    unawaited(
      container
          .read(attachmentCachePrunerProvider.future)
          .then<void>((pruner) async {
        await pruner.prune();
      }).catchError((_) {/* 静默降级 */}),
    );
    // Step 11.4：远端附件孤儿对象 sweep。冷启动 +5 分钟延迟触发，避免与
    // bootstrap 链 / 首帧渲染抢资源；7 天节流（用 SharedPreferences 记录上次
    // 完成时间）。failure / 超时 / 未配置云服务 一律静默。
    unawaited(_scheduleOrphanSweep(container));
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const BianBianApp(),
      ),
    );
  } catch (error, stack) {
    container.dispose();
    // 同步印到 logcat，方便 `adb logcat | grep flutter`。
    // ignore: avoid_print
    print('[bianbian] DB bootstrap failed: $error\n$stack');
    // 错误兜底页虽然不消费任何 provider，也仍旧包一层 ProviderScope——
    // 保持"任何 runApp 都在 ProviderScope 下"的基线（riverpod_lint 的
    // `missing_provider_scope` 规则对 catch 分支同样会扫到）。
    runApp(
      ProviderScope(child: _BootstrapErrorApp(error: error, stack: stack)),
    );
  }
}

/// Step 11.4：附件孤儿 sweep 的延迟 + 节流调度——抽出顶层函数以便 main 干净。
///
/// **延迟 5 分钟**：sweep 调用 `listBinary` 走完整云端目录递归，IO 量最大。
/// 冷启动头几分钟 App 在加载 UI / 首次同步 / 拉账户 etc，不能与之抢网卡。
///
/// **7 天节流**：用 [SharedPreferences] 持久化 `kLastOrphanSweepAtPrefKey`
/// 字段（epoch ms）。冷启动检查"上次 sweep < now-7d 才真跑"——避免每次
/// 冷启动都 IO 重发现。
///
/// 任意环节失败 / 未配置云服务 / [SharedPreferences] 异常 → 静默吞掉。
/// sweep 是 best-effort 后台任务，失败下次再试。
Future<void> _scheduleOrphanSweep(ProviderContainer container) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(kLastOrphanSweepAtPrefKey);
    final now = DateTime.now();
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (now.difference(last) < kOrphanSweepInterval) {
        return; // 7 天节流命中，跳过本轮
      }
    }
    // 5 分钟延迟——给 App 启动让路。
    await Future<void>.delayed(const Duration(minutes: 5));
    final sweeper =
        await container.read(attachmentOrphanSweeperProvider.future);
    if (sweeper == null) return; // 未配置云服务
    final report = await sweeper.sweep(now: DateTime.now());
    debugPrint('AttachmentOrphanSweeper: $report');
    await prefs.setInt(
      kLastOrphanSweepAtPrefKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (_) {
    // 静默——后台任务失败不应影响 App。
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF4F4),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DB bootstrap failed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB00020),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText('$error'),
                  const SizedBox(height: 12),
                  SelectableText(
                    '$stack',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
