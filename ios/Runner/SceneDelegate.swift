import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    private func isShareURL(_ url: URL) -> Bool {
        url.scheme == "ShareMedia-com.compete.youcam2"
    }

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(
            scene,
            willConnectTo: session,
            options: connectionOptions
        )
        guard
            let url = connectionOptions.urlContexts.first?.url,
            isShareURL(url)
        else { return }
        (UIApplication.shared.delegate as? AppDelegate)?.receiveSharedProduct()
    }

    override func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        guard let url = URLContexts.first?.url, isShareURL(url) else {
            super.scene(scene, openURLContexts: URLContexts)
            return
        }
        (UIApplication.shared.delegate as? AppDelegate)?.receiveSharedProduct()
    }
}
