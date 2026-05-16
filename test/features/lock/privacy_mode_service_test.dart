import 'package:bianbianbianbian/features/lock/privacy_mode_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 14.4 单测：[PrivacyModeService] 实现层。
///
/// 两条覆盖：
/// 1. [FakePrivacyModeService] 调用计数与最近一次入参——后续 settings widget /
///    provider 测试都靠它做断言。
/// 2. [MethodChannelPrivacyModeService] 通过 `TestDefaultBinaryMessenger` 把
///    `bianbian/privacy` 通道桩起来，验证 `setEnabled(true/false)` 正确序列化方法名
///    与参数；以及 `MissingPluginException` / `PlatformException` 都被静默吞掉
///    （生产路径不应该让 native 错误打死设置页）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakePrivacyModeService', () {
    test('初始 callCount=0 / lastEnabled=null', () {
      final fake = FakePrivacyModeService();
      expect(fake.callCount, 0);
      expect(fake.lastEnabled, isNull);
    });

    test('setEnabled 累加 callCount 并记录最近入参', () async {
      final fake = FakePrivacyModeService();
      await fake.setEnabled(true);
      expect(fake.callCount, 1);
      expect(fake.lastEnabled, isTrue);
      await fake.setEnabled(false);
      expect(fake.callCount, 2);
      expect(fake.lastEnabled, isFalse);
    });
  });

  group('MethodChannelPrivacyModeService', () {
    const channel = MethodChannel('bianbian/privacy');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('setEnabled(true) 触发一次 setEnabled / arguments=true', () async {
      const service = MethodChannelPrivacyModeService();
      await service.setEnabled(true);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setEnabled');
      expect(calls.single.arguments, isTrue);
    });

    test('setEnabled(false) 触发一次 setEnabled / arguments=false', () async {
      const service = MethodChannelPrivacyModeService();
      await service.setEnabled(false);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'setEnabled');
      expect(calls.single.arguments, isFalse);
    });

    test('PlatformException 被静默吞——生产路径不让 native 错误打死设置页', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'BOOM', message: 'native died');
      });
      const service = MethodChannelPrivacyModeService();
      // 不应抛——测试以"无异常逃逸"为通过。
      await service.setEnabled(true);
    });

    test('MissingPluginException 被静默吞——测试 / web 平台无 channel 实现',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      const service = MethodChannelPrivacyModeService();
      await service.setEnabled(true); // 无桩 → MissingPluginException → 静默
    });
  });
}
