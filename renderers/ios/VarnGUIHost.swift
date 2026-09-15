import QuartzCore
import UIKit

/// Drives a Varn GUI application on iOS, owning the run loop the engine is advanced from.
///
/// The engine is never given a thread of its own. The chunk is loaded and then advanced one tick at a
/// time from a display link on the main thread, so every host call the script makes arrives on the
/// thread that owns the interface and the renderer touches its views with no dispatch and no lock.
public final class VarnGUIHost {
    /// How far, or how fast, a drag from the edge counts as leaving the screen.
    private static let backTravel: CGFloat = 60
    private static let backSpeed: CGFloat = 400

    private let runtime: VarnRuntimeDriving
    private let renderer: VarnRenderer
    private let surface: UIView

    private var link: CADisplayLink?
    private var started = false
    private var watching: [NSObjectProtocol] = []
    private var gestures: [UIGestureRecognizer] = []
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
    /// Takes a link while the application is running, which is what a deep link and an app link arrive as.
    ///
    /// Where the application was asked to be is what a router opens on, so one that arrives before the
    /// engine has started is held rather than dropped, and one that arrives after is reported.
    public func open(address: String) {
        renderer.address = address

        guard started else {
            return
        }

        runtime.emit("gui.address", VarnJSON.text(["address": address]))
    }

    public func start(archive: URL, framework: URL, cache: URL, address: String = "/") throws {
        renderer.address = address
        started = true

        register()
        observeKeyboard()
        observeLifecycle()
        dismissKeyboardOnPress()
        observeBackGesture()

        let source = """
            package.path = "\(framework.path)/?.lua;\(framework.path)/?/init.lua;" .. package.path
            require("gui.host.launch").start({
                path = "\(archive.path)",
                framework = "\(framework.path)",
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

    /// Keeps a file where the system keeps them, or hands it to the sheet a reader sends one through.
    ///
    /// What a camera captures is written where the application may write, which nothing outside it can
    /// reach: a reader who took a picture has nothing until it is somewhere they can open again. Saving
    /// is the photo library, which is what a phone means by kept, and sharing is the system's own sheet,
    /// where they may also put it somewhere the application never hears about.
    private func keep(_ request: [String: Any]) {
        let ticket = request["ticket"] as? Int ?? 0
        let path = request["path"] as? String ?? ""
        let answer = { [weak self] (reply: [String: Any]) in
            var carried = reply
            carried["ticket"] = ticket
            self?.runtime.emit("gui.files", VarnJSON.text(carried))
        }

        guard FileManager.default.fileExists(atPath: path) else {
            answer(["problem": "there is no file at \(path)"])
            return
        }

        if request["action"] as? String == "share" {
            share(URL(fileURLWithPath: path), title: request["title"] as? String, answer: answer)
            return
        }

        VarnLibrary.keep(URL(fileURLWithPath: path)) { problem in
            answer(problem == nil ? ["path": path] : ["problem": problem ?? ""])
        }
    }

    /// Answers what the keystore holds, which is a value of whatever shape the tree wrote.
    ///
    /// A value crosses as json so it comes back as what it was rather than as the text of what it was,
    /// and it is the bytes of that json the keychain holds.
    private func preference(_ request: [String: Any]) {
        let ticket = request["ticket"] as? Int ?? 0
        let name = request["name"] as? String ?? ""

        let answer = { [weak self] (reply: [String: Any]) in
            var carried = reply
            carried["ticket"] = ticket
            self?.runtime.emit("gui.preferences", VarnJSON.text(carried))
        }

        do {
            switch request["action"] as? String {
            case "set":
                let written = VarnJSON.text(request["value"] ?? NSNull())

                try VarnPreferences.set(name, Data(written.utf8))
                answer([:])

            case "get":
                guard let held = try VarnPreferences.get(name),
                      let written = String(data: held, encoding: .utf8) else {
                    answer([:])
                    return
                }

                answer(["value": VarnJSON.value(written) ?? NSNull()])

            case "remove":
                try VarnPreferences.remove(name)
                answer([:])

            case "clear":
                try VarnPreferences.clear()
                answer([:])

            case "names":
                answer(["value": try VarnPreferences.names()])

            default:
                answer(["problem": "a preference is set, read, removed, cleared or listed"])
            }
        } catch {
            answer(["problem": "\(error)"])
        }
    }

    private func share(_ file: URL, title: String?, answer: @escaping ([String: Any]) -> Void) {
        guard let owner = surface.window?.rootViewController else {
            answer(["problem": "there is nothing to present a sheet from"])
            return
        }

        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)

        sheet.completionWithItemsHandler = { _, _, _, problem in
            answer(problem == nil ? ["path": file.path] : ["problem": problem?.localizedDescription ?? ""])
        }

        // A phone presents a sheet over what is on screen and a tablet points one at what was pressed,
        // which it refuses to present at all without.
        sheet.popoverPresentationController?.sourceView = surface
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: surface.bounds.midX, y: surface.bounds.maxY - 1, width: 1, height: 1
        )

        owner.present(sheet, animated: true)
    }

    /// Reports a drag from the leading edge, which is how a reader leaves a screen on iOS.
    ///
    /// It has to be an edge recogniser and it has to wait for the finger. A swipe recogniser over the
    /// whole surface takes any rightward move anywhere — dragging a carousel, a slider or a checkbox
    /// left the screen — and it recognises the moment the movement passes its threshold, so the screen
    /// went before the finger was lifted.
    private func observeBackGesture() {
        let drag = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(dragged))

        drag.edges = .left
        gestures.append(drag)
        surface.addGestureRecognizer(drag)
    }

    @objc private func dragged(_ recogniser: UIScreenEdgePanGestureRecognizer) {
        guard recogniser.state == .ended else {
            return
        }

        // Far enough or fast enough, which is what the system asks of the same gesture.
        let travelled = recogniser.translation(in: surface).x
        let speed = recogniser.velocity(in: surface).x

        guard travelled > VarnGUIHost.backTravel || speed > VarnGUIHost.backSpeed else {
            return
        }

        runtime.emit("gui.back", "{}")
    }

    /// Takes the keyboard away when a press lands anywhere but on what is being typed into.
    ///
    /// Every application on a phone does this, and nothing in a tree can, since only the surface sees a
    /// press that landed on none of its nodes. The recogniser lets the touch through, so whatever was
    /// under the finger still receives it.
    private func dismissKeyboardOnPress() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))

        tap.cancelsTouchesInView = false
        gestures.append(tap)
        surface.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        surface.endEditing(true)
    }

    /// Takes the surface down, which is the tree as well as the loop that was driving it.
    ///
    /// Stopping the pump alone leaves every screen mounted: a timer a screen asked for goes on firing
    /// and everything a node opened is still open, on an interface nobody is looking at. A host event
    /// is delivered by the loop rather than in place, so the tree comes down on a tick the pump has to
    /// still be there to take. What was set up to watch the window is given back with it, since a
    /// notification and a recogniser both outlive the surface otherwise.
    public func stop() {
        runtime.emit("gui.stop", "{}")
        runtime.poll()

        link?.invalidate()
        link = nil

        for token in watching {
            NotificationCenter.default.removeObserver(token)
        }

        watching.removeAll()

        for recogniser in gestures {
            surface.removeGestureRecognizer(recogniser)
        }

        gestures.removeAll()
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

        runtime.register("gui_files") { [weak self] json in
            guard let self, let request = VarnJSON.object(json) else {
                return "null"
            }

            self.keep(request)
            return "null"
        }

        runtime.register("gui_preferences") { [weak self] json in
            guard let self, let request = VarnJSON.object(json) else {
                return "null"
            }

            self.preference(request)
            return "null"
        }

        runtime.register("gui_theme") { [weak self] json in
            guard let self, let ground = VarnJSON.object(json) else {
                return "null"
            }

            self.renderer.showTheme(ground)
            return "null"
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

        watching.append(centre.addObserver(
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
        })

        watching.append(centre.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.report(keyboard: 0)
        })
    }

    /// Reports where the application is, and asks the engine for memory back when the platform wants it.
    private func observeLifecycle() {
        let centre = NotificationCenter.default

        for notice in VarnLifecycle.notices {
            watching.append(centre.addObserver(forName: notice, object: nil, queue: .main) { [weak self] note in
                guard let self, let state = VarnLifecycle.state(for: note.name) else {
                    return
                }

                self.runtime.emit("gui.lifecycle", VarnJSON.text(["state": state]))

                // A tick is what carries a commit to the screen, and one is not coming while the
                // application is going away, so the work the moment produced is pumped here instead.
                self.runtime.poll()
            })
        }

        watching.append(centre.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.runtime.emit("gui.memory", "{}")
            self?.runtime.poll()
        })
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

    static func value(_ json: String) -> Any? {
        decode(json)
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
