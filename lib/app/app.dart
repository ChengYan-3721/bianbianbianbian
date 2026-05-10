import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/lock/app_lock_overlay.dart';
import '../features/lock/app_lock_providers.dart';
import '../features/sync/sync_trigger.dart';
import 'app_router.dart';
import '../features/settings/settings_providers.dart';/// 应用根组件。
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
///
/// Step 14.3：在 `didChangeAppLifecycleState` 里追加 [AppLockGuard.onPaused] /
/// [AppLockGuard.onResumed] 调用——前台锁屏的"后台超时"判定由 guard 自己负责，
/// 这里只把生命周期事件原样转发；冷启动锁由 main.dart 在 bootstrap 末尾显式调
/// `guard.lock()`。`enableAppLockGuard` 让 widget 测试关掉这套行为——避免锁屏
/// overlay 干扰其他 feature 的 widget 测试。
class BianBianApp extends ConsumerStatefulWidget {
  const BianBianApp({
    super.key,
    this.enableSyncLifecycle = true,
    this.enableAppLockGuard = true,
  });

  final bool enableSyncLifecycle;

  /// Step 14.3：测试可关闭。生产恒为 true。
  final bool enableAppLockGuard;

  @override
  ConsumerState<BianBianApp> createState() => _BianBianAppState();
}

class _BianBianAppState extends ConsumerState<BianBianApp>
    with WidgetsBindingObserver {
  bool _observerRegistered = false;

  @override
  void initState() {
    super.initState();
    if (widget.enableSyncLifecycle || widget.enableAppLockGuard) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    if (!widget.enableSyncLifecycle) return;
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
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
    if (widget.enableSyncLifecycle) {
      // 显式停一下定时器——Notifier 的 ref.onDispose 在 ProviderContainer
      // 关闭时才会跑，而生产路径 BianBianApp 拆掉时 container 仍存活。
      // ignore: avoid_ref_inside_state_dispose
      ref.read(syncTriggerProvider.notifier).cancelTimers();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.enableSyncLifecycle) {
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
    if (widget.enableAppLockGuard) {
      final guard = ref.read(appLockGuardProvider.notifier);
      switch (state) {
        case AppLifecycleState.resumed:
          guard.onResumed();
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          guard.onPaused();
        case AppLifecycleState.inactive:
          // inactive 是 iOS 的"短暂打断"（来电覆盖、控制中心下拉等）——不算真正
          // 的后台进入，不更新 lastBackgroundedAt 避免误锁。Android 没有 inactive
          // 态，paused 直接打头。
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Step 15.1：主题由 provider 驱动，切换后即时变色。
    final theme = ref.watch(currentThemeProvider);
    return MaterialApp.router(
      title: '边边记账',
      theme: theme,
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
      // Step 15.2：字号调节 + 应用锁 overlay。
      // 字号覆盖需包在 router child 之上，这样全 app 所有 widget 都能
      // 通过 MediaQuery.textScalerOf 读到缩放后的值。应用锁 overlay 叠
      // 在最外层，锁屏时遮挡一切内容。
      builder: (context, child) {
        child = child ?? const SizedBox.shrink();
        // 字号缩放：app 因子 × 系统 TextScaler。
        final scaleFactor = ref.watch(fontSizeScaleFactorProvider);
        final systemScaler = MediaQuery.textScalerOf(context);
        child = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              systemScaler.scale(1.0) * scaleFactor,
            ),
          ),
          child: child,
        );
        if (widget.enableAppLockGuard) {
          child = _AppLockGate(child: child);
        }
        return child;
      },
    );
  }
}

/// Step 14.3：套在 router child 之上的锁屏门。
///
/// 设计上仅消费 `appLockGuardProvider.select((s) => s.isLocked)` 一项 bool——
/// `lastBackgroundedAt` / 内部 timeoutSeconds 变化都不应触发 rebuild，避免每次
/// paused 都重建整棵子树。
class _AppLockGate extends ConsumerWidget {
  const _AppLockGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked =
        ref.watch(appLockGuardProvider.select((s) => s.isLocked));
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isLocked) const AppLockOverlay(),
      ],
    );
  }
}
