import Flutter
import UIKit

/// Step 14.4 隐私模式：scene 生命周期回调里挂 / 撤遮盖层。
///
/// iOS 13+ scene-based 架构中，App Switcher 缩略图截取发生在
/// `sceneWillResignActive`；`sceneDidBecomeActive` 是回到前台的最早回调。
class SceneDelegate: FlutterSceneDelegate {
  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    PrivacyMode.shared.showOverlay(in: scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    PrivacyMode.shared.hideOverlay()
  }
}
