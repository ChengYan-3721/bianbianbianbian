import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'biometric_authenticator.dart';
import 'pin_credential.dart';
import 'privacy_mode_service.dart';

/// Step 14.1：应用锁的 Riverpod provider 链。
///
/// 不走 `@riverpod` codegen——参考 `sync_provider.dart` 同样选择，避免再产
/// `.g.dart`，且本模块的 provider 都是稳定结构，没有 family 也没有需要 codegen
/// 协助的 future Notifier 形态。
///
/// 链：
///   pinCredentialStoreProvider
///     └─ appLockEnabledProvider (`FutureProvider<bool>`)
///     └─ pinAttemptSessionProvider (`StateNotifierProvider<PinAttemptSession,`
///                                    `PinAttemptState>`)
/// AppLock 写入路径（`AppLockController`）走 [appLockControllerProvider]——它持
/// 有 store 引用，提供 `setupPin / changePin / disable` 等命令式 API；UI 调用后
/// 显式 `ref.invalidate(appLockEnabledProvider)` 触发开关 UI 重建。

/// PIN 失败上限，超过即进入冷却。
const int kPinFailureLimit = 3;

/// 冷却时长——错误 [kPinFailureLimit] 次后的拉黑窗口。
const Duration kPinCooldownDuration = Duration(seconds: 30);

/// 时间钩子——测试可注入固定时钟避免 flaky；生产默认 `DateTime.now`。
typedef AppLockClock = DateTime Function();

final appLockClockProvider = Provider<AppLockClock>((ref) => DateTime.now);

/// 凭据持久化层。生产为 [FlutterSecurePinCredentialStore]，测试通过
/// `ProviderContainer.test(overrides: [pinCredentialStoreProvider.overrideWithValue(...)])`
/// 注入 [InMemoryPinCredentialStore]。
final pinCredentialStoreProvider = Provider<PinCredentialStore>((ref) {
  return const FlutterSecurePinCredentialStore();
});

/// 是否启用应用锁——读 [PinCredentialStore.readEnabled]。
///
/// 真值源是 secure storage 的 `local_app_lock_enabled` 条目（"true"/"false"
/// 字符串），缺省视为关闭。修改路径：UI 调 [AppLockController] 的方法后
/// `ref.invalidate(appLockEnabledProvider)`。
final appLockEnabledProvider = FutureProvider<bool>((ref) async {
  final store = ref.watch(pinCredentialStoreProvider);
  return store.readEnabled();
});

/// Step 14.2：生物识别能力探测。
///
/// 返回 [BiometricCapability]——同时反映「设备硬件支持」+「用户已录入指纹/面容」
/// 两个维度。设置页用它决定开关是否置灰；解锁页用它决定是否走生物识别快路径。
///
/// **不**缓存：每次 watch / read 重跑探测。理由：用户可能在 App 运行过程中去系统
/// 设置里录入新指纹（或删掉所有指纹），探测结果会变。代价只是两次 method channel
/// 调用，可以接受。如果未来观察到性能问题，再加 short-lived cache。
final biometricCapabilityProvider =
    FutureProvider<BiometricCapability>((ref) async {
  final auth = ref.watch(biometricAuthenticatorProvider);
  final supported = await auth.isDeviceSupported();
  if (!supported) {
    return const BiometricCapability(
      supported: false,
      hasEnrolled: false,
    );
  }
  final enrolled = await auth.hasEnrolledBiometrics();
  return BiometricCapability(supported: true, hasEnrolled: enrolled);
});

/// 用户在设置页里的"生物识别"开关持久化值——独立于 [biometricCapabilityProvider]
/// 的硬件探测。
///
/// "可用" = `enabled && capability.supported && capability.hasEnrolled`，由 UI 自己
/// 组合判断；本 provider 只负责 secure storage 真值源。
final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  final store = ref.watch(pinCredentialStoreProvider);
  return store.readBiometricEnabled();
});

/// Step 14.3：后台超时锁定阈值（秒）。
///
/// 真值源是 `PinCredentialStore.readBackgroundLockTimeoutSeconds`。修改路径：
/// UI 调 [AppLockController.setBackgroundLockTimeoutSeconds] 后
/// `ref.invalidate(backgroundLockTimeoutProvider)`，[AppLockGuard] 通过 `ref.listen`
/// 自动同步新阈值——不重建 Notifier，会话状态（lastBackgroundedAt）保留。
///
/// 默认 [kDefaultBackgroundLockTimeoutSeconds]（60 秒）；`0` 表示"立即锁定"
/// （任何 paused→resumed 都触发锁屏）。
final backgroundLockTimeoutProvider = FutureProvider<int>((ref) async {
  final store = ref.watch(pinCredentialStoreProvider);
  return store.readBackgroundLockTimeoutSeconds();
});

/// Step 14.4：隐私模式开关持久化值。
///
/// 真值源是 secure storage 的 `local_app_lock_privacy_mode` 条目。修改路径：UI 调
/// [AppLockController.setPrivacyMode] —— 内部既写存储又调 [privacyModeServiceProvider]
/// 的 native 端，再 `ref.invalidate(privacyModeProvider)` 让开关 UI 重建。
///
/// **独立于 [appLockEnabledProvider]**：截屏阻止与"锁屏"是两种正交防护，开/关互不
/// 影响 —— 用户可以"不开应用锁但开隐私模式"，也可以"开应用锁但不开隐私模式"。
final privacyModeProvider = FutureProvider<bool>((ref) async {
  final store = ref.watch(pinCredentialStoreProvider);
  return store.readPrivacyMode();
});

/// Step 14.4：隐私模式 native 通道封装层 provider。
///
/// 生产为 [MethodChannelPrivacyModeService]，测试通过 `ProviderContainer.test(
/// overrides: [privacyModeServiceProvider.overrideWithValue(FakePrivacyModeService())])`
/// 注入。
final privacyModeServiceProvider = Provider<PrivacyModeService>((ref) {
  return const MethodChannelPrivacyModeService();
});

/// Step 14.2：生物识别封装层 provider。生产为 [LocalAuthBiometricAuthenticator]，
/// 测试通过 `ProviderContainer.test(overrides: [biometricAuthenticatorProvider.overrideWithValue(FakeBiometricAuthenticator())])`
/// 注入。
final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>((ref) {
  return LocalAuthBiometricAuthenticator();
});

/// 设备生物识别能力快照——unsupport / enrolled 两维度。
class BiometricCapability {
  const BiometricCapability({
    required this.supported,
    required this.hasEnrolled,
  });

  /// 设备硬件 + OS 层面是否支持任何生物识别（指纹/面容/虹膜）。
  final bool supported;

  /// 用户已在系统设置里录入了至少一种生物特征。
  final bool hasEnrolled;

  /// 是否可以立即调用 authenticate 走生物识别——两条都满足才算可用。
  bool get isUsable => supported && hasEnrolled;

  @override
  bool operator ==(Object other) =>
      other is BiometricCapability &&
      other.supported == supported &&
      other.hasEnrolled == hasEnrolled;

  @override
  int get hashCode => Object.hash(supported, hasEnrolled);

  @override
  String toString() =>
      'BiometricCapability(supported: $supported, hasEnrolled: $hasEnrolled)';
}

/// PIN 校验会话——保存"已连续失败次数"和"冷却到点的时间戳"。
///
/// **会话级**（不持久化）：App 冷启动后状态归零。这与"3 次失败冷却 30 秒"的口径
/// 是一致的——冷却是会话级护栏，重启不影响（如果用户重启后立即又能再试 3 次，那
/// 是设计接受的范围；阻止重启绕过需要把冷却时间也写进 secure storage，14.1 不
/// 做，留给后续若有"暴力破解告警"再加）。
class PinAttemptState {
  const PinAttemptState({
    required this.failures,
    required this.cooldownUntil,
  });

  final int failures;
  final DateTime? cooldownUntil;

  static const PinAttemptState initial =
      PinAttemptState(failures: 0, cooldownUntil: null);

  PinAttemptState copyWith({
    int? failures,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
  }) {
    return PinAttemptState(
      failures: failures ?? this.failures,
      cooldownUntil: clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PinAttemptState &&
      other.failures == failures &&
      other.cooldownUntil == cooldownUntil;

  @override
  int get hashCode => Object.hash(failures, cooldownUntil);

  @override
  String toString() =>
      'PinAttemptState(failures: $failures, cooldownUntil: $cooldownUntil)';
}

class PinAttemptSession extends StateNotifier<PinAttemptState> {
  PinAttemptSession({
    required this.store,
    required this.clock,
  }) : super(PinAttemptState.initial);

  final PinCredentialStore store;
  final AppLockClock clock;

  /// 当前是否在冷却窗口内——用于 UI 实时禁用输入框。
  bool isCoolingDown([DateTime? now]) {
    final until = state.cooldownUntil;
    if (until == null) return false;
    final ts = now ?? clock();
    return ts.isBefore(until);
  }

  /// 冷却剩余秒数（向上取整）。未冷却时返回 0。
  int cooldownRemainingSeconds([DateTime? now]) {
    final until = state.cooldownUntil;
    if (until == null) return 0;
    final ts = now ?? clock();
    final diff = until.difference(ts);
    if (diff.isNegative) return 0;
    return (diff.inMilliseconds / 1000).ceil();
  }

  /// 尝试用 [pin] 验证。
  ///
  /// - 冷却中调用直接返回 `false`，**不**消耗 attempt（避免冷却中重复尝试再次拉
  ///   长冷却）；
  /// - 凭据缺失（store 还没 setupPin）也返回 `false`；
  /// - 验证成功 → 状态归零（`failures=0 / cooldownUntil=null`）；
  /// - 验证失败 + 累计 failures < [kPinFailureLimit] → `failures+1`；
  /// - 验证失败 + 累计 failures >= [kPinFailureLimit] → 触发冷却，重置 failures 为 0
  ///   并把 `cooldownUntil = now + kPinCooldownDuration` 写入 state。
  Future<bool> tryVerify(String pin) async {
    if (isCoolingDown()) return false;
    final cred = await store.load();
    if (cred == null) return false;
    final ok = await verifyPin(pin, cred);
    if (ok) {
      state = PinAttemptState.initial;
      return true;
    }
    final nextFailures = state.failures + 1;
    if (nextFailures >= kPinFailureLimit) {
      state = PinAttemptState(
        failures: 0,
        cooldownUntil: clock().add(kPinCooldownDuration),
      );
    } else {
      state = state.copyWith(failures: nextFailures);
    }
    return false;
  }

  /// 重置失败 / 冷却状态。
  ///
  /// 调用方：[AppLockController.setupPin / changePin / disable] 写入凭据后清残余
  /// 失败计数；Step 14.2 [PinUnlockPage] 在生物识别成功后也会调，避免上一会话残
  /// 余的 PIN 失败计数把后续手动 PIN 输入直接推进冷却。
  void reset() {
    state = PinAttemptState.initial;
  }
}

final pinAttemptSessionProvider =
    StateNotifierProvider<PinAttemptSession, PinAttemptState>((ref) {
  final store = ref.watch(pinCredentialStoreProvider);
  final clock = ref.watch(appLockClockProvider);
  return PinAttemptSession(store: store, clock: clock);
});

/// 命令式控制器——负责 setup/change/disable PIN 三类写入。
///
/// 所有写入都直接打 store；UI 在 await 后显式 `ref.invalidate(appLockEnabledProvider)`
/// 让开关重新读取最新状态。
class AppLockController {
  AppLockController(this.ref);

  final Ref ref;

  PinCredentialStore get _store => ref.read(pinCredentialStoreProvider);

  /// 首次启用：写凭据 + 置 enabled=true。
  Future<void> setupPin(String pin) async {
    final formatError = validatePinFormat(pin);
    if (formatError != null) {
      throw ArgumentError(formatError);
    }
    final salt = generatePinSalt();
    final cred = await hashPin(pin, salt);
    await _store.save(cred);
    await _store.writeEnabled(true);
    // 重置失败/冷却状态——新设 PIN 后不让上一会话的失败计数继续生效。
    ref.read(pinAttemptSessionProvider.notifier).reset();
  }

  /// 修改 PIN——调用前 UI 必须先用 [PinAttemptSession.tryVerify] 验证旧 PIN。
  /// 本方法不再验证，只负责写新凭据；enabled 标志保持不变。
  Future<void> changePin(String newPin) async {
    final formatError = validatePinFormat(newPin);
    if (formatError != null) {
      throw ArgumentError(formatError);
    }
    final salt = generatePinSalt();
    final cred = await hashPin(newPin, salt);
    await _store.save(cred);
    ref.read(pinAttemptSessionProvider.notifier).reset();
  }

  /// 关闭应用锁——清凭据 + 置 enabled=false + 同时清生物识别开关（避免下次重新设
  /// PIN 后旧的生物识别 enabled=true 残留生效）。
  /// 调用方应先验证旧 PIN（关锁需要持有人确认）；忘记 PIN 走另一条路径
  /// （[forgetPinAndDisable] 直接清，配合"会清空本地数据"的告知）。
  Future<void> disable() async {
    await _store.clearCredential();
    await _store.writeEnabled(false);
    await _store.writeBiometricEnabled(false);
    ref.read(pinAttemptSessionProvider.notifier).reset();
  }

  /// "忘记 PIN" 路径——直接清凭据 + 关锁。
  ///
  /// **不**在本方法内清空本地数据库——14.1 仅负责 PIN 状态；"清空本地数据但云端
  /// 可恢复"的真实清库行为留给 UI 层在调用前/后接到 trash / db reset 流程。
  /// 14.1 阶段 UI 只展示告知文案 + 调用本方法关锁，让用户接着手工"重新登录云端"
  /// 走 Phase 10 的 download 路径——这与设计文档 §5.5 描述的恢复模型一致。
  Future<void> forgetPinAndDisable() async {
    await disable();
  }

  /// Step 14.2：持久化用户在设置页的生物识别开关选择。
  ///
  /// **本方法不做硬件可用性校验**——UI 在调用前应先看 [biometricCapabilityProvider]
  /// 是否 isUsable，并且开启路径需用 [BiometricAuthenticator.authenticate] 弹一次系
  /// 统面板二次确认。本方法只负责把最终决定写入 secure storage。
  ///
  /// 调用方在 await 后显式 `ref.invalidate(biometricEnabledProvider)` 触发开关 UI
  /// 重建。
  Future<void> setBiometricEnabled(bool enabled) async {
    await _store.writeBiometricEnabled(enabled);
  }

  /// Step 14.3：持久化后台超时锁定阈值（秒）。
  ///
  /// 调用方在 await 后显式 `ref.invalidate(backgroundLockTimeoutProvider)` 触发
  /// [AppLockGuard] 同步新阈值。
  ///
  /// 接受值：
  /// - `0` = 立即锁定（任何 paused→resumed 都锁）；
  /// - 正整数 = 后台超过 N 秒锁定（建议从 [kBackgroundLockTimeoutOptions] 选）；
  /// - 负值 = 抛 [ArgumentError]（避免误传 -1 之类被当成"立即"）。
  Future<void> setBackgroundLockTimeoutSeconds(int seconds) async {
    if (seconds < 0) {
      throw ArgumentError('seconds must be >= 0, got $seconds');
    }
    await _store.writeBackgroundLockTimeoutSeconds(seconds);
  }

  /// Step 14.4：持久化隐私模式开关并立即同步到 native。
  ///
  /// 调用方在 await 后显式 `ref.invalidate(privacyModeProvider)` 触发开关 UI 重建。
  ///
  /// 顺序：先写 native 再写 storage。理由：native 调用是即时生效路径（FLAG_SECURE
  /// 直接打到 Window / iOS overlay state），失败时不应让存储和实际生效状态不一致。
  /// 失败由 service 内部静默吞 —— 不影响 storage 写入（用户的偏好仍被尊重，下次
  /// bootstrap 时会再 apply 一次）。
  Future<void> setPrivacyMode(bool enabled) async {
    await ref.read(privacyModeServiceProvider).setEnabled(enabled);
    await _store.writePrivacyMode(enabled);
  }
}

final appLockControllerProvider = Provider<AppLockController>((ref) {
  return AppLockController(ref);
});

/// 判断"应用锁是否已经设置"——比 enabled 标志更宽，仅检查凭据三件套是否都齐。
/// 主要给"开关切换"的反向流程用：用户拨开开关时如果凭据已存在但 enabled=false
/// （理论上不会发生，14.1 没有产生这种状态的路径），可以选择直接置 enabled=true
/// 而不重新输 PIN。当前 UI 没有用到这个 provider；保留以备 14.2。
@visibleForTesting
final pinIsConfiguredProvider = FutureProvider<bool>((ref) async {
  final store = ref.watch(pinCredentialStoreProvider);
  return (await store.load()) != null;
});

/// 调试工具：只在 debug build 暴露 PinAttemptState 字符串——避免 release 包里把
/// 失败次数泄露给截屏工具。当前没人消费，留作 14.3 锁屏页可能需要的观测点。
@visibleForTesting
String debugDumpAttemptState(PinAttemptState s) {
  if (!kDebugMode) return '<release>';
  return s.toString();
}

/// Step 14.3：前台锁屏 Guard 的状态。
///
/// 两条核心字段：
/// - [isLocked]：当前是否需要展示锁屏——`true` 时 [BianBianApp] 在路由器之上覆盖
///   [PinUnlockPage] overlay；`false` 时 overlay 隐藏，正常路由生效；
/// - [lastBackgroundedAt]：进入后台的时间戳——`null` 表示当前没有"挂起的后台
///   会话"（要么从未进过后台，要么已经处理过 resumed）。
///
/// 本类不对外暴露 lastBackgroundedAt 的修改语义——所有变更走 [AppLockGuard]
/// 的方法。**不**持久化：App 冷启动状态归零（冷启动锁逻辑由 main.dart 主动调
/// `lock()` 触发），与 PinAttemptState 一致。
@immutable
class AppLockGuardState {
  const AppLockGuardState({
    required this.isLocked,
    required this.lastBackgroundedAt,
  });

  final bool isLocked;
  final DateTime? lastBackgroundedAt;

  static const AppLockGuardState unlocked =
      AppLockGuardState(isLocked: false, lastBackgroundedAt: null);

  static const AppLockGuardState locked =
      AppLockGuardState(isLocked: true, lastBackgroundedAt: null);

  AppLockGuardState copyWith({
    bool? isLocked,
    DateTime? lastBackgroundedAt,
    bool clearLastBackgroundedAt = false,
  }) {
    return AppLockGuardState(
      isLocked: isLocked ?? this.isLocked,
      lastBackgroundedAt: clearLastBackgroundedAt
          ? null
          : (lastBackgroundedAt ?? this.lastBackgroundedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppLockGuardState &&
      other.isLocked == isLocked &&
      other.lastBackgroundedAt == lastBackgroundedAt;

  @override
  int get hashCode => Object.hash(isLocked, lastBackgroundedAt);

  @override
  String toString() =>
      'AppLockGuardState(isLocked: $isLocked, '
      'lastBackgroundedAt: $lastBackgroundedAt)';
}

/// Step 14.3：前台锁屏触发器。
///
/// 监听三类事件：
/// - [lock]：冷启动锁——main.dart 在 bootstrap 末尾若 `appLockEnabledProvider == true`
///   主动调用；
/// - [onPaused]：[BianBianApp.didChangeAppLifecycleState] 收到 paused/hidden/detached
///   时调用——记录 [AppLockGuardState.lastBackgroundedAt]；
/// - [onResumed]：收到 resumed 时调用——若 `(now - lastBackgroundedAt >= timeoutSeconds)`
///   则锁。`timeoutSeconds == 0` 表示立即锁（任何 paused→resumed 都锁）。
///
/// 调用 [unlock] 解锁——成功验证 PIN / 生物识别后由 [PinUnlockPage] overlay 触发。
///
/// `enabled` 标志由外部 provider 链联动——`appLockEnabledProvider` 变 false 时
/// [appLockGuardProvider] 的 listen 自动 `forceUnlock()` 清状态（避免锁屏卡死）。
class AppLockGuard extends StateNotifier<AppLockGuardState> {
  AppLockGuard({
    required this.clock,
    int initialTimeoutSeconds = kDefaultBackgroundLockTimeoutSeconds,
  })  : _timeoutSeconds = initialTimeoutSeconds < 0
            ? kDefaultBackgroundLockTimeoutSeconds
            : initialTimeoutSeconds,
        super(AppLockGuardState.unlocked);

  final AppLockClock clock;
  int _timeoutSeconds;

  /// 当前生效的后台超时阈值（秒）；UI 不直接消费——只用于日志/调试。
  @visibleForTesting
  int get timeoutSeconds => _timeoutSeconds;

  /// 由 [appLockGuardProvider] 的 listen 在 [backgroundLockTimeoutProvider]
  /// 变化时调用，同步新阈值。**不重建 Notifier**——保留 lastBackgroundedAt
  /// 与 isLocked 状态不被打断。
  void setTimeoutSeconds(int seconds) {
    if (seconds < 0) return;
    _timeoutSeconds = seconds;
  }

  /// 立即锁屏——main 冷启动 / 测试可手动调。
  ///
  /// 同时清空 lastBackgroundedAt——避免锁屏期间 paused→resumed 的额外锁动作
  /// 干扰（用户已经在锁屏页面，再"加锁"无意义）。
  void lock() {
    state = AppLockGuardState.locked;
  }

  /// 解锁——PIN/生物识别验证成功后由 [PinUnlockPage] 调用。
  ///
  /// 同时清 lastBackgroundedAt——下次 paused 事件会重新写入。
  void unlock() {
    state = AppLockGuardState.unlocked;
  }

  /// 应用锁被关闭时由 listen 调用——立即解锁 + 清 lastBackgroundedAt。
  /// 与 [unlock] 等价；保留独立方法名是为了在 stack trace 里区分调用源。
  void forceUnlock() {
    state = AppLockGuardState.unlocked;
  }

  /// App 进入后台——记录 lastBackgroundedAt 时间戳。**不**直接锁屏，等
  /// [onResumed] 时按超时阈值判定。
  ///
  /// 已锁屏（isLocked == true）时本方法依然记录 lastBackgroundedAt，
  /// 但不会改变锁屏状态——避免用户在锁屏页面快速切换前后台时丢失"已锁"语义。
  void onPaused() {
    state = state.copyWith(lastBackgroundedAt: clock());
  }

  /// App 回到前台——若距 [onPaused] 时刻已超过 timeoutSeconds 则锁屏。
  ///
  /// 边界条件：
  /// - lastBackgroundedAt == null（未走过 onPaused）→ 不动；
  /// - timeoutSeconds == 0 → 任何 elapsed >= 0 都触发锁；
  /// - elapsed < timeoutSeconds → 不锁，但**清空** lastBackgroundedAt（视为"本次
  ///   后台会话已处理"）；
  /// - elapsed >= timeoutSeconds → 锁。
  void onResumed() {
    final last = state.lastBackgroundedAt;
    if (last == null) return;
    final now = clock();
    final elapsedSeconds = now.difference(last).inSeconds;
    if (elapsedSeconds >= _timeoutSeconds) {
      state = AppLockGuardState.locked;
    } else {
      // 未触发锁但已"消化"本次后台会话——避免用户多次 resume 重复触发判定。
      state = state.copyWith(clearLastBackgroundedAt: true);
    }
  }
}

/// Step 14.3：[AppLockGuard] 的 Riverpod 入口。
///
/// 创建时 listen 两个上游 provider：
/// - [appLockEnabledProvider]：true→false 时调 [AppLockGuard.forceUnlock]
///   （用户关闭应用锁后立即让 overlay 隐藏）；
/// - [backgroundLockTimeoutProvider]：值变更时调 [AppLockGuard.setTimeoutSeconds]
///   （即时生效，不重建 Notifier、保留 lastBackgroundedAt）。
///
/// **不**主动锁——冷启动锁由 main.dart 在 bootstrap 末尾显式调
/// `ref.read(appLockGuardProvider.notifier).lock()`，避免 provider 初始化时机
/// 与 enabled async 状态的 race。
final appLockGuardProvider =
    StateNotifierProvider<AppLockGuard, AppLockGuardState>((ref) {
  final clock = ref.watch(appLockClockProvider);
  // 用 `read` 拿一次同步初值——provider 已被 main bootstrap 预热到 AsyncData。
  // 取不到（极少见的 race，例如测试场景）就用 default。
  final initialTimeout = ref.read(backgroundLockTimeoutProvider).maybeWhen(
        data: (s) => s,
        orElse: () => kDefaultBackgroundLockTimeoutSeconds,
      );
  final guard = AppLockGuard(
    clock: clock,
    initialTimeoutSeconds: initialTimeout,
  );
  ref.listen<AsyncValue<int>>(backgroundLockTimeoutProvider, (prev, next) {
    next.whenData(guard.setTimeoutSeconds);
  });
  ref.listen<AsyncValue<bool>>(appLockEnabledProvider, (prev, next) {
    next.whenData((enabled) {
      if (!enabled) guard.forceUnlock();
    });
  });
  return guard;
});
