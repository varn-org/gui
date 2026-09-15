import UIKit
import WebKit
import AVKit

/// Builds the UIKit view that stands for one node type.
enum VarnViewFactory {
    static func make(type: String) -> UIView {
        switch type {
        case "text", "richtext": return VarnLabel()
        case "image": return VarnPictureView()
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
        case "stepper": return VarnStepper()
        case "segmented": return UISegmentedControl()
        case "progress": return UIProgressView()
        case "activity": return VarnActivityView()
        case "video": return VarnVideoView()
        case "camera": return VarnCameraView()
        case "recorder": return VarnRecorderView()
        case "audio": return VarnAudioView()
        case "webview": return VarnWebView()
        case "canvas": return VarnCanvasView()
        case "gradient": return VarnGradientView()
        case "nineslice": return VarnNineSliceView()
        case "richeditor": return VarnRichEditor()
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

/// A picture, drawn from what it was loaded with rather than from what was last written over it.
///
/// A tint and a filter each rewrite the picture they are given, and the props of one batch arrive in no
/// order at all, so applying one and then the other lost whichever came first: a tinted icon that was
/// also filtered came out as one or the other depending on the order of a table. What was loaded, what
/// tints it and what filters it are kept apart, and the picture is drawn from all three. A tint replaces
/// the colours of a picture outright, so a picture that carries one leaves a filter nothing to change.
final class VarnPictureView: UIImageView {
    var source: UIImage? {
        didSet { redraw() }
    }

    var tint: UIColor? {
        didSet { redraw() }
    }

    var filter: [Double]? {
        didSet { redraw() }
    }

    private func redraw() {
        guard let tint else {
            image = VarnFilter.apply(filter, to: source)?.withRenderingMode(.alwaysOriginal)
            return
        }

        tintColor = tint
        image = source?.withRenderingMode(.alwaysTemplate)
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

/// A web view that honours whether the tree allows the page it shows to run scripts.
///
/// A `WKWebView` answers a copy of the configuration it was built with, so writing a preference on it
/// afterwards changes nothing at all: a tree that said no to scripts was shown a page that ran them.
/// The decision belongs to the navigation, which is where a browser puts it too, and it is read when
/// the load actually begins rather than in whatever order the props of one batch arrive.
final class VarnWebView: WKWebView, WKNavigationDelegate {
    var scripting = true

    /// Told at each end of a load, and told rather than left silent when one cannot be made at all.
    var onWillLoad: (([String: Any]) -> Void)?
    var onLoad: (([String: Any]) -> Void)?
    var onError: (([String: Any]) -> Void)?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        navigationDelegate = self
    }

    convenience init() {
        self.init(frame: .zero, configuration: WKWebViewConfiguration())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("a web view is built by the factory rather than from a nib")
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        preferences.allowsContentJavaScript = scripting
        decisionHandler(.allow, preferences)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onWillLoad?(["url": webView.url?.absoluteString ?? ""])
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoad?(["url": webView.url?.absoluteString ?? ""])
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onError?(["message": error.localizedDescription])
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        onError?(["message": error.localizedDescription])
    }
}

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
    /// The room the title keeps inside the button, which the engine has already worked into the frame.
    ///
    /// The padding is part of the frame the engine sends, and the platform centres the title in that, so
    /// an even padding needs nothing done to it. What is left is a padding that is not even, which moves
    /// the title by the difference. `contentEdgeInsets` did it and is deprecated, and so are the two
    /// rects that replaced it — the compiler said so on every build, which is a defect found for free.
    var insets: UIEdgeInsets = .zero {
        didSet { setNeedsLayout() }
    }

    init() {
        super.init(frame: .zero)
        configuration = nil
        titleLabel?.adjustsFontSizeToFitWidth = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()

        let across = (insets.left - insets.right) / 2
        let down = (insets.top - insets.bottom) / 2

        guard across != 0 || down != 0 else {
            return
        }

        titleLabel?.frame = (titleLabel?.frame ?? .zero).offsetBy(dx: across, dy: down)
        imageView?.frame = (imageView?.frame ?? .zero).offsetBy(dx: across, dy: down)
    }

    override var isHighlighted: Bool {
        didSet { VarnPress.show(isHighlighted, on: self) }
    }
}

/// A box that can be pressed, which is what anything at all becomes when it is given a handler.
///
/// It is a control rather than a plain view so that a finger held on it is answered the way the
/// platform answers one, and so the press is reported on release inside it rather than on any tap.
final class VarnPressableView: UIControl, VarnKeyed, VarnFocusing {
    /// How far past its own edge a finger still counts, which a small control needs to be hittable.
    var slop: CGFloat = 0

    var onKey: ((String, [String: Any]) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var wanted = false

    /// Which axis this box claims a drag along, which the recogniser reads when it is attached.
    var panAxis: String?

    /// A box that is listening for a key takes the keyboard, which is what a key is delivered through.
    override var canBecomeFirstResponder: Bool {
        onKey != nil || wanted
    }

    override var canBecomeFocused: Bool {
        wanted
    }

    override func becomeFirstResponder() -> Bool {
        let took = super.becomeFirstResponder()

        if took {
            onFocusChange?(true)
        }

        return took
    }

    override func resignFirstResponder() -> Bool {
        let gave = super.resignFirstResponder()

        if gave {
            onFocusChange?(false)
        }

        return gave
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        if context.nextFocusedView === self {
            onFocusChange?(true)
        }

        if context.previouslyFocusedView === self {
            onFocusChange?(false)
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !VarnKeys.report(presses, as: "onKeyDown", to: self) {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !VarnKeys.report(presses, as: "onKeyUp", to: self) {
            super.pressesEnded(presses, with: event)
        }
    }

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

/// A stepper that takes how far it may go, which the platform's own control will not be told piecemeal.
///
/// `UIStepper` raises rather than answers when a bound crosses the other or a step is not positive, and
/// the props of one batch arrive in no order at all, so a minimum written before its maximum would take
/// the process down. What it is worth and how far it goes are read together once the batch has landed,
/// and a stepper nobody bounded goes as far in either direction as a number goes, which is what the
/// other two platforms do with one.
final class VarnStepper: UIStepper, VarnSettling {
    var least: Double = -.greatestFiniteMagnitude
    var most: Double = .greatestFiniteMagnitude
    var by: Double = 1
    var current: Double = 0

    func settle() {
        let low = min(least, most)
        let high = max(least, most)

        maximumValue = .greatestFiniteMagnitude
        minimumValue = low
        maximumValue = high

        stepValue = by
        value = min(high, max(low, current))
    }
}

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
final class VarnTextField: UITextField, UITextFieldDelegate, VarnKeyed {
    var insets: UIEdgeInsets = .zero {
        didSet { setNeedsLayout() }
    }

    var limit: Int?

    var onKey: ((String, [String: Any]) -> Void)?

    /// Says where the caret is, which a browser and the two phones each report at a different moment.
    var onSelection: (([String: Any]) -> Void)?

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !VarnKeys.report(presses, as: "onKeyDown", to: self) {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !VarnKeys.report(presses, as: "onKeyUp", to: self) {
            super.pressesEnded(presses, with: event)
        }
    }

    /// Says where the caret went, which the platform reports through the delegate and nowhere else.
    ///
    /// A field's `selectedTextRange` is set by UIKit without going through anything a subclass can
    /// observe, so watching the property is a handler that never fires. This is the one moment the
    /// platform publishes for it.
    func textFieldDidChangeSelection(_ field: UITextField) {
        guard let onSelection, let range = selectedTextRange else {
            return
        }

        onSelection([
            "start": offset(from: beginningOfDocument, to: range.start),
            "end": offset(from: beginningOfDocument, to: range.end),
            "marks": [String: Any](),
        ])
    }

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
final class VarnTextView: UITextView, UITextViewDelegate, VarnKeyed {
    var limit: Int?
    var onFocus: (() -> Void)?
    var onBlur: (() -> Void)?
    var onChange: ((String) -> Void)?
    var onKey: ((String, [String: Any]) -> Void)?

    /// Says where the caret is, which a browser and the two phones each report at a different moment.
    var onSelection: (([String: Any]) -> Void)?

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !VarnKeys.report(presses, as: "onKeyDown", to: self) {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !VarnKeys.report(presses, as: "onKeyUp", to: self) {
            super.pressesEnded(presses, with: event)
        }
    }

    func textViewDidChangeSelection(_ text: UITextView) {
        onSelection?([
            "start": text.selectedRange.location,
            "end": text.selectedRange.location + text.selectedRange.length,
            "marks": [String: Any](),
        ])
    }

    /// The words shown in an empty field, which `UITextView` has none of and every other field does.
    ///
    /// A one-line field is a `UITextField` and carries its own. A field over several lines is a text
    /// view, which the platform gives no placeholder at all, so a field on a phone showed nothing where
    /// the same tree on a page showed the words. It is drawn here, in the muted colour a placeholder is
    /// drawn in, and goes as soon as there is anything to read.
    private let hint = UILabel()

    var placeholder: String? {
        didSet {
            hint.text = placeholder
            showHint()
        }
    }

    override var text: String! {
        didSet { showHint() }
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delegate = self

        hint.numberOfLines = 0
        hint.textColor = .placeholderText
        hint.isUserInteractionEnabled = false
        addSubview(hint)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()

        let inset = textContainerInset
        let left = inset.left + textContainer.lineFragmentPadding
        let width = bounds.width - left - inset.right - textContainer.lineFragmentPadding

        hint.font = font
        hint.frame = CGRect(x: left, y: inset.top, width: max(0, width), height: 0)
        hint.sizeToFit()
        hint.frame.origin = CGPoint(x: left, y: inset.top)
    }

    private func showHint() {
        hint.isHidden = !(text ?? "").isEmpty
    }

    func textView(_ text: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
        VarnLimit.allows(text.text, range, replacementText, limit)
    }

    func textViewDidChange(_ text: UITextView) {
        showHint()
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

    /// The colour matrix every frame is drawn through, which is what a look over a film is.
    ///
    /// A player draws its own frames, so nothing over the view can colour them: the look is applied where
    /// the frames are composed instead, which is also the only place iOS lets one reach a video at all.
    var filter: [Double]? {
        didSet { compose() }
    }

    var showsControls = true {
        didSet { controller.view.isHidden = !showsControls }
    }

    /// Called when the video reaches its end, unless it was told to start over instead.
    var onEnd: (() -> Void)?

    /// Called when what it was given cannot be played at all, which is otherwise a black box.
    var onError: (([String: Any]) -> Void)?

    /// Called once the film can be played, carrying how long the whole of it runs for.
    var onReady: (([String: Any]) -> Void)?

    /// Called as it plays, carrying where it has got to, which is what a scrubber of the tree's follows.
    var onProgress: (([String: Any]) -> Void)?

    private var watching: Any?

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

        // The notice names the item that finished, and every item in the process raises the same one, so
        // a screen holding a video and a sound tells both of them that one of them ended.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ended(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        watching = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.report(at: time.seconds)
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    deinit {
        NotificationCenter.default.removeObserver(self)

        if let watching {
            player.removeTimeObserver(watching)
        }
    }

    private func report(at position: Double) {
        let whole = player.currentItem?.duration.seconds ?? 0
        let duration = whole.isFinite ? whole : 0

        onProgress?(["position": position, "duration": duration])
    }

    /// Moves to a moment, which is a reader dragging a scrubber rather than anything the tree describes.
    func seek(to seconds: Double) {
        let whole = player.currentItem?.duration.seconds ?? 0
        let bound = whole.isFinite ? whole : seconds
        let wanted = CMTime(seconds: max(0, min(seconds, bound)), preferredTimescale: 600)

        // The completion is not promised on any particular queue, and what it does reaches the tree.
        player.seek(to: wanted, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.report(at: self.player.currentTime().seconds)
            }
        }
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

    /// Draws every frame the player produces through the look the tree asked for.
    private func compose() {
        guard let item = player.currentItem else {
            return
        }

        guard let matrix = filter else {
            item.videoComposition = nil
            return
        }

        item.videoComposition = AVVideoComposition(asset: item.asset) { request in
            guard let drawn = VarnFilter.filtered(matrix, request.sourceImage) else {
                request.finish(with: request.sourceImage, context: nil)
                return
            }

            request.finish(with: drawn, context: nil)
        }
    }

    /// Takes a new source, starting it straight away when it was told to.
    ///
    /// The poster stands over the player until there is a frame behind it, which is what the first
    /// moment of a video that has not been asked to play yet looks like.
    func play(_ item: AVPlayerItem) {
        VarnAudioSession.playback()
        player.replaceCurrentItem(with: item)
        compose()

        watchForFirstFrame(item)

        if autoplays {
            player.playImmediately(atRate: rate)
            poster.isHidden = true
        }
    }

    private func watchForFirstFrame(_ item: AVPlayerItem) {
        readiness?.invalidate()

        readiness = item.observe(\.status) { [weak self] observed, _ in
            if observed.status == .failed {
                let problem = observed.error?.localizedDescription ?? "the film could not be opened"
                DispatchQueue.main.async { self?.onError?(["message": problem]) }
                return
            }

            guard observed.status == .readyToPlay else {
                return
            }

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.poster.isHidden = true

                let whole = observed.duration.seconds

                self.onReady?(["duration": whole.isFinite ? whole : 0])
            }
        }
    }

    @objc private func ended(_ note: Notification) {
        guard note.object as AnyObject? === player.currentItem else {
            return
        }

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
