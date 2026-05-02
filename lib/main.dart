import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'app/app.dart';
import 'data/local/providers.dart';
import 'features/settings/settings_providers.dart';

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
