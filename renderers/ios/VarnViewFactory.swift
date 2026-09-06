import UIKit
import WebKit
import AVKit

/// Builds the UIKit view that stands for one node type.
enum VarnViewFactory {
    static func make(type: String) -> UIView {
        switch type {
        case "text", "richtext": return UILabel()
        case "image", "icon": return UIImageView()
        case "button": return VarnButton()
        case "pressable": return VarnPressableView()
        case "textinput", "searchbar": return VarnTextField()
        case "textarea": return VarnTextView()
        case "scroll": return VarnScrollView()
        case "keyboardavoiding": return VarnView()
        case "list", "sectionlist", "grid", "carousel": return VarnCollectionView()
        case "switch": return VarnSwitch()
        case "slider": return VarnSlider()
        case "stepper": return UIStepper()
        case "segmented": return UISegmentedControl()
        case "progress": return UIProgressView()
        case "activity": return UIActivityIndicatorView(style: .medium)
        case "video": return VarnVideoView()
        case "webview": return WKWebView()
        case "canvas": return VarnCanvasView()
        case "divider": return VarnDividerView()
        case "chip", "badge", "tooltip", "avatar": return VarnLabelView()
        case "rating": return VarnRatingView()
        case "checkbox": return VarnCheckView(shape: .square)
        case "radio": return VarnCheckView(shape: .circle)
        case "picker", "filepicker": return VarnChooserButton()
        case "datepicker": return VarnDatePicker(mode: .date)
        case "timepicker": return VarnDatePicker(mode: .time)
        case "colorpicker": return UIColorWell()
        case "refresh": return UIActivityIndicatorView(style: .medium)

        // A box is what the rest are: the engine positions them and their style paints them.
        default: return VarnView()
        }
    }

    /// Answers the view children are added to, which for a scrolling view is not the view itself.
    static func contentView(of view: UIView) -> UIView {
        if let collection = view as? VarnCollectionView {
            return collection.contentView
        }

        if let scroll = view as? VarnScrollView {
            return scroll.contentView
        }

        return view
    }
}

/// The plain box everything else is built from, which draws a background and a border and nothing else.
final class VarnView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        VarnHit.through(super.hitTest(point, with: event), self)
    }
}

/// Lets a finger through a box that has nothing to do with it, which is what a box usually is.
///
/// A screen is a tree of boxes, and one sitting inside something that can be pressed would take the
/// touch meant for it and answer nothing at all: pressing a row of the gallery did nothing, because an
/// ordinary box holding its two labels was what the finger landed on. A box the touch lands on with
/// nothing inside it wanting the point is not the answer, so the search carries on without it and finds
/// whatever was given a handler.
enum VarnHit {
    static func through(_ hit: UIView?, _ view: UIView) -> UIView? {
        if hit === view && view.gestureRecognizers?.isEmpty != false {
            return nil
        }

        return hit
    }
}

/// A box that shows one line of text, which is what a chip, a badge and a tooltip each are.
///
/// The engine sizes it, so the label simply fills it and is centred inside.
final class VarnLabelView: UIView {
    let label = UILabel()

    var insets: UIEdgeInsets = .zero {
        didSet { setNeedsLayout() }
    }

    init() {
        super.init(frame: .zero)
        label.textAlignment = .center
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.inset(by: insets)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        VarnHit.through(super.hitTest(point, with: event), self)
    }
}

/// A scrolling view whose content layer holds the children the engine placed inside it.
///
/// The engine measures how far the content reaches and sends it, so this decides nothing: it applies
/// the extent along the axis it was told to scroll.
final class VarnScrollView: UIScrollView {
    private let content = VarnContentView()
    private var horizontal = false
    private var extent: CGFloat = 0

    init() {
        super.init(frame: .zero)
        addSubview(content)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    var contentView: UIView { content }

    func setHorizontal(_ value: Bool) {
        horizontal = value
        resize()
    }

    func setContentExtent(_ value: CGFloat) {
        extent = value
        resize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        resize()
    }

    private func resize() {
        let size = horizontal
            ? CGSize(width: max(extent, bounds.width), height: bounds.height)
            : CGSize(width: bounds.width, height: max(extent, bounds.height))

        contentSize = size
        content.frame = CGRect(origin: .zero, size: size)
    }
}

final class VarnContentView: UIView {}

/// A box that shows a mark and a label, which is what a checkbox and a radio each are.
final class VarnCheckView: UIControl {
    enum Shape {
        case square
        case circle

        var marks: (on: String, off: String) {
            switch self {
            case .square: return ("checkmark.square.fill", "square")
            case .circle: return ("largecircle.fill.circle", "circle")
            }
        }
    }

    private let mark = UIImageView()
    private let shape: Shape
    let label = UILabel()

    private(set) var isChecked = false

    init(shape: Shape) {
        self.shape = shape
        super.init(frame: .zero)
        mark.contentMode = .scaleAspectFit
        mark.tintColor = .systemBlue
        addSubview(mark)
        addSubview(label)
        addTarget(self, action: #selector(toggle), for: .touchUpInside)
        setChecked(false)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func setChecked(_ checked: Bool) {
        isChecked = checked
        mark.image = UIImage(systemName: checked ? shape.marks.on : shape.marks.off)
    }

    @objc private func toggle() {
        setChecked(!isChecked)
        sendActions(for: .valueChanged)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let side = min(bounds.height, 22)
        mark.frame = CGRect(x: 0, y: (bounds.height - side) / 2, width: side, height: side)
        label.frame = CGRect(x: side + 6, y: 0, width: max(0, bounds.width - side - 6), height: bounds.height)
    }
}

/// A button that shows the choice a picker holds and asks the platform for a new one.
///
/// It carries no look of its own for the same reason a button does not: the style a commit sends is
/// what paints it, and a chooser is drawn as the field it stands beside rather than as a grey pill.
final class VarnChooserButton: UIButton {
    private var written: String?

    /// What the chooser offers, as the label a reader sees and the value a handler is given.
    var options: [(label: String, value: String)] = [] {
        didSet { rebuild() }
    }

    var onChoose: ((String) -> Void)?

    init() {
        super.init(frame: .zero)
        configuration = nil
        contentHorizontalAlignment = .leading
        showsMenuAsPrimaryAction = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Shows the option carrying a value as the chosen one, without reporting it as a choice.
    func choose(_ value: String?) {
        written = value
        rebuild()
    }

    /// Takes a choice a reader made, which is what an option in the menu does when it is picked.
    func pick(_ value: String) {
        guard written != value else {
            return
        }

        written = value
        rebuild()
        onChoose?(value)
    }

    private func rebuild() {
        let actions = options.map { option in
            UIAction(title: option.label, state: option.value == written ? .on : .off) { [weak self] _ in
                self?.pick(option.value)
            }
        }

        menu = UIMenu(children: actions)
        setTitle(options.first(where: { $0.value == written })?.label ?? title(for: .normal), for: .normal)
    }
}

/// A row of stars a reader taps to score something, which UIKit has no control for.
///
/// The engine sizes it, so the stars simply share the width it was given, and a tap on one reports the
/// score it stands for. Drawing them as a label left a rating that could be read and never set.
final class VarnRatingView: UIControl {
    private var stars: [UILabel] = []
    private var font: UIFont = .systemFont(ofSize: 17)
    private var colour: UIColor = .systemOrange

    var value: Int = 0 {
        didSet { show() }
    }

    var count: Int = 5 {
        didSet { rebuild() }
    }

    var onChoose: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()

        let side = stars.isEmpty ? 0 : bounds.width / CGFloat(stars.count)

        for (at, star) in stars.enumerated() {
            star.frame = CGRect(x: side * CGFloat(at), y: 0, width: side, height: bounds.height)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            return
        }

        choose(at: point)
    }

    /// Takes the score the star under a point stands for, which is what tapping one means.
    func choose(at point: CGPoint) {
        guard !stars.isEmpty, bounds.width > 0 else {
            return
        }

        let chosen = min(stars.count, max(1, Int(point.x / (bounds.width / CGFloat(stars.count))) + 1))

        value = chosen
        onChoose?(chosen)
    }

    /// Draws the stars in the font and the colour the style asked for.
    func paint(_ font: UIFont, _ colour: UIColor) {
        self.font = font
        self.colour = colour

        for star in stars {
            star.font = font
            star.textColor = colour
        }
    }

    private func rebuild() {
        stars.forEach { $0.removeFromSuperview() }
        stars = (0..<max(0, count)).map { _ in
            let star = UILabel()
            star.text = "★"
            star.textAlignment = .center
            star.font = font
            star.textColor = colour
            addSubview(star)
            return star
        }

        show()
        setNeedsLayout()
    }

    private func show() {
        for (at, star) in stars.enumerated() {
            star.alpha = at < value ? 1 : 0.3
        }
    }
}

/// The platform's own date and time wheel, which is what a date picker has to be to feel native.
final class VarnDatePicker: UIDatePicker {
    init(mode: UIDatePicker.Mode) {
        super.init(frame: .zero)
        datePickerMode = mode
        preferredDatePickerStyle = .compact
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}

/// A button with no look of its own, since the style a commit carries is what paints it.
///
/// A configured UIButton paints itself from the system tint and ignores what the style asked for, so
/// four variants would arrive as one and no theme would reach any of them. What it keeps is the
/// platform's own answer to being pressed, since a control that does not react to a finger reads as
/// one that is not listening.
final class VarnButton: UIButton {
    init() {
        super.init(frame: .zero)
        configuration = nil
        titleLabel?.adjustsFontSizeToFitWidth = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isHighlighted: Bool {
        didSet { VarnPress.show(isHighlighted, on: self) }
    }
}

/// A box that can be pressed, which is what anything at all becomes when it is given a handler.
///
/// It is a control rather than a plain view so that a finger held on it is answered the way the
/// platform answers one, and so the press is reported on release inside it rather than on any tap.
final class VarnPressableView: UIControl {
    /// How far past its own edge a finger still counts, which a small control needs to be hittable.
    var slop: CGFloat = 0

    override var isHighlighted: Bool {
        didSet { VarnPress.show(isHighlighted, on: self) }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -slop, dy: -slop).contains(point)
    }
}

/// The platform's own answer to being pressed, which is the same one wherever it is given.
enum VarnPress {
    static func show(_ pressed: Bool, on view: UIView) {
        let alpha: CGFloat = pressed ? 0.55 : 1

        if view.alpha == alpha {
            return
        }

        UIView.animate(withDuration: pressed ? 0 : 0.22) {
            view.alpha = alpha
        }
    }
}

final class VarnSwitch: UISwitch {}

/// A slider that answers in the steps it was given rather than in every value between them.
final class VarnSlider: UISlider {
    var step: CGFloat?

    override var value: Float {
        get { super.value }
        set {
            guard let step, step > 0 else {
                super.value = newValue
                return
            }

            super.value = Float((CGFloat(newValue) / step).rounded() * step)
        }
    }
}

/// A field whose text sits inside the padding the style gave it rather than against its own border.
///
/// What may be typed into it is refused as it is typed. A tree that trimmed the text afterwards would
/// put the caret back to the end and lose the keystroke that followed.
final class VarnTextField: UITextField, UITextFieldDelegate {
    var insets: UIEdgeInsets = .zero {
        didSet { setNeedsLayout() }
    }

    var limit: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func textField(
        _ field: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        VarnLimit.allows(field.text, range, string, limit)
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: insets)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: insets)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: insets)
    }
}
final class VarnTextView: UITextView, UITextViewDelegate {
    var limit: Int?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func textView(_ text: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
        VarnLimit.allows(text.text, range, replacementText, limit)
    }
}

/// Answers whether what is being typed still fits in the length the field was given.
enum VarnLimit {
    static func allows(_ text: String?, _ range: NSRange, _ replacement: String, _ limit: Int?) -> Bool {
        guard let limit else {
            return true
        }

        let current = text ?? ""

        guard let span = Range(range, in: current) else {
            return true
        }

        return current.replacingCharacters(in: span, with: replacement).count <= limit
    }
}
final class VarnDividerView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

final class VarnVideoView: UIView {
    let player = AVPlayer()
    private let layerView = AVPlayerLayer()
    private let poster = UIImageView()
    private let controls = AVPlayerViewController()

    var rate: Float = 1
    var loops = false
    var autoplays = false

    var showsControls = true {
        didSet { controls.view.isHidden = !showsControls }
    }

    /// Called when the video reaches its end, unless it was told to start over instead.
    var onEnd: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layerView.player = player
        layer.addSublayer(layerView)

        poster.contentMode = .scaleAspectFill
        poster.clipsToBounds = true
        addSubview(poster)

        controls.player = player
        controls.showsPlaybackControls = true
        addSubview(controls.view)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ended),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Shows the still a video stands behind until it has something of its own to draw.
    func showPoster(at path: String?) {
        poster.image = path.flatMap { UIImage(contentsOfFile: $0) }
        poster.isHidden = poster.image == nil
    }

    /// Takes a new source, starting it straight away when it was told to.
    func play(_ item: AVPlayerItem) {
        player.replaceCurrentItem(with: item)

        if autoplays {
            player.playImmediately(atRate: rate)
            poster.isHidden = true
        }
    }

    @objc private func ended() {
        if loops {
            player.seek(to: .zero)
            player.playImmediately(atRate: rate)
            return
        }

        onEnd?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layerView.frame = bounds
        poster.frame = bounds
        controls.view.frame = bounds
    }
}

/// Draws the commands a canvas node carries, which is the one place Lua describes pixels rather than widgets.
final class VarnCanvasView: UIView {
    var commands: [[String: Any]] = [] {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        for command in commands {
            guard let op = command["op"] as? String else { continue }

            switch op {
            case "fill", "stroke":
                guard let points = command["path"] as? [[CGFloat]], points.count > 1 else { continue }

                let path = UIBezierPath()
                path.move(to: CGPoint(x: points[0][0], y: points[0][1]))
                for point in points.dropFirst() {
                    path.addLine(to: CGPoint(x: point[0], y: point[1]))
                }

                if op == "fill" {
                    path.close()
                    (VarnStyle.color(command["color"]) ?? .black).setFill()
                    path.fill()
                } else {
                    (VarnStyle.color(command["color"]) ?? .black).setStroke()
                    path.lineWidth = VarnValue.number(command["width"]) ?? 1
                    path.stroke()
                }

            case "text":
                let text = command["text"] as? String ?? ""
                let size = VarnValue.number(command["size"]) ?? 15
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: size),
                    .foregroundColor: VarnStyle.color(command["color"]) ?? .black,
                ]

                let origin = CGPoint(x: VarnValue.number(command["x"]) ?? 0, y: VarnValue.number(command["y"]) ?? 0)
                (text as NSString).draw(at: origin, withAttributes: attributes)

            default:
                context.saveGState()
                context.restoreGState()
            }
        }
    }
}
