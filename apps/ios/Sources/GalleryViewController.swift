import UIKit

/// Shows the gallery, which is the packed archive the Android and web hosts run unchanged.
final class GalleryViewController: UIViewController {
    private var host: VarnGUIHost?
    private weak var banner: UIView?
    private let surface = UIView()

    /// Draws the system's own bars the way the tree asked for, which only the window's controller may say.
    override var preferredStatusBarStyle: UIStatusBarStyle {
        VarnSystemBars.style
    }

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

    /// Shows what went wrong as something a reader can put away, rather than as part of the screen.
    ///
    /// Drawn into the view it stayed there for the rest of the session, carried from screen to screen by
    /// a reader who had no way of dismissing it.
    private func report(_ message: String) {
        banner?.removeFromSuperview()

        let banner = UIView()
        let label = UILabel()
        let dismiss = UIButton(type: .close)

        banner.backgroundColor = UIColor.systemRed
        banner.layer.cornerRadius = 12
        banner.translatesAutoresizingMaskIntoConstraints = false

        label.text = message
        label.textColor = .white
        label.numberOfLines = 4
        label.font = .preferredFont(forTextStyle: .footnote)
        label.translatesAutoresizingMaskIntoConstraints = false

        dismiss.tintColor = .white
        dismiss.translatesAutoresizingMaskIntoConstraints = false
        dismiss.addAction(UIAction { [weak banner] _ in banner?.removeFromSuperview() }, for: .touchUpInside)

        banner.addSubview(label)
        banner.addSubview(dismiss)
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10),

            dismiss.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            dismiss.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -8),
            dismiss.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
        ])

        self.banner = banner
    }
}
