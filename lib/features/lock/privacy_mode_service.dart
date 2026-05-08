import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Step 14.4：隐私模式 native 通道封装。
///
/// 与 native 端约定：MethodChannel `bianbian/privacy`，唯一方法 `setEnabled(bool)`。
/// 实现细节：
/// - Android：MainActivity.kt 调 `window.setFlags(FLAG_SECURE)` /
///   `clearFlags(FLAG_SECURE)`。FLAG_SECURE 是持久 flag，App 进程存活期间一直生效；
///   多任务预览自动黑屏，截屏 / 录屏被系统级阻止。
/// - iOS：AppDelegate.swift 把 `enabled` 写入 `PrivacyMode.shared`，由 SceneDelegate
///   在 `sceneWillResignActive` 时按需挂全屏遮盖 UIView，`sceneDidBecomeActive` 时
///   移除。iOS 系统不允许 App 阻止截屏，但能挡住多任务缩略图。
///
/// 设计要点：
/// - 抽象类 + 生产 / Fake 双实现 —— 单测可注入 [FakePrivacyModeService] 验证调用次
///   数与最近一次入参，无需触达 platform channel。
/// - 调用方（[PrivacyModeController] / main bootstrap）不关心平台差异，只负责把
///   true/false 转发下来。
abstract class PrivacyModeService {
  Future<void> setEnabled(bool enabled);
}

class MethodChannelPrivacyModeService implements PrivacyModeService {
  const MethodChannelPrivacyModeService([
    MethodChannel channel = const MethodChannel('bianbian/privacy'),
  ]) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      // 测试环境 / 不支持的平台（web / 桌面）会抛该异常 —— 静默吞掉。
      // 生产路径 Android / iOS 都注册了 channel，不会走到这里。
      debugPrint('PrivacyMode channel not available; ignoring setEnabled');
    } on PlatformException catch (e, st) {
      debugPrint('PrivacyMode setEnabled platform error: $e\n$st');
    }
  }
}

@visibleForTesting
class FakePrivacyModeService implements PrivacyModeService {
  bool? lastEnabled;
  int callCount = 0;

  @override
  Future<void> setEnabled(bool enabled) async {
    callCount++;
    lastEnabled = enabled;
  }
}
