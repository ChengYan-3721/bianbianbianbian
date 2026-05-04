import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/sync/sync_trigger.dart';
import 'app_router.dart';
import 'app_theme.dart';

/// 应用根组件。
///
/// Step 10.7：升级为 [ConsumerStatefulWidget] + [WidgetsBindingObserver]，
/// 在 App 启动 / 前台恢复 / 后台 三个生命周期点上调度同步任务：
///
/// - `initState` → 触发一次启动同步 + 启动 15 分钟定期 timer；
/// - `didChangeAppLifecycleState(resumed)` → 触发一次前台恢复同步 + 重新启动
///   定期 timer；
/// - `didChangeAppLifecycleState(paused | detached)` → 停止定期 timer，避免
///   在后台持续耗电；
///
/// 触发本身由 [SyncTrigger] 内置的「前一次未完成则跳过」/「未配置云服务则
/// 跳过」/「网络错误归一化」三大不变量兜底，调用方 fire-and-forget 即可。
///
/// `enableSyncLifecycle` 让 widget 测试可以关闭这套行为——避免 test 环境
/// 下 `syncServiceProvider` 链触达 `SharedPreferences` 时抛
/// `MissingPluginException`，以及悬挂的 `Timer.periodic` 让
/// `tester.pumpAndSettle()` 报"Timer still pending"。
class BianBianApp extends ConsumerStatefulWidget {
  const BianBianApp({super.key, this.enableSyncLifecycle = true});

  final bool enableSyncLifecycle;

  @override
  ConsumerState<BianBianApp> createState() => _BianBianAppState();
}

class _BianBianAppState extends ConsumerState<BianBianApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (!widget.enableSyncLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    // 不能在 initState 同步阶段读 provider（未 mount 完成前读会被 Riverpod
    // 警告）。延迟到首帧后再启动。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final trigger = ref.read(syncTriggerProvider.notifier);
      // 启动同步——内部已经做了 try/catch，不会冒烟。
      unawaited(trigger.trigger());
      // 前台启动 → 启 15 分钟定时器。后台时由生命周期回调停。
      trigger.startPeriodic();
    });
  }

  @override
  void dispose() {
    if (widget.enableSyncLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      // 显式停一下定时器——Notifier 的 ref.onDispose 在 ProviderContainer
      // 关闭时才会跑，而生产路径 BianBianApp 拆掉时 container 仍存活。
      // ignore: avoid_ref_inside_state_dispose
      ref.read(syncTriggerProvider.notifier).cancelTimers();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enableSyncLifecycle) return;
    final trigger = ref.read(syncTriggerProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(trigger.trigger());
        trigger.startPeriodic();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        trigger.stopPeriodic();
      case AppLifecycleState.inactive:
        // 短暂态（如来电覆盖），不动定时器。
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '边边记账',
      theme: appTheme,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
