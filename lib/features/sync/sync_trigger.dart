import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/providers.dart' show currentLedgerIdProvider;
import 'sync_provider.dart';
import 'sync_service.dart';

/// Step 10.7：同步触发结果。
enum SyncTriggerOutcome {
  /// 同步成功（本次执行了一次 upload）。
  success,

  /// 失败，且原因被识别为网络问题（断网 / DNS / TLS / timeout）。
  networkUnavailable,

  /// 其它失败（鉴权 / 服务端 4xx/5xx / 序列化等）。
  failure,

  /// 跳过——前一次同步未完成。
  skipped,

  /// 跳过——当前未配置或未激活云服务。
  notConfigured,
}

class SyncTriggerResult {
  const SyncTriggerResult({required this.outcome, this.message});

  final SyncTriggerOutcome outcome;
  final String? message;

  bool get isSuccess => outcome == SyncTriggerOutcome.success;
  bool get isFailure =>
      outcome == SyncTriggerOutcome.failure ||
      outcome == SyncTriggerOutcome.networkUnavailable;
}

/// Step 10.7：同步调度器对外暴露的状态。
///
/// UI 通过 `ref.watch(syncTriggerProvider)` 订阅，用于在首页顶栏渲染状态
/// 圆点 / 上次同步时间 / 错误徽标。
class SyncTriggerState {
  const SyncTriggerState({
    required this.isRunning,
    required this.isConfigured,
    this.lastSyncedAt,
    this.lastError,
  });

  /// 当前是否有同步任务在执行。
  final bool isRunning;

  /// 当前是否激活了非 `local` 后端。仅供 UI 决定要不要展示状态徽标。
  final bool isConfigured;

  /// 最近一次同步成功的本地时间。
  final DateTime? lastSyncedAt;

  /// 最近一次同步失败的可读消息。成功后清空。
  final String? lastError;

  static const SyncTriggerState idle = SyncTriggerState(
    isRunning: false,
    isConfigured: false,
  );

  SyncTriggerState copyWith({
    bool? isRunning,
    bool? isConfigured,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
    bool clearLastSyncedAt = false,
  }) {
    return SyncTriggerState(
      isRunning: isRunning ?? this.isRunning,
      isConfigured: isConfigured ?? this.isConfigured,
      lastSyncedAt:
          clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncTriggerState &&
          other.isRunning == isRunning &&
          other.isConfigured == isConfigured &&
          other.lastSyncedAt == lastSyncedAt &&
          other.lastError == lastError;

  @override
  int get hashCode => Object.hash(
        isRunning,
        isConfigured,
        lastSyncedAt,
        lastError,
      );
}

typedef SyncTriggerClock = DateTime Function();

/// Step 10.7：把"5 个触发源"统一在同一个调度器下：
///
/// - App 启动 / 前台恢复（lifecycle 在 [BianBianApp] 调用 [trigger]）；
/// - 记账后保存（`record_new_providers.save` 调用 [scheduleDebounced]）；
/// - 首页下拉刷新（`record_home_page` 调用 [trigger] 并消费返回结果展示
///   SnackBar）；
/// - 15 分钟定时器（lifecycle resumed 时启 [startPeriodic] / paused 时
///   [stopPeriodic]）。
///
/// 三大不变量：
///
/// 1. **前一次未完成则跳过**——内部 `_running` 标记，命中则返回
///    [SyncTriggerOutcome.skipped]，不堆叠 upload。
/// 2. **未配置云服务则跳过**——读取 [syncServiceProvider]，遇到
///    [LocalOnlySyncService] 直接返回 [SyncTriggerOutcome.notConfigured]，
///    不抛异常打断调用方。
/// 3. **网络错误归一化**——[SocketException] 与常见 `Failed host lookup` /
///    `Connection refused` / `handshake` / `timeout` 文本都归类为
///    [SyncTriggerOutcome.networkUnavailable]，UI 据此显示「网络不可用」。
///
/// 任何意外异常（含 `MissingPluginException` 等测试环境下的平台报错）
/// 都被外层 try/catch 兜住——保证调用方 `unawaited(trigger(...))` 永远
/// 不冒烟。
class SyncTrigger extends Notifier<SyncTriggerState> {
  SyncTrigger({SyncTriggerClock? clock}) : _clock = clock ?? DateTime.now;

  final SyncTriggerClock _clock;
  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _running = false;

  @override
  SyncTriggerState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _periodicTimer?.cancel();
    });
    return SyncTriggerState.idle;
  }

  /// 主入口：执行一次 upload。所有触发路径最终都汇聚到这里。
  Future<SyncTriggerResult> trigger() async {
    if (_running) {
      // i18n-exempt: needs refactoring for l10n (Notifier has no BuildContext)
      return const SyncTriggerResult(
        outcome: SyncTriggerOutcome.skipped,
        message: '同步进行中',
      );
    }
    _running = true;
    state = state.copyWith(isRunning: true);
    try {
      final service = await ref.read(syncServiceProvider.future);
      if (service is LocalOnlySyncService) {
        state = state.copyWith(
          isRunning: false,
          isConfigured: false,
          clearError: true,
        );
        // i18n-exempt: needs refactoring for l10n (Notifier has no BuildContext)
        return const SyncTriggerResult(
          outcome: SyncTriggerOutcome.notConfigured,
          message: '未配置云服务',
        );
      }
      final ledgerId = await ref.read(currentLedgerIdProvider.future);
      await service.upload(ledgerId: ledgerId);
      service.clearCache();
      state = state.copyWith(
        isRunning: false,
        isConfigured: true,
        lastSyncedAt: _clock(),
        clearError: true,
      );
      return const SyncTriggerResult(outcome: SyncTriggerOutcome.success);
    } catch (e) {
      // i18n-exempt: needs refactoring for l10n (Notifier has no BuildContext)
      final isNet = _isNetworkError(e);
      final msg = isNet ? '网络不可用' : e.toString();
      state = state.copyWith(
        isRunning: false,
        lastError: msg,
      );
      return SyncTriggerResult(
        outcome: isNet
            ? SyncTriggerOutcome.networkUnavailable
            : SyncTriggerOutcome.failure,
        message: msg,
      );
    } finally {
      _running = false;
    }
  }

  /// 记账后调用：N 秒静默防抖。重复调用会重置计时器，连续记账只触发最后一次。
  void scheduleDebounced({
    Duration delay = const Duration(seconds: 5),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      // 故意不 await——防抖回调脱离调用栈、丢弃返回值即可。
      // 内部已 try/catch，所有异常被吞掉，不会冒烟。
      // ignore: discarded_futures
      trigger();
    });
  }

  /// lifecycle resumed 时启动；paused 时 [stopPeriodic]。多次调用安全：
  /// 旧计时器先取消再重建，不会叠加触发频率。
  void startPeriodic({
    Duration interval = const Duration(minutes: 15),
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) {
      // ignore: discarded_futures
      trigger();
    });
  }

  void stopPeriodic() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// 显式取消所有内部计时器。生产路径由 [BianBianApp.dispose] 调用，
  /// 让 widget 树拆掉时立即停掉同步定时器（不必等到 ProviderContainer
  /// 关闭，那要冷启动重启才会发生）。
  void cancelTimers() {
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    _debounceTimer = null;
    _periodicTimer = null;
  }

  bool _isNetworkError(Object e) {
    if (e is SocketException) return true;
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('connection closed') ||
        s.contains('handshakeexception') ||
        s.contains('timeoutexception') ||
        s.contains('network is unreachable') ||
        s.contains('no address associated');
  }
}

/// `keepAlive` 默认（NotifierProvider 不带 autoDispose）。整个 App 生命
/// 周期内单例，承载防抖/定期定时器与 [SyncTriggerState]。
final syncTriggerProvider =
    NotifierProvider<SyncTrigger, SyncTriggerState>(() => SyncTrigger());
