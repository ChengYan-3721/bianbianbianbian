import 'dart:async';
import 'dart:ui' as ui;

import 'package:bianbianbianbian/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:home_widget/home_widget.dart';

import '../features/compliance/privacy_consent_gate.dart';
import '../features/lock/app_lock_overlay.dart';
import '../features/lock/app_lock_providers.dart';
import '../data/repository/providers.dart'
    show
        currentLedgerIdProvider,
        ledgerRepositoryProvider,
        transactionRepositoryProvider;
import '../features/settings/widget_data_service.dart';
import '../features/sync/sync_trigger.dart';
import 'app_router.dart';
import '../features/settings/settings_providers.dart';

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
    this.enablePrivacyConsentGate = true,
  });

  final bool enableSyncLifecycle;

  /// Step 14.3：测试可关闭。生产恒为 true。
  final bool enableAppLockGuard;

  /// Step 17.3：测试可关闭。生产恒为 true。widget 测试中若不需要走完整
  /// 隐私同意流程（默认状态：未同意），可关闭本 gate 直接进入主界面。
  /// 另一种方式是通过 `SharedPreferences.setMockInitialValues` 把同意
  /// 状态预置为已同意；两种手段择一使用。
  final bool enablePrivacyConsentGate;

  @override
  ConsumerState<BianBianApp> createState() => _BianBianAppState();
}

class _BianBianAppState extends ConsumerState<BianBianApp>
    with WidgetsBindingObserver {
  bool _observerRegistered = false;
  bool _privacySnapshotShieldVisible = false;
  bool _androidSecureFlagRelaxedForSnapshot = false;
  bool _androidSecureFlagRelaxScheduled = false;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observerRegistered = true;
    // 不能在 initState 同步阶段读 provider（未 mount 完成前读会被 Riverpod
    // 警告）。延迟到首帧后再启动。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Step 16.3：检测是否从桌面小组件点击启动，是则跳转到新建记账页。
      // 延迟 2 帧确保 GoRouter 的 InheritedGoRouter 完全挂载后再导航，
      // 否则会触发 Duplicate GlobalKey / _debugLocked 断言。
      _scheduleWidgetDeepLink();
      // Step 16.3：监听运行中从小组件点击回来的事件。
      _listenWidgetClicks();
      if (!widget.enableSyncLifecycle) return;
      final trigger = ref.read(syncTriggerProvider.notifier);
      // 启动同步——内部已经做了 try/catch，不会冒烟。
      unawaited(trigger.trigger());
      // 前台启动 → 启 15 分钟定时器。后台时由生命周期回调停。
      trigger.startPeriodic();
    });
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
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
    _handleAndroidPrivacySnapshotLifecycle(state);
    if (widget.enableSyncLifecycle) {
      final trigger = ref.read(syncTriggerProvider.notifier);
      switch (state) {
        case AppLifecycleState.resumed:
          unawaited(trigger.trigger());
          trigger.startPeriodic();
          // Step 16.3：前台恢复时刷新小组件数据——用户可能在后台
          // 通过其他设备同步了新流水，回来后小组件应立即更新。
          unawaited(_updateWidgetData());
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
          // Android 在多任务/失焦场景可能只短暂进入 inactive；把它作为后台计时
          // 起点，才能覆盖从多任务界面停留超过阈值后切回的路径。iOS 的 inactive
          // 仍按短暂打断处理，避免来电/控制中心下拉造成误锁。
          if (defaultTargetPlatform == TargetPlatform.android) {
            guard.onPaused();
          }
          break;
      }
    }
  }

  /// Android 隐私模式折中方案：
  /// - 前台常态保持 FLAG_SECURE，阻止直接截屏 / 录屏；
  /// - 进入多任务 / 后台前先盖 Flutter 模糊遮罩，下一帧临时清掉 FLAG_SECURE，
  ///   让系统 task snapshot 尽量捕获"模糊后的画面"；
  /// - 回前台时先恢复 FLAG_SECURE，再撤遮罩。
  ///
  /// 这是 best-effort：系统抓取 task snapshot 的时机由 Android / 厂商 ROM 决定，
  /// 无法做到与 FLAG_SECURE 一样的强一致保证。
  void _handleAndroidPrivacySnapshotLifecycle(AppLifecycleState state) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _restoreAndroidSecureFlagAfterSnapshot();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _prepareAndroidPrivacySnapshot();
    }
  }

  bool _privacyModeEnabledSync() {
    return ref
        .read(privacyModeProvider)
        .maybeWhen(data: (enabled) => enabled, orElse: () => false);
  }

  bool _appLockCurrentlyLocked() {
    return widget.enableAppLockGuard && ref.read(appLockGuardProvider).isLocked;
  }

  void _prepareAndroidPrivacySnapshot() {
    if (!_privacyModeEnabledSync()) return;
    if (_appLockCurrentlyLocked()) return;
    if (!_privacySnapshotShieldVisible && mounted) {
      setState(() => _privacySnapshotShieldVisible = true);
    }
    if (_androidSecureFlagRelaxedForSnapshot ||
        _androidSecureFlagRelaxScheduled) {
      return;
    }

    _androidSecureFlagRelaxScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_androidSecureFlagRelaxScheduled ||
          !mounted ||
          !_privacySnapshotShieldVisible ||
          !_privacyModeEnabledSync()) {
        return;
      }
      _androidSecureFlagRelaxScheduled = false;
      _androidSecureFlagRelaxedForSnapshot = true;
      unawaited(ref.read(privacyModeServiceProvider).setEnabled(false));
    });
  }

  void _restoreAndroidSecureFlagAfterSnapshot() {
    if (!_privacySnapshotShieldVisible &&
        !_androidSecureFlagRelaxedForSnapshot &&
        !_androidSecureFlagRelaxScheduled) {
      return;
    }

    _androidSecureFlagRelaxScheduled = false;
    final shouldRestoreSecureFlag =
        _androidSecureFlagRelaxedForSnapshot && _privacyModeEnabledSync();
    _androidSecureFlagRelaxedForSnapshot = false;

    void hideShield() {
      if (!mounted || !_privacySnapshotShieldVisible) return;
      setState(() => _privacySnapshotShieldVisible = false);
    }

    if (shouldRestoreSecureFlag) {
      unawaited(
        ref
            .read(privacyModeServiceProvider)
            .setEnabled(true)
            .whenComplete(hideShield),
      );
    } else {
      hideShield();
    }
  }

  /// Step 16.3：前台恢复时刷新小组件数据。
  Future<void> _updateWidgetData() async {
    try {
      final ledgerId = await ref.read(currentLedgerIdProvider.future);
      final txRepo = await ref.read(transactionRepositoryProvider.future);
      final ledgerRepo = await ref.read(ledgerRepositoryProvider.future);
      await WidgetDataService.computeAndRefresh(
        ledgerId: ledgerId,
        txRepo: txRepo,
        ledgerRepo: ledgerRepo,
      );
    } catch (_) {
      // 静默
    }
  }

  /// Step 16.3：延迟检测从桌面小组件启动时的深链并导航。
  ///
  /// 必须等待 GoRouter widget 树完全稳定后再导航，否则会触发
  /// Duplicate GlobalKey（InheritedGoRouter 重复挂载）或
  /// `_debugLocked` 断言。延迟 2 帧（首帧 postFrameCallback +
  /// 再一帧 addPostFrameCallback）确保路由器完全就绪。
  void _scheduleWidgetDeepLink() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleWidgetDeepLink();
      });
    });
  }

  /// Step 16.3：检测从桌面小组件启动时的深链并导航。
  ///
  /// [HomeWidget.initiallyLaunchedFromHomeWidget] 在 App 冷启动由小组件
  /// 点击触发时返回非 null Uri。路径匹配 `/record/new` → go_router 跳转。
  Future<void> _handleWidgetDeepLink() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null && uri.path == '/record/new' && mounted) {
        ref.read(goRouterProvider).go('/record/new');
      }
    } catch (_) {
      // 非 iOS / Android
    }
  }

  /// Step 16.3：监听 App 运行中从小组件点击回来的事件。
  ///
  /// [HomeWidget.widgetClicked] 是一个 [Stream]，App 在前台时用户
  /// 点击小组件，系统会通过此 stream 推送 URI。
  void _listenWidgetClicks() {
    try {
      _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
        if (uri != null && uri.path == '/record/new') {
          // 延迟 1 帧避免 navigator 锁定状态
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ref.read(goRouterProvider).go('/record/new');
          });
        }
      }, onError: (_) {});
    } catch (_) {
      // 非 iOS / Android
    }
  }

  @override
  Widget build(BuildContext context) {
    // Step 15.1：主题由 provider 驱动，切换后即时变色。
    final theme = ref.watch(currentThemeProvider);
    return MaterialApp.router(
      title:
          '边边记账', // i18n-exempt: app title used before localization is available
      theme: theme,
      routerConfig: ref.watch(goRouterProvider),
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
        if (widget.enablePrivacyConsentGate) {
          // Step 17.3：套在最外层——同意页必须先于应用锁、底栏出现，
          // 否则首次启动的新用户会被 PIN/解锁页卡死而看不到政策。
          child = PrivacyConsentGate(child: child);
        }
        child = _PrivacySnapshotGate(
          visible: _privacySnapshotShieldVisible,
          child: child,
        );
        return child;
      },
    );
  }
}

/// Android 隐私模式的多任务快照遮罩。
///
/// 外层 gate 常驻，避免切换遮罩时重建 / 迁移锁屏页；真正的模糊层只在 App
/// 失焦 / 进入后台时短暂挂上，让 task snapshot 捕获模糊后的画面。
class _PrivacySnapshotGate extends StatelessWidget {
  const _PrivacySnapshotGate({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surface.withValues(alpha: 0.72);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: IgnorePointer(
              key: const ValueKey('privacy_snapshot_shield'),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: ColoredBox(color: color),
                ),
              ),
            ),
          ),
      ],
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
    final isLocked = ref.watch(appLockGuardProvider.select((s) => s.isLocked));
    return Stack(
      fit: StackFit.expand,
      children: [child, if (isLocked) const AppLockOverlay()],
    );
  }
}
