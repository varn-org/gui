import QuartzCore
import UIKit

/// Drives a Varn GUI application on iOS, owning the run loop the engine is advanced from.
///
/// The engine is never given a thread of its own. The chunk is loaded and then advanced one tick at a
/// time from a display link on the main thread, so every host call the script makes arrives on the
/// thread that owns the interface and the renderer touches its views with no dispatch and no lock.
public final class VarnGUIHost {
    private let runtime: VarnRuntimeDriving
    private let renderer: VarnRenderer
    private let surface: UIView

    private var link: CADisplayLink?
    private var keyboardHeight: CGFloat = 0
    private var reportedSize: CGSize = .zero
    private var reportedInsets: UIEdgeInsets = .zero
    private var reportedAppearance: UIUserInterfaceStyle = .unspecified

    /// Called with anything that went wrong where the application could not be told itself.
    public var onProblem: ((String) -> Void)?

    public init(runtime: VarnRuntimeDriving, surface: UIView) {
        self.runtime = runtime
        self.surface = surface
        self.renderer = VarnRenderer(surface: surface, emit: { id, name, payload in
            runtime.emit("gui.event", VarnJSON.text(["id": id, "name": name, "payload": payload]))
        })
    }

    /// Runs an application archive, which is the same file the Android and web hosts run.
    ///
    /// The framework is Lua carried in the bundle, so the engine is told where it sits and requires it
    /// from there. Nothing is copied and nothing is extracted, because the files are already on disk.
    public func start(archive: URL, framework: URL, cache: URL) throws {
        register()
        observeKeyboard()

        let source = """
            package.path = "\(framework.path)/?.lua;\(framework.path)/?/init.lua;" .. package.path
            require("gui.host.launch").start({
                path = "\(archive.path)",
                cache = "\(cache.path)",
                onProblem = function(problem) host.gui_problem({ problem = problem }) end,
            })
        """

        let code = runtime.load(source: source, chunkName: "=varn-gui")
        if code != 0 {
            throw RendererError.missing("the engine rejected the application with code \(code)")
        }

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    public func stop() {
        link?.invalidate()
        link = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func register() {
        runtime.register("gui_apply") { [weak self] json in
            guard let self, let ops = VarnJSON.array(json) else {
                return "null"
            }

            do {
                try self.renderer.apply(ops)
            } catch {
                return VarnJSON.text(["error": "\(error)"])
            }

            return "null"
        }

        runtime.register("gui_measure") { [weak self] json in
            guard let self, let request = VarnJSON.object(json) else {
                return "null"
            }

            let text = request["text"] as? String ?? ""
            let style = request["style"] as? [String: Any] ?? [:]
            let bound = VarnValue.number(request["bound"])

            return VarnJSON.text(self.renderer.measureText(text, style: style, bound: bound))
        }

        runtime.register("gui_invoke") { [weak self] json in
            guard let self, let request = VarnJSON.object(json) else {
                return "false"
            }

            let id = request["id"] as? Int ?? 0
            let method = request["method"] as? String ?? ""
            let arguments = request["arguments"] as? [String: Any] ?? [:]

            return ((try? self.renderer.invoke(id: id, method: method, arguments: arguments)) ?? false)
                ? "true" : "false"
        }

        runtime.register("gui_capabilities") { [weak self] _ in
            VarnJSON.text(self?.renderer.capabilities ?? [:])
        }

        runtime.register("gui_surface") { [weak self] _ in
            VarnJSON.text(self?.renderer.surfaceDescription() ?? [:])
        }

        // What goes wrong where nothing can be returned to reaches the host, which has a screen. The
        // engine's log does not, and a reader looking at a blank application is told nothing by it.
        runtime.register("gui_problem") { [weak self] json in
            guard let self, let request = VarnJSON.object(json) else {
                return "null"
            }

            self.onProblem?(request["problem"] as? String ?? "the application failed")
            return "null"
        }

        runtime.register("gui_measure_control") { [weak self] json in
            guard let self, let request = VarnJSON.object(json), let type = request["type"] as? String else {
                return "null"
            }

            return VarnJSON.text(self.renderer.measureControl(type))
        }

        runtime.register("gui_register_font") { [weak self] json in
            guard let self, let request = VarnJSON.object(json), let path = request["path"] as? String else {
                return VarnJSON.text(["error": "a font is registered by the path it is carried at"])
            }

            // A font that cannot be registered is answered rather than swallowed, or a style naming that
            // family draws in the system font instead and nobody is ever told the file was not read.
            do {
                try self.renderer.registerFont(path: path)
            } catch {
                return VarnJSON.text(["error": "\(error)"])
            }

            self.runtime.emit("gui.fontsRegistered", "{}")
            return "null"
        }
    }

    /// Reports the keyboard as a height, which the tree treats as a layout input rather than a platform.
    private func observeKeyboard() {
        let centre = NotificationCenter.default

        centre.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }

            let covered = max(0, self.surface.bounds.maxY - self.surface.convert(frame, from: nil).minY)
            self.report(keyboard: covered)
        }

        centre.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.report(keyboard: 0)
        }
    }

    private func report(keyboard height: CGFloat) {
        guard height != keyboardHeight else {
            return
        }

        keyboardHeight = height
        runtime.emit("gui.keyboard", VarnJSON.text(["height": height]))
    }

    @objc private func tick() {
        reportSurface()
        runtime.poll()
    }

    /// Tells the engine about a rotation, a new safe area or a change of appearance.
    private func reportSurface() {
        let size = surface.bounds.size
        let insets = surface.safeAreaInsets
        let appearance = surface.traitCollection.userInterfaceStyle

        if appearance != reportedAppearance {
            reportedAppearance = appearance
            runtime.emit("gui.appearance", VarnJSON.text(["appearance": appearance == .dark ? "dark" : "light"]))
        }

        guard size != reportedSize || insets != reportedInsets else {
            return
        }

        reportedSize = size
        reportedInsets = insets

        runtime.emit("gui.resize", VarnJSON.text([
            "width": size.width,
            "height": size.height,
            "safeArea": [
                "top": insets.top,
                "right": insets.right,
                "bottom": insets.bottom,
                "left": insets.left,
            ],
        ]))
    }
}

/// What the host needs of a runtime, so the renderer can be driven by a test as well as by the engine.
public protocol VarnRuntimeDriving: AnyObject {
    @discardableResult func register(_ name: String, _ handler: @escaping (String) -> String?) -> Bool
    @discardableResult func emit(_ name: String, _ jsonArgument: String) -> Bool
    @discardableResult func load(source: String, chunkName: String) -> Int32
    @discardableResult func poll() -> Bool
}

/// Turns what crosses the bridge between json text and Foundation values.
enum VarnJSON {
    static func text(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
              let encoded = String(data: data, encoding: .utf8) else {
            return "null"
        }

        return encoded
    }

    static func object(_ json: String) -> [String: Any]? {
        decode(json) as? [String: Any]
    }

    static func array(_ json: String) -> [[String: Any]]? {
        decode(json) as? [[String: Any]]
    }

    private static func decode(_ json: String) -> Any? {
        guard let data = json.data(using: .utf8) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}
