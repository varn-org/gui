import UIKit

/// Shows the gallery, which is the packed archive the Android and web hosts run unchanged.
final class GalleryViewController: UIViewController {
    private var host: VarnGUIHost?
    private let surface = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        surface.frame = view.bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(surface)

        start()
    }

    private func start() {
        guard let archive = Bundle.main.url(forResource: "gallery", withExtension: "vap"),
              let resources = Bundle.main.resourceURL else {
            report("the application bundle carries no gallery.vap")
            return
        }

        guard let runtime = VarnRuntime() else {
            report("the engine could not be created")
            return
        }

        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("varn-gui", isDirectory: true)

        let host = VarnGUIHost(runtime: runtime, surface: surface)
        host.onProblem = { [weak self] problem in self?.report(problem) }
        self.host = host

        do {
            // The gui tree sits beside the archive in the bundle, so the resources directory is the root.
            try host.start(archive: archive, framework: resources, cache: cache)
        } catch {
            report("the gallery failed to start: \(error)")
        }
    }

    private func report(_ message: String) {
        let label = UILabel(frame: view.bounds.insetBy(dx: 24, dy: 24))
        label.text = message
        label.numberOfLines = 0
        label.textAlignment = .center
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(label)
    }
}
