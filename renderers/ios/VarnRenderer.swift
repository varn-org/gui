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
        "haptics": true, "safearea": true, "audio": true, "map": true, "location": true, "gradient": true, "blur": true,
    ]

    public init(surface: UIView, emit: @escaping EventSink) {
        self.surface = surface
        self.emit = emit
    }

    private final class Node {
        let view: UIView
        let type: String
        var props: [String: Any] = [:]

        /// Whether the node has been on screen once, which is what tells an arrival from a change.
        var settled = false

        /// Whether the arrival it was given is still waiting for the frame it is drawn against.
        var arriving = false

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

        node.settled = true
        node.arriving = node.props["enter"] != nil
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
    private static let structural: Set<String> = [
        "segments", "options", "count", "text", "title", "label", "transition", "enter",
    ]

    private func apply(props: [String: Any], to node: Node, id: Int) throws {
        let ordered = props.sorted { first, second in
            Self.structural.contains(first.key) && !Self.structural.contains(second.key)
        }

        for (key, raw) in ordered {
            let value = VarnValue.isRemoved(raw) ? nil : raw
            node.props[key] = value

            if key == "transition" || key == "enter" {
                continue
            }

            if key == "style" {
                apply(style: value as? [String: Any] ?? [:], to: node)
            } else {
                VarnProps.apply(key: key, value: value, to: node.view, type: node.type, id: id, emit: emit)
            }
        }

        (node.view as? VarnSettling)?.settle()
    }

    /// Applies a style, over time when the node was told how long the change should take.
    private func apply(style: [String: Any], to node: Node) {
        guard node.settled, let timing = VarnMotion.timing(node.props["transition"]) else {
            VarnStyle.apply(style, to: node.view, type: node.type)
            return
        }

        VarnMotion.animate(timing) { [view = node.view, type = node.type] in
            VarnStyle.apply(style, to: view, type: type)
        }
    }

    /// Draws the arrival of a node that was given a state to come from, once it knows what size it is.
    ///
    /// It waits for the frame because a state is written against the node it moves: a panel that arrives
    /// from the whole of its own height has no height to travel until the layout has given it one, and a
    /// view animated before it is placed has nothing to animate from.
    private func arrive(_ node: Node) {
        node.arriving = false

        guard let entering = node.props["enter"] as? [String: Any],
              let timing = VarnMotion.timing(node.props["transition"]) else {
            return
        }

        VarnMotion.arrive(
            node.view,
            entering: entering,
            settled: node.props["style"] as? [String: Any] ?? [:],
            type: node.type,
            timing: timing
        )
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

        // A frame is undefined while a view carries a transform, since UIKit works one out through the
        // other. A commit landing during an animation therefore moved the view for good, by however far
        // the animation had travelled by then. Bounds and centre mean the same thing whatever the
        // transform is, so a screen sliding in is placed as exactly as one standing still.
        //
        // Only the size is written, since a scrolling view's bounds origin is its content offset and a
        // zero written there puts every list back to the top on every commit.
        node.view.bounds = CGRect(origin: node.view.bounds.origin, size: frame.size)
        node.view.center = CGPoint(x: frame.midX, y: frame.midY)

        // A pill radius is only known to be one once the box has a size, so it is held to what the box
        // can hold here as well as where the style is applied.
        let style = node.props["style"] as? [String: Any] ?? [:]
        let radius = VarnStyle.cornerRadius(VarnValue.number(style["radius"]) ?? 0, in: frame.size)

        node.view.layer.cornerRadius = radius

        // What a map is looking at depends on how big it turned out to be, so it is settled with the
        // frame rather than only with the props, and a box held against an edge is held again from
        // wherever the frame has just put it.
        (node.view as? VarnSettling)?.settle()

        if (node.view as? VarnView)?.pinned != nil {
            (node.view.superview?.superview as? VarnCollectionView)?.hold()
        }
        node.view.clipsToBounds = VarnStyle.clips(style, node.view, radius: radius)

        // A label never wraps into a line it has no room for, unless the tree said how many it may run
        // to, which is a caller's own decision and not one a frame may take back.
        if let label = node.view as? UILabel, label.font.lineHeight > 0 {
            let declared = node.props["numberOfLines"] as? Int

            label.numberOfLines = declared ?? max(1, Int(frame.height / label.font.lineHeight))
            label.lineBreakMode = .byTruncatingTail
        }

        // A travel written as a share of the node is worked out against the size the layout has just
        // given it, rather than against the nothing it was when it was created. Only what the style
        // names is written: a node arriving carries its travel in `enter`, and clearing that here left
        // the arrival with nowhere to come from.
        if let transform = style["transform"] {
            VarnStyle.applyTransform(transform, to: node.view)
        }

        if node.arriving {
            arrive(node)
        }
    }

    /// Answers what a string measures, which the layout engine caches and never guesses at.
    public func measureText(_ text: String, style: [String: Any], bound: CGFloat?) -> [String: CGFloat] {
        let font = VarnStyle.font(from: style)
        let spacing = VarnValue.number(style["letterSpacing"]) ?? 0
        let leading = VarnValue.number(style["lineHeight"]) ?? 0
        let key = "\(text)|\(font.fontName)|\(font.pointSize)|\(spacing)|\(leading)|\(bound ?? -1)" as NSString

        if let cached = measurements.object(forKey: key)?.cgSizeValue {
            return ["width": cached.width, "height": cached.height]
        }

        // A bound of zero is a node that has not been measured yet, not a node with no room.
        let usable = (bound ?? 0) > 0 ? bound! : CGFloat.greatestFiniteMagnitude
        let attributes = VarnStyle.attributes(from: style)
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
    /// A variant names which of a control the tree asked for, since a wheel and a compact date are two
    /// different controls to lay out and only one of them is what the factory makes by default.
    public func measureControl(_ type: String, variant: String?) -> [String: CGFloat] {
        let control = VarnViewFactory.make(type: type)

        if variant == "wheel", let picker = control as? UIDatePicker {
            picker.preferredDatePickerStyle = .wheels
        }

        var size = control.intrinsicContentSize

        // A control answering `noIntrinsicMetric` for an axis is the platform saying it has no opinion
        // about that axis and fills whatever room it is given, which is what a slider does with a row.
        // Asking such a control to fit gives the smallest it can be drawn at, which is not an opinion:
        // a slider answered 37 points and was laid out as a thumb with no track beside it.
        if size.width == UIView.noIntrinsicMetric && size.height == UIView.noIntrinsicMetric {
            size = control.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
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
            "platform": "ios",
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
