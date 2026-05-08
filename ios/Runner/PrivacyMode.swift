import Flutter
import UIKit

/// Step 14.4 隐私模式 —— iOS 多任务预览遮盖。
///
/// iOS 在 `applicationWillResignActive`（→ scene 级别等价于 `sceneWillResignActive`）
/// 截一帧用作 App Switcher 缩略图；只要在该回调里把 keyWindow 顶部叠一个不透明
/// View，截到的就是遮盖层而不是真实页面。didBecomeActive 时再移除。
///
/// 设计要点：
/// - 共享单例 + `enabled` flag —— Dart 侧通过 `bianbian/privacy` MethodChannel 设置；
/// - overlay 直接挂在 keyWindow 上，避免新建 UIWindow 与 statusBar 抢层级；
/// - hideOverlay 永远幂等 —— 不依赖 enabled 状态，避免 enabled 在被关闭瞬间残留 view。
final class PrivacyMode {
    static let shared = PrivacyMode()

    var enabled = false
    private var overlay: UIView?
    private static let overlayTag = 0xB1AB1A

    func showOverlay(in scene: UIScene) {
        guard enabled else { return }
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = windowScene.windows.first(where: { $0.isKeyWindow })
            ?? windowScene.windows.first
        guard let target = window else { return }
        if let existing = target.viewWithTag(Self.overlayTag) {
            existing.removeFromSuperview()
        }
        let view = UIView(frame: target.bounds)
        view.tag = Self.overlayTag
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.backgroundColor = UIColor(
            red: 1.0, green: 0.95, blue: 0.86, alpha: 1.0
        )
        let label = UILabel(frame: view.bounds)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.text = "边边记账"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        label.textColor = UIColor(
            red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0
        )
        view.addSubview(label)
        target.addSubview(view)
        overlay = view
    }

    func hideOverlay() {
        overlay?.removeFromSuperview()
        overlay = nil
    }
}
