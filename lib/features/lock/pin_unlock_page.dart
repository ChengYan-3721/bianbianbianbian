import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_providers.dart';
import 'biometric_authenticator.dart';
import 'pin_credential.dart';

/// PIN 解锁页——14.1 阶段用于"关闭应用锁"与"修改 PIN"前的旧 PIN 验证；
/// 14.2 阶段在 PIN 上叠加生物识别快路径（启用 + 设备可用 + 未冷却时自动弹一次系
/// 统面板，成功直接 pop(true)，失败/取消降级到 PIN 输入）；
/// 14.3 阶段会作为前台锁屏的输入界面被 [AppLockGuard] overlay 显示——overlay 形态
/// 下不在路由栈，所以传 [onUnlocked] 让 widget 直接通知 guard 而非 pop。
///
/// UI 协议：
/// - 验证成功（PIN 或生物识别）→ 若传了 [onUnlocked] 则调用 callback；否则
///   `Navigator.pop(true)`（兼容 push/await pop 的老调用方）；
/// - 用户主动返回（系统返回键 / AppBar back）→ 仅 push 形态生效，overlay 形态
///   由调用方用 [PopScope] 拦截；
/// - 错误 [kPinFailureLimit] 次后进入 [kPinCooldownDuration] 秒冷却——输入框置灰
///   + Filled 按钮置灰 + 生物识别按钮也置灰，倒计时通过 1 秒间隔的 `Timer.periodic`
///   触发 setState 重绘。倒计时结束自动允许重新输入。
///
/// **不**支持"忘记 PIN"入口——该入口由设置页承载，只允许在用户已知道
/// "会清空本地数据"前提下点击；锁屏页若内嵌"忘记 PIN"会让"前台锁屏"形同虚设。
class PinUnlockPage extends ConsumerStatefulWidget {
  const PinUnlockPage({
    super.key,
    this.subtitle = '请输入应用锁 PIN',
    this.allowBiometric = true,
    this.onUnlocked,
    this.showAppBar = true,
  });

  final String subtitle;

  /// 是否允许走生物识别。"修改 PIN" / "关闭应用锁" 这种"持有人确认"路径建议传
  /// false——避免随手扫脸/按指纹绕过验证；纯锁屏场景传 true。
  final bool allowBiometric;

  /// Step 14.3：成功验证后的回调。
  ///
  /// - `null`（push/await 调用方）→ 走 `Navigator.pop(true)`；
  /// - 非 null（[AppLockGuard] overlay 形态）→ 不 pop，直接 callback——通常调用方
  ///   会 `ref.read(appLockGuardProvider.notifier).unlock()`，让 overlay 隐藏。
  final VoidCallback? onUnlocked;

  /// Step 14.3：是否显示 AppBar。锁屏 overlay 形态下传 false——避免出现返回箭头
  /// 暗示用户"可以退出锁屏"。
  final bool showAppBar;

  @override
  ConsumerState<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends ConsumerState<PinUnlockPage> {
  final _ctrl = TextEditingController();
  String? _errorText;
  bool _busy = false;
  Timer? _cooldownTicker;

  /// 防止 build 期间多次自动触发——只在 init 时尝试一次自动弹，之后用户必须手动点
  /// "使用生物识别"按钮才能再触发。
  bool _autoBiometricAttempted = false;

  /// 当前是否在等待系统生物识别面板返回——true 时禁用 PIN 输入与按钮，
  /// 避免用户同时在两个通道操作。
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    _maybeStartTicker();
    // 自动弹生物识别推迟到 first frame 之后，避免 mid-build 触发 ref.read。
    if (widget.allowBiometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeAutoTriggerBiometric();
      });
    }
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _maybeStartTicker() {
    final session = ref.read(pinAttemptSessionProvider.notifier);
    if (session.isCoolingDown()) {
      _cooldownTicker?.cancel();
      _cooldownTicker =
          Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final stillCoolingDown = session.isCoolingDown();
        if (!stillCoolingDown) {
          _cooldownTicker?.cancel();
          _cooldownTicker = null;
          setState(() {
            _errorText = null;
          });
        } else {
          // 强制 rebuild 让 cooldownRemainingSeconds 数字滚动。
          setState(() {});
        }
      });
    }
  }

  Future<void> _maybeAutoTriggerBiometric() async {
    if (_autoBiometricAttempted) return;
    _autoBiometricAttempted = true;
    final session = ref.read(pinAttemptSessionProvider.notifier);
    if (session.isCoolingDown()) return;

    final enabled = await ref.read(biometricEnabledProvider.future);
    if (!enabled || !mounted) return;
    final cap = await ref.read(biometricCapabilityProvider.future);
    if (!cap.isUsable || !mounted) return;
    await _runBiometric();
  }

  Future<void> _runBiometric() async {
    if (_biometricBusy || _busy) return;
    final session = ref.read(pinAttemptSessionProvider.notifier);
    if (session.isCoolingDown()) return;

    setState(() {
      _biometricBusy = true;
      _errorText = null;
    });

    final auth = ref.read(biometricAuthenticatorProvider);
    final result = await auth.authenticate(reason: '验证身份以解锁边边记账');
    if (!mounted) return;

    switch (result) {
      case BiometricResult.success:
        // 成功后清空 PIN 失败计数，防止上一会话残余触发冷却。
        session.reset();
        _emitSuccess();
        return;
      case BiometricResult.cancelled:
        // 用户主动取消（按取消 / 来电中断）——静默回退到 PIN，不展示报错。
        setState(() {
          _biometricBusy = false;
        });
        return;
      case BiometricResult.lockedOut:
        setState(() {
          _biometricBusy = false;
          _errorText = '生物识别已被系统临时锁定，请改用 PIN';
        });
        return;
      case BiometricResult.notAvailable:
        setState(() {
          _biometricBusy = false;
          _errorText = '生物识别暂不可用，请改用 PIN';
        });
        return;
      case BiometricResult.failed:
        setState(() {
          _biometricBusy = false;
          _errorText = '生物识别未通过，请改用 PIN';
        });
        return;
    }
  }

  /// Step 14.3：成功验证后的统一收口——overlay 形态调 callback、push 形态 pop。
  void _emitSuccess() {
    final cb = widget.onUnlocked;
    if (cb != null) {
      cb();
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _onSubmit() async {
    if (_busy || _biometricBusy) return;
    final session = ref.read(pinAttemptSessionProvider.notifier);
    if (session.isCoolingDown()) return;

    final pin = _ctrl.text;
    final formatError = validatePinFormat(pin);
    if (formatError != null) {
      setState(() => _errorText = formatError);
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });

    final ok = await session.tryVerify(pin);
    if (!mounted) return;
    if (ok) {
      _emitSuccess();
      return;
    }

    // 失败后清空输入并展示错误。若刚触发冷却就启动 ticker。
    final state = ref.read(pinAttemptSessionProvider);
    setState(() {
      _busy = false;
      _ctrl.clear();
      if (state.cooldownUntil != null) {
        _errorText = '错误次数过多，已进入冷却';
        _maybeStartTicker();
      } else {
        final left = kPinFailureLimit - state.failures;
        _errorText = 'PIN 错误，剩余尝试次数 $left';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(pinAttemptSessionProvider.notifier);
    // watch state 让"失败次数 / cooldownUntil 变化"触发 rebuild（复算 isCoolingDown）。
    ref.watch(pinAttemptSessionProvider);

    final coolingDown = session.isCoolingDown();
    final cooldownLeft = session.cooldownRemainingSeconds();
    final inputDisabled = coolingDown || _busy || _biometricBusy;

    // 仅当生物识别开关 ON + 设备可用 时显示按钮（避免给用户错误信号）。
    final biometricEnabledAsync = widget.allowBiometric
        ? ref.watch(biometricEnabledProvider)
        : const AsyncValue<bool>.data(false);
    final biometricCapAsync = widget.allowBiometric
        ? ref.watch(biometricCapabilityProvider)
        : const AsyncValue<BiometricCapability>.data(
            BiometricCapability(supported: false, hasEnrolled: false),
          );
    final biometricAvailable = biometricEnabledAsync.maybeWhen(
          data: (enabled) =>
              enabled &&
              biometricCapAsync.maybeWhen(
                data: (cap) => cap.isUsable,
                orElse: () => false,
              ),
          orElse: () => false,
        );

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('解锁')) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _ctrl,
                autofocus: !inputDisabled,
                enabled: !inputDisabled,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: kPinMaxLength,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(kPinMaxLength),
                ],
                decoration: InputDecoration(
                  labelText: 'PIN',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _onSubmit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: inputDisabled ? null : _onSubmit,
                child: Text(coolingDown ? '冷却中（$cooldownLeft 秒）' : '验证'),
              ),
              if (biometricAvailable) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: inputDisabled ? null : _runBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(
                    _biometricBusy ? '请按提示完成生物识别…' : '使用指纹 / 面容解锁',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
