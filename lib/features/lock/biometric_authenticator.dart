import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Step 14.2：生物识别接入层。
///
/// 把 `local_auth` 包成一层薄抽象，目的：
/// 1. 测试侧可注入 [FakeBiometricAuthenticator] 控制 supported / canCheck /
///    success 三个旋钮；
/// 2. 隔离 plugin 错误码——`local_auth` 3.x 在不支持设备 / 用户取消 / 系统取消
///    会抛 [LocalAuthException]；本层统一吞掉，把"是否通过"用 [BiometricResult]
///    返回，让 UI 走分支文案而不必关心 plugin 内部错误码命名。
///
/// 不持久化任何状态——是否开启生物识别由 `PinCredentialStore.readBiometricEnabled`
/// 管。
abstract class BiometricAuthenticator {
  /// 设备硬件 + 系统层面是否支持生物识别（指纹 / 面容 / 虹膜）。
  ///
  /// 注意：`local_auth.canCheckBiometrics` 在 3.x 含义改为"设备硬件具备生物识别能
  /// 力"——返回 true 不代表用户已录入；还要看 [hasEnrolledBiometrics]。
  Future<bool> isDeviceSupported();

  /// 用户在系统设置里录入了至少一种生物特征。
  Future<bool> hasEnrolledBiometrics();

  /// 弹出系统生物识别面板。[reason] 在 iOS 用作弹窗副标题文案。
  ///
  /// 返回：
  /// - [BiometricResult.success]：用户通过；
  /// - [BiometricResult.cancelled]：用户主动取消 / 系统取消（按 home 键、来电）；
  /// - [BiometricResult.lockedOut]：连续失败被 OS 临时锁定；
  /// - [BiometricResult.notAvailable]：硬件不支持 / 未录入；
  /// - [BiometricResult.failed]：用户输入错误未触发系统锁定（通常 OS 会自己重试，
  ///   走到这里大多是 plugin 通道异常）。
  Future<BiometricResult> authenticate({required String reason});
}

enum BiometricResult {
  success,
  cancelled,
  lockedOut,
  notAvailable,
  failed,
}

/// 生产实现——直接调 `local_auth` 3.x。
///
/// `LocalAuthentication.authenticate` 的契约：
/// - 返回 `true`：用户通过；
/// - 返回 `false`：用户输错（无副作用，不抛异常）；
/// - 抛 [LocalAuthException]：其他失败原因（取消 / 锁定 / 不可用 / 设备错误）。
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on LocalAuthException catch (e, st) {
      debugPrint('isDeviceSupported error: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> hasEnrolledBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on LocalAuthException catch (e, st) {
      debugPrint('canCheckBiometrics error: $e\n$st');
      return false;
    }
  }

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
        case LocalAuthExceptionCode.userRequestedFallback:
          return BiometricResult.cancelled;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return BiometricResult.lockedOut;
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          return BiometricResult.notAvailable;
        case LocalAuthExceptionCode.authInProgress:
        case LocalAuthExceptionCode.uiUnavailable:
        case LocalAuthExceptionCode.deviceError:
        case LocalAuthExceptionCode.unknownError:
          return BiometricResult.failed;
      }
    }
  }
}

/// 测试 / Riverpod override 用的可控实现。
@visibleForTesting
class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({
    this.deviceSupported = true,
    this.enrolled = true,
    this.nextResult = BiometricResult.success,
  });

  bool deviceSupported;
  bool enrolled;
  BiometricResult nextResult;

  /// 调用次数——测试可断言 PinUnlockPage 只在 init 阶段调一次。
  int authenticateCalls = 0;

  /// 上一次 authenticate 收到的 reason，便于断言文案。
  String? lastReason;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> hasEnrolledBiometrics() async => enrolled;

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    authenticateCalls++;
    lastReason = reason;
    return nextResult;
  }
}
