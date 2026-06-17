import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

    private var privacyOverlay: UIView?

    // Hide vault contents in the app-switcher snapshot when leaving the foreground.
    override func sceneWillResignActive(_ scene: UIScene) {
        super.sceneWillResignActive(scene)
        guard let windowScene = scene as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = .black
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)
        privacyOverlay = overlay
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        privacyOverlay?.removeFromSuperview()
        privacyOverlay = nil
    }
}
