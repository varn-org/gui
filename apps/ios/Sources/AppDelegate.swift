import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let gallery = GalleryViewController()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        // A link the application was opened by arrives with the scene, and the router opens on it rather
        // than on wherever the entry point happens to start.
        if let opened = options.urlContexts.first?.url {
            gallery.opened = opened.absoluteString
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = gallery
        window.makeKeyAndVisible()
        self.window = window
    }

    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        guard let opened = contexts.first?.url else {
            return
        }

        gallery.open(address: opened.absoluteString)
    }
}
