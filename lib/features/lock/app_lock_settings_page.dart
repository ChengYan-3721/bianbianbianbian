import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_ext.dart';
import 'app_lock_providers.dart';
import 'biometric_authenticator.dart';
import 'pin_credential.dart';
import 'pin_setup_page.dart';
import 'pin_unlock_page.dart';

/// 「我的 → 应用锁」设置页。
///
/// 四类操作：
/// 1. 启用 / 关闭应用锁——开关 [SwitchListTile]：
///    - 关→开：push [PinSetupPage]，setupPin 成功即开启；
///    - 开→关：push [PinUnlockPage]（**关闭生物识别**——属"持有人确认"路径），
///      验证通过后调 [AppLockController.disable]。
/// 2. 修改 PIN——开启状态下可见；先 push [PinUnlockPage]（同样关闭生物识别）验证
///    旧 PIN，再 push [PinSetupPage] 采集新 PIN；任一环节用户取消都不写入。
/// 3. **Step 14.2** 生物识别开关 [_BiometricToggle]——只在 PIN 已开启时显示；硬件
///    不支持 / 未录入时置灰 + 给出说明；开启时弹一次系统面板二次确认（成功才
///    persist）；关闭直接 persist。
/// 4. 忘记 PIN——任何状态都可见（关闭状态下入口隐藏，避免误导）。点击弹
///    `AlertDialog` 明确告知"会清空本地数据但云端可恢复"——14.1 阶段仅清 PIN
///    凭据 + 关锁，不真的清库；用户随后需要走 Phase 10「我的 → 云服务 → 下载」
///    自行恢复云端数据。
class AppLockSettingsPage extends ConsumerWidget {
  const AppLockSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(appLockEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.lockTitle)),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.readFailedWithError(e.toString()))),
        data: (enabled) => _Body(enabled: enabled),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.enabled});

  final bool enabled;

  Future<void> _onToggle(BuildContext context, WidgetRef ref, bool next) async {
    if (next == enabled) return;
    if (next) {
      // 开启：push 设置页采集 PIN。
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const PinSetupPage(mode: PinSetupMode.setup),
        ),
      );
      if (ok != true) return;
      ref.invalidate(appLockEnabledProvider);
    } else {
      // 关闭：先验证旧 PIN，再 disable。**不**允许走生物识别——属于"持有人确认"
      // 路径，避免随手扫脸/按指纹绕过验证。
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PinUnlockPage(
            subtitle: context.l10n.lockEnterCurrentPinToDisable,
            allowBiometric: false,
          ),
        ),
      );
      if (ok != true) return;
      await ref.read(appLockControllerProvider).disable();
      ref.invalidate(appLockEnabledProvider);
      ref.invalidate(biometricEnabledProvider);
    }
  }

  Future<void> _onChangePin(BuildContext context, WidgetRef ref) async {
    // 修改 PIN：必须用旧 PIN 验证，不允许生物识别——同样属于"持有人确认"路径。
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PinUnlockPage(
          subtitle: context.l10n.lockEnterCurrentPinToVerify,
          allowBiometric: false,
        ),
      ),
    );
    if (verified != true) return;
    if (!context.mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PinSetupPage(mode: PinSetupMode.change),
      ),
    );
    // changePin 成功 / 失败均不动 enabled 标志，无需 invalidate。
  }

  Future<void> _onForgetPin(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.lockForgotPin),
        content: Text(context.l10n.lockForgotPinMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.lockAcknowledgeAndDisable),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appLockControllerProvider).forgetPinAndDisable();
    ref.invalidate(appLockEnabledProvider);
    ref.invalidate(biometricEnabledProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: Text(context.l10n.lockEnableAppLock),
          subtitle: Text(
            enabled ? context.l10n.lockEnabled : context.l10n.lockDisabling,
          ),
          value: enabled,
          onChanged: (v) => _onToggle(context, ref, v),
        ),
        if (enabled) ...[
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: Text(context.l10n.lockChangePin),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _onChangePin(context, ref),
          ),
          const Divider(height: 0),
          const _BiometricToggle(),
          const Divider(height: 0),
          const _BackgroundTimeoutTile(),
        ],
        const Divider(height: 0),
        const _PrivacyModeToggle(),
        const Divider(height: 0),
        ListTile(
          leading: Icon(
            Icons.help_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            context.l10n.lockForgotPin,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: Text(context.l10n.lockDisableHint),
          onTap: () => _onForgetPin(context, ref),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            context.l10n.lockSecurityNote,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(context.l10n.lockSecurityNoteMsg),
        ),
      ],
    );
  }
}

/// Step 14.2：生物识别开关 ListTile。
///
/// 三态：
/// - 设备硬件不支持（`capability.supported == false`）：置灰 + "本设备不支持生物识别"；
/// - 设备支持但未录入（`hasEnrolled == false`）：置灰 + "请先在系统设置录入指纹 / 面容"；
/// - 可用：根据 [biometricEnabledProvider] 显示开关。开启路径需弹一次系统面板二次
///   确认（避免用户在不知情况下被开启），成功才 persist。
class _BiometricToggle extends ConsumerWidget {
  const _BiometricToggle();

  Future<void> _onChange(BuildContext context, WidgetRef ref, bool next) async {
    if (next) {
      final auth = ref.read(biometricAuthenticatorProvider);
      final result =
          await auth.authenticate(reason: context.l10n.lockVerifyBiometric);
      if (!context.mounted) return;
      if (result != BiometricResult.success) {
        // 用户取消 / 系统拒绝 / 失败——不开启，但给出温和反馈。
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_resultMessage(context, result))),
        );
        return;
      }
      await ref.read(appLockControllerProvider).setBiometricEnabled(true);
      ref.invalidate(biometricEnabledProvider);
    } else {
      await ref.read(appLockControllerProvider).setBiometricEnabled(false);
      ref.invalidate(biometricEnabledProvider);
    }
  }

  String _resultMessage(BuildContext context, BiometricResult result) {
    switch (result) {
      case BiometricResult.success:
        return context.l10n.lockBiometricEnabled;
      case BiometricResult.cancelled:
        return context.l10n.lockBiometricCancelled;
      case BiometricResult.lockedOut:
        return context.l10n.lockBiometricLockedOut;
      case BiometricResult.notAvailable:
        return context.l10n.lockBiometricNotAvailable;
      case BiometricResult.failed:
        return context.l10n.lockBiometricNotRecognized;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capAsync = ref.watch(biometricCapabilityProvider);
    final enabledAsync = ref.watch(biometricEnabledProvider);

    return capAsync.when(
      loading: () => ListTile(
        leading: const Icon(Icons.fingerprint),
        title: Text(context.l10n.lockBiometricTitle),
        subtitle: Text(context.l10n.lockBiometricDetecting),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.fingerprint),
        title: Text(context.l10n.lockBiometricTitle),
        subtitle: Text(context.l10n.lockBiometricDetectFailed(e.toString())),
        enabled: false,
      ),
      data: (cap) {
        final reasonText = !cap.supported
            ? context.l10n.lockBiometricNotSupported
            : !cap.hasEnrolled
                ? context.l10n.lockBiometricNotEnrolled
                : null;
        if (reasonText != null) {
          return ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(context.l10n.lockBiometricTitle),
            subtitle: Text(reasonText),
            trailing: const Switch(value: false, onChanged: null),
            enabled: false,
          );
        }
        return enabledAsync.when(
          loading: () => ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(context.l10n.lockBiometricTitle),
            subtitle: Text(context.l10n.lockBiometricReadingPrefs),
          ),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(context.l10n.lockBiometricTitle),
            subtitle: Text(context.l10n.readFailedWithError(e.toString())),
            enabled: false,
          ),
          data: (enabled) => SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: Text(context.l10n.lockBiometricTitle),
            subtitle: Text(
              enabled
                  ? context.l10n.lockBiometricEnabledDesc
                  : context.l10n.lockBiometricDisabledDesc,
            ),
            value: enabled,
            onChanged: (v) => _onChange(context, ref, v),
          ),
        );
      },
    );
  }
}

/// Step 14.3：后台超时锁定阈值选择器。
///
/// 仅在应用锁已开启时挂载（由 `_Body.build` 控制）。点击 ListTile 弹
/// `showModalBottomSheet`，4 个固定选项：
/// - 立即锁定（0 秒）
/// - 1 分钟（60 秒）
/// - 5 分钟（300 秒）
/// - 15 分钟（900 秒）
///
/// 选中后调 [AppLockController.setBackgroundLockTimeoutSeconds] + invalidate
/// `backgroundLockTimeoutProvider`，[AppLockGuard] 通过 listen 即时更新阈值
/// （不重建 Notifier，会话状态保留）。
class _BackgroundTimeoutTile extends ConsumerWidget {
  const _BackgroundTimeoutTile();

  String _label(BuildContext context, int seconds) {
    if (seconds == 0) return context.l10n.lockLockNow;
    if (seconds < 60) return context.l10n.lockSeconds(seconds);
    if (seconds < 3600) {
      final m = seconds ~/ 60;
      return context.l10n.lockMinutes(m);
    }
    final h = seconds ~/ 3600;
    return context.l10n.lockHours(h);
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref, int current) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<int>(
          groupValue: current,
          onChanged: (v) {
            if (v == null) return;
            Navigator.of(ctx).pop(v);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.lockBackgroundTimeout,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              for (final option in kBackgroundLockTimeoutOptions)
                RadioListTile<int>(
                  value: option,
                  title: Text(_label(context, option)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selected == null || selected == current) return;
    await ref
        .read(appLockControllerProvider)
        .setBackgroundLockTimeoutSeconds(selected);
    ref.invalidate(backgroundLockTimeoutProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTimeout = ref.watch(backgroundLockTimeoutProvider);
    return asyncTimeout.when(
      loading: () => ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(context.l10n.lockBackgroundTimeout),
        subtitle: Text(context.l10n.lockBiometricReadingPrefs),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(context.l10n.lockBackgroundTimeout),
        subtitle: Text(context.l10n.readFailedWithError(e.toString())),
        enabled: false,
      ),
      data: (seconds) => ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(context.l10n.lockBackgroundTimeout),
        subtitle: Text(
          seconds == 0
              ? context.l10n.lockLockNowDesc
              : context.l10n.lockTimeoutDesc(_label(context, seconds)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _onTap(context, ref, seconds),
      ),
    );
  }
}

/// Step 14.4：隐私模式开关 ListTile。
///
/// **独立于应用锁开启状态**——隐私模式与"锁屏"是两种正交防护，所以挂在 enabled
/// 块外。开关切换路径：
/// 1. UI 调 [AppLockController.setPrivacyMode]——内部先打 native（FLAG_SECURE /
///    iOS overlay enabled flag）再写 secure storage；
/// 2. await 后 invalidate [privacyModeProvider] 让 ListTile 重建展示新状态。
///
/// 副标题文案根据平台差异化：Android 强调"防截屏"，iOS 仅强调"多任务遮盖"。
class _PrivacyModeToggle extends ConsumerWidget {
  const _PrivacyModeToggle();

  Future<void> _onChange(WidgetRef ref, bool next) async {
    await ref.read(appLockControllerProvider).setPrivacyMode(next);
    ref.invalidate(privacyModeProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEnabled = ref.watch(privacyModeProvider);
    return asyncEnabled.when(
      loading: () => ListTile(
        leading: const Icon(Icons.visibility_off_outlined),
        title: Text(context.l10n.lockPrivacyMode),
        subtitle: Text(context.l10n.lockBiometricReadingPrefs),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.visibility_off_outlined),
        title: Text(context.l10n.lockPrivacyMode),
        subtitle: Text(context.l10n.readFailedWithError(e.toString())),
        enabled: false,
      ),
      data: (enabled) => SwitchListTile(
        secondary: const Icon(Icons.visibility_off_outlined),
        title: Text(context.l10n.lockPrivacyMode),
        subtitle: Text(
          enabled
              ? context.l10n.lockPrivacyEnabledDesc
              : context.l10n.lockPrivacyDisabledDesc,
        ),
        value: enabled,
        onChanged: (v) => _onChange(ref, v),
      ),
    );
  }
}
