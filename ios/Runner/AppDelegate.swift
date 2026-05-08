import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Step 14.4 隐私模式：注册 `bianbian/privacy` MethodChannel，接收 Dart 侧的
    // setEnabled(bool) 调用 —— 持久化到 PrivacyMode.shared.enabled，由 SceneDelegate
    // 在 sceneWillResignActive 时按需展示遮盖层。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BianbianPrivacyMode") {
      let channel = FlutterMethodChannel(
        name: "bianbian/privacy",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "setEnabled":
          guard let enabled = call.arguments as? Bool else {
            result(FlutterError(
              code: "INVALID_ARGUMENT",
              message: "setEnabled expects Bool argument",
              details: nil
            ))
            return
          }
          PrivacyMode.shared.enabled = enabled
          if !enabled {
            PrivacyMode.shared.hideOverlay()
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
