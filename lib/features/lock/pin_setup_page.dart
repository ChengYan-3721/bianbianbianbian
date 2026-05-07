import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_providers.dart';
import 'pin_credential.dart';

/// PIN 设置 / 修改页。
///
/// - [PinSetupMode.setup]：首次开启应用锁时使用。两次输入 PIN 一致后调
///   [AppLockController.setupPin] 写入凭据 + 置 enabled=true，pop(true)。
/// - [PinSetupMode.change]：已开启应用锁后修改 PIN。**调用方必须在 push 本页前
///   完成对旧 PIN 的验证**（走 `PinUnlockPage`）；本页只负责采集新 PIN，不再做
///   旧 PIN 校验。两次输入新 PIN 一致后调 [AppLockController.changePin]，pop(true)。
enum PinSetupMode { setup, change }

class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key, required this.mode});

  final PinSetupMode mode;

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  /// 两阶段：第一次输入 → 第二次确认。
  _SetupStage _stage = _SetupStage.enter;

  String _firstPin = '';
  final _firstCtrl = TextEditingController();
  final _secondCtrl = TextEditingController();
  String? _errorText;
  bool _busy = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _secondCtrl.dispose();
    super.dispose();
  }

  String get _title =>
      widget.mode == PinSetupMode.setup ? '设置应用锁 PIN' : '修改应用锁 PIN';

  String get _subtitle => switch (_stage) {
        _SetupStage.enter =>
          '请输入 $kPinMinLength-$kPinMaxLength 位数字 PIN，避免使用生日等易猜组合。',
        _SetupStage.confirm => '请再次输入相同 PIN 以确认。',
      };

  Future<void> _onContinue() async {
    if (_busy) return;
    setState(() => _errorText = null);

    if (_stage == _SetupStage.enter) {
      final pin = _firstCtrl.text;
      final formatError = validatePinFormat(pin);
      if (formatError != null) {
        setState(() => _errorText = formatError);
        return;
      }
      setState(() {
        _firstPin = pin;
        _stage = _SetupStage.confirm;
        _secondCtrl.clear();
      });
      return;
    }

    // confirm stage
    final pin = _secondCtrl.text;
    if (pin != _firstPin) {
      setState(() {
        _errorText = '两次输入不一致，请重新设置';
        _stage = _SetupStage.enter;
        _firstCtrl.clear();
        _secondCtrl.clear();
        _firstPin = '';
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final controller = ref.read(appLockControllerProvider);
      if (widget.mode == PinSetupMode.setup) {
        await controller.setupPin(pin);
      } else {
        await controller.changePin(pin);
      }
      if (!mounted) return;
      ref.invalidate(appLockEnabledProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '保存失败：$e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _stage == _SetupStage.enter ? _firstCtrl : _secondCtrl;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _subtitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              key: ValueKey('pin_input_${_stage.name}'),
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: kPinMaxLength,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(kPinMaxLength),
              ],
              decoration: InputDecoration(
                labelText: _stage == _SetupStage.enter ? '新 PIN' : '确认 PIN',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _onContinue(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _onContinue,
              child: Text(
                _stage == _SetupStage.enter ? '下一步' : '保存',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SetupStage { enter, confirm }
