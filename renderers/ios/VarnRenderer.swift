import UIKit

/// Applies the operations a commit carries to real UIKit views, and reports events back.
///
/// It decides nothing. Every size, colour and position arrives already resolved, which is what keeps
/// this renderer in agreement with the ones on Android and the web.
public final class VarnRenderer {
    public typealias EventSink = (Int, String, Any) -> Void

    private let surface: UIView
    private let emit: EventSink

    private var nodes: [Int: Node] = [:]
    private var measurements = NSCache<NSString, NSValue>()

    public let capabilities: [String: Bool] = [
        "text": true, "image": true, "list": true, "scroll": true, "input": true,
        "video": true, "webview": true, "canvas": true,
        "picker": true, "datepicker": true,
        "haptics": true, "safearea": true,
    ]

    public init(surface: UIView, emit: @escaping EventSink) {
        self.surface = surface
        self.emit = emit
    }

    private final class Node {
        let view: UIView
        let type: String
        var props: [String: Any] = [:]

        init(view: UIView, type: String) {
            self.view = view
            self.type = type
        }
    }

    /// Applies one batch, which is the whole of what a commit does to the interface.
    public func apply(_ ops: [[String: Any]]) throws {
        for op in ops {
            guard let kind = op["op"] as? String else {
                throw RendererError.malformed("an operation carried no op")
            }

            switch kind {
            case "create": try create(op)
            case "update": try update(op)
            case "insert", "move": try place(op)
            case "remove": remove(op["id"] as? Int)
            case "frame": try frame(op)
            default: throw RendererError.malformed("unknown operation \(kind)")
            }
        }
    }

    private func create(_ op: [String: Any]) throws {
        guard let id = op["id"] as? Int, let type = op["type"] as? String else {
            throw RendererError.malformed("a create carried no id or type")
        }

        let view = VarnViewFactory.make(type: type)
        view.translatesAutoresizingMaskIntoConstraints = true
        view.tag = id

        let node = Node(view: view, type: type)
        nodes[id] = node

        if let props = op["props"] as? [String: Any] {
            try apply(props: props, to: node, id: id)
        }
    }

    private func expect(_ id: Int?) throws -> Node {
        guard let id, let node = nodes[id] else {
            throw RendererError.missing("the batch touched node \(id ?? -1), which was never created")
        }

        return node
    }

    private func update(_ op: [String: Any]) throws {
        let node = try expect(op["id"] as? Int)
        guard let props = op["props"] as? [String: Any] else {
            throw RendererError.malformed("an update carried no props")
        }

        try apply(props: props, to: node, id: op["id"] as? Int ?? 0)
    }

    /// The props that build what a node holds, which are applied before the ones that choose among it.
    ///
    /// A batch carries props as a map, so they arrive in no order at all. Rebuilding the segments of a
    /// control after the chosen one was set would drop the choice on whichever batch happened to be
    /// ordered that way, which is a defect that comes and goes rather than one that can be found.
    private static let structural: Set<String> = ["segments", "options", "count", "text", "title", "label"]

    private func apply(props: [String: Any], to node: Node, id: Int) throws {
        let ordered = props.sorted { first, second in
            Self.structural.contains(first.key) && !Self.structural.contains(second.key)
        }

        for (key, raw) in ordered {
            let value = VarnValue.isRemoved(raw) ? nil : raw
            node.props[key] = value

            if key == "style" {
                VarnStyle.apply(value as? [String: Any] ?? [:], to: node.view, type: node.type)
            } else {
                VarnProps.apply(key: key, value: value, to: node.view, type: node.type, id: id, emit: emit)
            }
        }
    }

    private func place(_ op: [String: Any]) throws {
        let node = try expect(op["id"] as? Int)
        guard let parent = op["parent"] as? Int, let index = op["index"] as? Int else {
            throw RendererError.malformed("a placement carried no parent or index")
        }

        let container = parent == 0 ? surface : try expect(parent).view
        let target = VarnViewFactory.contentView(of: container)

        node.view.removeFromSuperview()

        let position = min(max(index - 1, 0), target.subviews.count)
        target.insertSubview(node.view, at: position)
    }

    private func remove(_ id: Int?) {
        guard let id, let node = nodes[id] else {
            return
        }

        node.view.removeFromSuperview()
        nodes.removeValue(forKey: id)
    }

    private func frame(_ op: [String: Any]) throws {
        let node = try expect(op["id"] as? Int)

        let frame = CGRect(
            x: VarnValue.number(op["x"]) ?? 0,
            y: VarnValue.number(op["y"]) ?? 0,
            width: VarnValue.number(op["width"]) ?? 0,
            height: VarnValue.number(op["height"]) ?? 0
        )

        node.view.frame = frame

        // A pill radius is only known to be one once the box has a size, so it is held to what the box
        // can hold here as well as where the style is applied.
        let style = node.props["style"] as? [String: Any] ?? [:]
        let radius = VarnStyle.cornerRadius(VarnValue.number(style["radius"]) ?? 0, in: frame.size)

        node.view.layer.cornerRadius = radius
        node.view.clipsToBounds = VarnStyle.clips(style, node.view, radius: radius)

        // The engine decided how many lines fit, so a label never wraps into one it has no room for.
        if let label = node.view as? UILabel, label.font.lineHeight > 0 {
            label.numberOfLines = max(1, Int(frame.height / label.font.lineHeight))
            label.lineBreakMode = .byTruncatingTail
        }
    }

    /// Answers what a string measures, which the layout engine caches and never guesses at.
    public func measureText(_ text: String, style: [String: Any], bound: CGFloat?) -> [String: CGFloat] {
        let font = VarnStyle.font(from: style)
        let key = "\(text)|\(font.fontName)|\(font.pointSize)|\(bound ?? -1)" as NSString

        if let cached = measurements.object(forKey: key)?.cgSizeValue {
            return ["width": cached.width, "height": cached.height]
        }

        // A bound of zero is a node that has not been measured yet, not a node with no room.
        let usable = (bound ?? 0) > 0 ? bound! : CGFloat.greatestFiniteMagnitude
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let single = (text as NSString).size(withAttributes: attributes)

        // A label lays its own text out with `size(withAttributes:)`, so a line that fits is measured
        // the same way here. Anything wider is measured against the bound, where it wraps.
        var measured = single

        if single.width > usable {
            measured = (text as NSString).boundingRect(
                with: CGSize(width: usable, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            ).size
        }

        let size = CGSize(width: ceil(measured.width), height: ceil(measured.height))
        measurements.setObject(NSValue(cgSize: size), forKey: key)
        return ["width": size.width, "height": size.height]
    }

    /// Answers the size the platform draws a control at, which is the one thing about it Lua cannot know.
    ///
    /// A number written into the tree is a number that was true of one platform on one day: a switch was
    /// 51 across until it was 61, and a frame worked out from the old one spills the control out of the
    /// box it was given.
    public func measureControl(_ type: String) -> [String: CGFloat] {
        let control = VarnViewFactory.make(type: type)
        var size = control.intrinsicContentSize

        // A wheel and a chooser answer nothing until they are asked to fit, so both questions are put.
        if size.width <= 0 || size.height <= 0 {
            let fitted = control.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            size = CGSize(width: max(size.width, fitted.width), height: max(size.height, fitted.height))
        }

        return [
            "width": max(0, size.width),
            "height": max(0, size.height),
        ]
    }

    /// Registers a font from the bundle, after which any style may name its family.
    public func registerFont(path: String) throws {
        guard let data = NSData(contentsOfFile: path),
              let provider = CGDataProvider(data: data),
              let font = CGFont(provider) else {
            throw RendererError.missing("the font at \(path) could not be read")
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            throw RendererError.missing("the font at \(path) was refused by the system")
        }

        measurements.removeAllObjects()
    }

    /// Reaches a node imperatively, which is what a ref calls through.
    public func invoke(id: Int, method: String, arguments: [String: Any]) throws -> Bool {
        let node = try expect(id)
        return try VarnActions.perform(method, on: node.view, arguments: arguments)
    }

    /// Answers the surface the engine lays out inside, plus the insets the platform reports.
    public func surfaceDescription() -> [String: Any] {
        let insets = surface.safeAreaInsets

        return [
            "width": surface.bounds.width,
            "height": surface.bounds.height,
            "scale": UIScreen.main.scale,
            "appearance": surface.traitCollection.userInterfaceStyle == .dark ? "dark" : "light",
            "safeArea": [
                "top": insets.top,
                "right": insets.right,
                "bottom": insets.bottom,
                "left": insets.left,
            ],
        ]
    }
}

public enum RendererError: Error {
    case malformed(String)
    case missing(String)
}

enum VarnValue {
    /// Answers a number whatever kind it arrived as, since json carries one as any of several.
    ///
    /// Casting `Any` straight to `CGFloat` succeeds only for the bridged kind, so a plain `Double` or
    /// `Int` would read as nothing at all and the value would silently be the default.
    static func number(_ value: Any?) -> CGFloat? {
        if let number = value as? NSNumber {
            return CGFloat(number.doubleValue)
        }

        if let double = value as? Double {
            return CGFloat(double)
        }

        if let whole = value as? Int {
            return CGFloat(whole)
        }

        return value as? CGFloat
    }

    /// The sentinel an update carries for a prop the new description no longer has.
    static func isRemoved(_ value: Any) -> Bool {
        if let text = value as? String {
            return text == "__varn_removed__"
        }

        return value is NSNull
    }
}
