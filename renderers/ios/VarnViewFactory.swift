import UIKit
import WebKit
import AVKit

/// Builds the UIKit view that stands for one node type.
enum VarnViewFactory {
    static func make(type: String) -> UIView {
        switch type {
        case "text", "richtext": return VarnLabel()
        case "image": return UIImageView()
        case "button": return VarnButton()
        case "pressable": return VarnPressableView()
        case "textinput", "searchbar": return VarnTextField()
        case "textarea": return VarnTextView()
        case "keyboardavoiding": return VarnView()
        case "safearea": return VarnSafeAreaView()
        // One scrolling surface serves every scrolling type, since the engine sends all of them the same thing.
        case "scroll", "list", "sectionlist", "grid", "carousel": return VarnCollectionView()
        case "switch": return VarnSwitch()
        case "slider": return VarnSlider()
        case "stepper": return UIStepper()
        case "segmented": return UISegmentedControl()
        case "progress": return UIProgressView()
        case "activity": return UIActivityIndicatorView(style: .medium)
        case "video": return VarnVideoView()
        case "audio": return VarnAudioView()
        case "webview": return WKWebView()
        case "canvas": return VarnCanvasView()
        case "gradient": return VarnGradientView()
        case "blur": return VarnBlurView()
        case "map": return VarnMapView()
        case "location": return VarnLocationView()
        case "divider": return VarnDividerView()
        case "badge", "tooltip": return VarnLabelView()
        case "rating": return VarnRatingView()
        case "checkbox": return VarnCheckView(shape: .square)
        case "radio": return VarnCheckView(shape: .circle)
        case "picker": return VarnChooserButton()
        case "filepicker": return VarnFilePicker()
        case "datepicker": return VarnDatePicker(mode: .date)
        case "timepicker": return VarnDatePicker(mode: .time)
        case "colorpicker": return UIColorWell()

        // A box is what the rest are: the engine positions them and their style paints them.
        default: return VarnView()
        }
    }

    /// Answers the view children are added to, which for a scrolling view is not the view itself.
    static func contentView(of view: UIView) -> UIView {
        if let collection = view as? VarnCollectionView {
            return collection.contentView
        }

        if let blur = view as? VarnBlurView {
            return blur.contentView
        }

        return view
    }
}

/// A label whose text sits inside the padding the style gave it rather than against its own edge.
///
/// UIKit draws a label's text against its bounds, so a heading told to keep a margin drew flush against
/// the side of the screen. The engine works padding into the frame, so what is left is to inset the
/// text within it.
final class VarnLabel: UILabel {
    var insets: UIEdgeInsets = .zero {
        didSet { setNeedsDisplay() }
    }

    /// What the string is drawn with beyond its font, which is what it is measured with as well.
    var typography: [NSAttributedString.Key: Any] = [:] {
        didSet { redraw() }
    }

    /// The string itself, kept apart from what draws it so that setting either one keeps the other.
    var written: String = "" {
        didSet { redraw() }
    }

    private func redraw() {
        guard !typography.isEmpty else {
            attributedText = nil
            text = written
            return
        }

        attributedText = NSAttributedString(string: written, attributes: typography)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize

        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}

/// The plain box everything else is built from, which draws a background and a border and nothing else.
final class VarnView: UIView {
    /// The range the surface holds this box against its leading edge over, which a header is given.
    ///
    /// A header placed from the tree follows a finger a commit late, which is a header drifting over the
    /// rows it is meant to cover. The range is what the tree knows and the offset is what the surface
    /// knows, so each says the part it has.
    var pinned: (from: CGFloat, to: CGFloat)?

    func pin(_ value: [String: Any]?) {
        guard let value,
              let from = VarnValue.number(value["from"]),
              let to = VarnValue.number(value["to"]) else {
            pinned = nil
            return
        }

        pinned = (CGFloat(from), CGFloat(to))
    }

    /// Answers where it sits for an offset, which is against the edge until its range runs out.
    func held(at offset: CGFloat) -> CGFloat {
        guard let pinned else {
            return offset
        }

        return min(max(offset, pinned.from), max(pinned.from, pinned.to - bounds.height))
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        VarnHit.into(super.hitTest(point, with: event), self, point, event)
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

    /// Answers the control itself for a finger that landed on something inside it that wants nothing.
    ///
    /// A plain view takes a touch on iOS whether or not it has any use for one, so an icon inside a tab
    /// swallowed every press aimed at it: the bar looked right and answered nothing, and a reader who
    /// happened to land beside the icon got through. Anything inside that answers a finger of its own
    /// keeps it, and everything else hands the press to the control it is drawn in.
    /// Answers a child drawn outside the box for a finger that landed on it.
    ///
    /// A view answers a touch only within its own bounds, so a child drawn past the edge of the box it
    /// belongs to is seen and never pressed: the raised picture on a tab bar is drawn half above the bar
    /// and nothing above the bar's own edge reached it. A box that clips its drawing clips its touches
    /// with it, which is the one case where what is outside is not meant to be there at all.
    static func into(_ hit: UIView?, _ view: UIView, _ point: CGPoint, _ event: UIEvent?) -> UIView? {
        if let hit {
            return through(hit, view)
        }

        guard !view.clipsToBounds, !view.isHidden, view.alpha > 0.01, view.isUserInteractionEnabled else {
            return nil
        }

        for child in view.subviews.reversed() {
            if let found = child.hitTest(view.convert(point, to: child), with: event) {
                return found
            }
        }

        return nil
    }

    static func claim(_ hit: UIView?, _ control: UIControl) -> UIView? {
        guard let hit else {
            return nil
        }

        if hit === control {
            return control
        }

        var view: UIView? = hit

        while view != nil, view !== control {
            if view is UIControl || view is UIScrollView || view is WKWebView
                || view?.gestureRecognizers?.isEmpty == false {
                return hit
            }

            view = view?.superview
        }

        return control
    }
}

/// A box that shows one line of text, which is what a badge and a tooltip each are.
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

final class VarnContentView: UIView {}

/// A box that shows a mark and a label, which is what a checkbox and a radio each are.
final class VarnCheckView: UIControl {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        VarnHit.claim(super.hitTest(point, with: event), self)
    }

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
        mark.tintColor = .tintColor
        addSubview(mark)
        addSubview(label)
        addTarget(self, action: #selector(toggle), for: .touchUpInside)
        setChecked(false)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Paints the tick, which is the tree's decision rather than the platform's own accent.
    func paint(_ colour: UIColor) {
        mark.tintColor = colour
    }

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

    /// Answers what was chosen, which is a date, a time, or both, and never an instant.
    ///
    /// A picker chooses what a calendar or a clock shows, not a moment on a timeline. Reporting it as
    /// an instant gives it a zone nobody chose, and reading it back in another one moves the day.
    var chosen: String {
        formatter.string(from: date)
    }

    /// Takes what a calendar or a clock shows, in the same form it reports one in.
    func choose(_ text: String?) {
        guard let text, let chosen = formatter.date(from: text) else {
            return
        }

        date = chosen
    }

    private var formatter: DateFormatter {
        let built = DateFormatter()

        built.locale = Locale(identifier: "en_US_POSIX")
        built.dateFormat = pattern

        return built
    }

    private var pattern: String {
        switch datePickerMode {
        case .time: return "HH:mm"
        case .dateAndTime: return "yyyy-MM-dd'T'HH:mm"
        default: return "yyyy-MM-dd"
        }
    }
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

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        VarnHit.claim(super.hitTest(point, with: event), self)
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

    private var said: [String] = []

    /// Records what this field told the tree, which is what a commit later answers it with.
    func reported(_ text: String) {
        said.append(text)

        if said.count > 64 {
            said.removeFirst()
        }
    }

    /// Answers whether a value is one this field itself produced since it was last written to.
    ///
    /// A tree answers a keystroke with the value it has just been told, and by the time that lands the
    /// reader has typed two more: writing it back puts the field where it was and everything typed
    /// since is gone, so "Are you there" arrives as "Are you r". Anything the field never said — a
    /// draft cleared after sending, a field filled in from somewhere else — is a real change, and the
    /// history starts again from there.
    func echoed(_ text: String?) -> Bool {
        guard let text else {
            return false
        }

        return said.contains(text)
    }

    func written() {
        said.removeAll()
    }

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

    /// Takes the keyboard away when the return key finishes, and leaves it up when it moves on.
    ///
    /// A field whose return key says `next` is one of several, so dismissing on it would put the
    /// keyboard away between every question of a form.
    func textFieldShouldReturn(_ field: UITextField) -> Bool {
        if field.returnKeyType != .next {
            field.resignFirstResponder()
        }

        return true
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
    var onFocus: (() -> Void)?
    var onBlur: (() -> Void)?
    var onChange: ((String) -> Void)?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func textView(_ text: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
        VarnLimit.allows(text.text, range, replacementText, limit)
    }

    func textViewDidChange(_ text: UITextView) {
        onChange?(text.text ?? "")
    }

    func textViewDidBeginEditing(_ text: UITextView) {
        onFocus?()
    }

    func textViewDidEndEditing(_ text: UITextView) {
        onBlur?()
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
    let poster = UIImageView()
    let controller = AVPlayerViewController()

    private var readiness: NSKeyValueObservation?

    var rate: Float = 1
    var loops = false
    var autoplays = false

    var showsControls = true {
        didSet { controller.view.isHidden = !showsControls }
    }

    /// Called when the video reaches its end, unless it was told to start over instead.
    var onEnd: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layerView.player = player
        layerView.videoGravity = .resizeAspect
        layer.addSublayer(layerView)

        controller.player = player
        controller.showsPlaybackControls = true
        controller.view.backgroundColor = .clear
        controller.videoGravity = .resizeAspect

        // The poster stands over the video layer until there is a frame to draw behind it.
        poster.contentMode = .scaleAspectFill
        poster.clipsToBounds = true
        poster.isUserInteractionEnabled = false
        addSubview(poster)

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

    /// Attaches the platform's own controls once there is a view controller to attach them to.
    ///
    /// An `AVPlayerViewController` whose view is added without containment never receives the callbacks
    /// it lays itself out from, so it draws an opaque black rectangle over everything and shows no
    /// controls at all. It belongs to whichever controller owns the surface, which is only knowable
    /// once the view is in a window.
    override func didMoveToWindow() {
        super.didMoveToWindow()

        guard window != nil, controller.parent == nil, let owner = owningController() else {
            return
        }

        owner.addChild(controller)
        controller.view.frame = bounds

        // The order from the bottom is the video, the poster standing over it, and the controls over
        // both, so the play button is reachable while the still is still showing.
        addSubview(controller.view)
        controller.didMove(toParent: owner)
        controller.view.isHidden = !showsControls
    }

    private func owningController() -> UIViewController? {
        var responder: UIResponder? = self

        while let next = responder?.next {
            if let controller = next as? UIViewController {
                return controller
            }

            responder = next
        }

        return nil
    }

    /// Shows the still a video stands behind until it has something of its own to draw.
    func showPoster(at path: String?) {
        poster.image = path.flatMap { UIImage(contentsOfFile: $0) }
        poster.isHidden = poster.image == nil
    }

    /// Takes a new source, starting it straight away when it was told to.
    ///
    /// The poster stands over the player until there is a frame behind it, which is what the first
    /// moment of a video that has not been asked to play yet looks like.
    func play(_ item: AVPlayerItem) {
        VarnAudioSession.playback()
        player.replaceCurrentItem(with: item)

        if autoplays {
            player.playImmediately(atRate: rate)
            poster.isHidden = true
            return
        }

        watchForFirstFrame(item)
    }

    private func watchForFirstFrame(_ item: AVPlayerItem) {
        readiness?.invalidate()

        readiness = item.observe(\.status) { [weak self] observed, _ in
            guard observed.status == .readyToPlay else {
                return
            }

            DispatchQueue.main.async {
                self?.poster.isHidden = true
            }
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
        controller.view.frame = bounds
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
                guard let points = command["path"] as? [[CGFloat]] else { continue }

                let pairs = points.filter { $0.count >= 2 }
                guard pairs.count > 1 else { continue }

                let path = UIBezierPath()
                path.move(to: CGPoint(x: pairs[0][0], y: pairs[0][1]))
                for point in pairs.dropFirst() {
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
