import AVFoundation
import UIKit
import WebKit

/// Applies one prop to the view that stands for a node, and wires the events it declares.
enum VarnProps {
    typealias EventSink = (Int, String, Any) -> Void

    static func apply(key: String, value: Any?, to view: UIView, type: String, id: Int, emit: @escaping EventSink) {
        // Layout is computed by the engine, so a node that asked to hear about its frame hears from there.
        if key == "onLayout" {
            return
        }

        if key.hasPrefix("on") {
            bind(event: key, to: view, id: id, emit: emit)
            return
        }

        switch key {
        case "contentExtent":
            applyContentExtent(value, to: view)

        case "horizontal":
            (view as? VarnCollectionView)?.setHorizontal((value as? Bool) ?? false)

        case "showsIndicator":
            (view as? VarnCollectionView)?.setShowsIndicator((value as? Bool) ?? true)

        case "scrollEnabled":
            (view as? UIScrollView)?.isScrollEnabled = (value as? Bool) ?? true

        case "bounces":
            (view as? UIScrollView)?.bounces = (value as? Bool) ?? true

        case "paging":
            (view as? UIScrollView)?.isPagingEnabled = (value as? Bool) ?? false

        case "text":
            (view as? UILabel)?.text = value as? String
            (view as? VarnLabel)?.written = (value as? String) ?? ""
            (view as? VarnLabelView)?.label.text = value as? String

        case "label":
            (view as? VarnLabelView)?.label.text = value as? String
            (view as? VarnCheckView)?.label.text = value as? String

        case "title":
            (view as? UIButton)?.setTitle(value as? String, for: .normal)

        case "value":
            if let holder = view as? VarnLabelView {
                holder.label.text = value.map { "\($0)" }
            }

            applyValue(value, to: view, type: type)

        case "selected":
            (view as? VarnCheckView)?.setChecked((value as? Bool) ?? false)

        case "spans":
            applySpans(value as? [[String: Any]] ?? [], to: view)

        case "options":
            applyOptions(value as? [[String: Any]] ?? [], to: view)

        case "count":
            applyStars(value as? Int ?? 5, to: view)

        case "placeholder":
            (view as? UITextField)?.placeholder = value as? String

            if let image = view as? UIImageView, image.image == nil, let path = value as? String {
                image.image = UIImage(contentsOfFile: path)
            }

        case "pointerEvents":
            view.isUserInteractionEnabled = (value as? String) != "none"

        case "hitSlop":
            (view as? VarnPressableView)?.slop = VarnValue.number(value) ?? 0

        case "onColor":
            (view as? UISwitch)?.onTintColor = VarnStyle.color(value)

        case "thumbColor":
            (view as? UISwitch)?.thumbTintColor = VarnStyle.color(value)
            (view as? UISlider)?.thumbTintColor = VarnStyle.color(value)

        case "offColor":
            (view as? UISwitch)?.tintColor = VarnStyle.color(value)

        case "trackColor":
            (view as? UISlider)?.minimumTrackTintColor = VarnStyle.color(value)
            (view as? UIProgressView)?.trackTintColor = VarnStyle.color(value)

        case "step":
            (view as? UIStepper)?.stepValue = VarnValue.number(value) ?? 1
            (view as? VarnSlider)?.step = VarnValue.number(value)

        case "continuous":
            (view as? UISlider)?.isContinuous = (value as? Bool) ?? true

        case "refreshing":
            VarnRefresh.show((value as? Bool) ?? false, on: view)

        case "display":
            (view as? VarnDatePicker)?.preferredDatePickerStyle =
                (value as? String) == "wheel" ? .wheels : .compact

        case "keyboardDismissMode":
            (view as? UIScrollView)?.keyboardDismissMode =
                (value as? String) == "on-drag" ? .onDrag : .none

        case "tint":
            (view as? VarnBlurView)?.setTint(value as? String)
            applyTint(value, to: view)

        case "color":
            applyControlColour(value, to: view)

        case "barContent":
            (view as? VarnSafeAreaView)?.setBarContent(value as? String)

        case "kind":
            (view as? VarnFilePicker)?.setKind(value as? String)

        case "accept":
            (view as? VarnFilePicker)?.setAccept(value as? [String] ?? [])

        case "multiple":
            (view as? VarnFilePicker)?.setMultiple((value as? Bool) ?? false)

        case "maxBytes":
            (view as? VarnFilePicker)?.setMaxBytes(Int(VarnValue.number(value) ?? 0))

        case "colors":
            (view as? VarnGradientView)?.setColors(value as? [Any] ?? [])

        case "locations":
            (view as? VarnGradientView)?.setLocations(value as? [Any])

        case "direction":
            (view as? VarnGradientView)?.setDirection(value as? String)

        case "intensity":
            (view as? VarnBlurView)?.setIntensity(CGFloat(VarnValue.number(value) ?? 0.85))

        case "pinned":
            (view as? VarnView)?.pin(value as? [String: Any])
            view.superview?.bringSubviewToFront(view)
            (view.superview?.superview as? VarnCollectionView)?.hold()

        case "colors":
            (view as? VarnGradientView)?.setColors(value as? [Any] ?? [])

        case "locations":
            (view as? VarnGradientView)?.setLocations(value as? [Any])

        case "direction":
            (view as? VarnGradientView)?.setDirection(value as? String)

        case "intensity":
            (view as? VarnBlurView)?.setIntensity(CGFloat(VarnValue.number(value) ?? 0.85))

        case "pinned":
            (view as? VarnView)?.pin(value as? [String: Any])
            view.superview?.bringSubviewToFront(view)
            (view.superview?.superview as? VarnCollectionView)?.hold()

        case "center":
            (view as? VarnMapView)?.setCenter(value as? [String: Any])

        case "zoom":
            (view as? VarnMapView)?.setZoom(VarnValue.number(value) ?? 14)

        case "markers":
            (view as? VarnMapView)?.setMarkers(value as? [[String: Any]] ?? [])

        case "interactive":
            (view as? VarnMapView)?.setInteractive((value as? Bool) ?? true)

        case "watch":
            (view as? VarnLocationView)?.setWatch((value as? Bool) ?? false)

        case "accuracy":
            (view as? VarnLocationView)?.setAccuracy(value as? String)

        case "playing":
            (view as? VarnAudioView)?.setPlaying((value as? Bool) ?? false)

        case "position":
            (view as? VarnAudioView)?.setPosition(VarnValue.number(value) ?? 0)

        case "muted":
            (view as? VarnVideoView)?.player.isMuted = (value as? Bool) ?? false

        case "volume":
            (view as? VarnVideoView)?.player.volume = Float(VarnValue.number(value) ?? 1)
            (view as? VarnAudioView)?.setVolume(Float(VarnValue.number(value) ?? 1))

        case "rate":
            (view as? VarnVideoView)?.rate = Float(VarnValue.number(value) ?? 1)
            (view as? VarnAudioView)?.setRate(Float(VarnValue.number(value) ?? 1))

        case "loop":
            (view as? VarnVideoView)?.loops = (value as? Bool) ?? false
            (view as? VarnAudioView)?.setLoops((value as? Bool) ?? false)

        case "autoplay":
            (view as? VarnVideoView)?.autoplays = (value as? Bool) ?? false

        case "controls":
            (view as? VarnVideoView)?.showsControls = (value as? Bool) ?? true

        case "javaScriptEnabled":
            (view as? WKWebView)?.configuration.preferences.javaScriptEnabled = (value as? Bool) ?? true

        case "poster":
            (view as? VarnVideoView)?.showPoster(at: value as? String)

        case "resizeMode":
            applyResizeMode(value as? String, to: view)

        case "source":
            applySource(value, to: view, type: type)

        case "disabled":
            (view as? UIControl)?.isEnabled = !((value as? Bool) ?? false)

        case "editable":
            (view as? UITextField)?.isEnabled = (value as? Bool) ?? true
            (view as? UITextView)?.isEditable = (value as? Bool) ?? true

        case "maxLength":
            (view as? VarnTextField)?.limit = value as? Int
            (view as? VarnTextView)?.limit = value as? Int

        case "autoCapitalize":
            (view as? UITextField)?.autocapitalizationType = capitalisation(value as? String)
            (view as? UITextView)?.autocapitalizationType = capitalisation(value as? String)

        case "autoCorrect":
            let correcting: UITextAutocorrectionType = (value as? Bool) == false ? .no : .yes
            (view as? UITextField)?.autocorrectionType = correcting
            (view as? UITextView)?.autocorrectionType = correcting

        case "placeholderColor":
            applyPlaceholderColour(value, to: view)

        case "secure":
            (view as? UITextField)?.isSecureTextEntry = (value as? Bool) ?? false

        case "keyboard":
            (view as? UITextField)?.keyboardType = keyboard(value as? String)

        case "returnKey":
            (view as? UITextField)?.returnKeyType = returnKey(value as? String)

        case "numberOfLines":
            (view as? UILabel)?.numberOfLines = (value as? Int) ?? 0

        case "animating":
            applyAnimating(value as? Bool ?? true, to: view)

        case "size":
            (view as? UIActivityIndicatorView)?.style = (value as? String) == "small" ? .medium : .large

        case "thickness":
            applyThickness(VarnValue.number(value) ?? 4, to: view)

        case "indeterminate":
            applyIndeterminate((value as? Bool) ?? false, to: view)

        case "minimum":
            (view as? UISlider)?.minimumValue = Float((value as? Double) ?? 0)

        case "maximum":
            (view as? UISlider)?.maximumValue = Float((value as? Double) ?? 1)

        case "selectedIndex":
            (view as? UISegmentedControl)?.selectedSegmentIndex = ((value as? Int) ?? 1) - 1

        case "segments":
            applySegments(value as? [String] ?? [], to: view)

        case "visible", "open":
            view.isHidden = !((value as? Bool) ?? false)

        case "url":
            if let text = value as? String, let url = URL(string: text) {
                (view as? WKWebView)?.load(URLRequest(url: url))
            }

        case "html":
            (view as? WKWebView)?.loadHTMLString(value as? String ?? "", baseURL: nil)

        case "commands":
            (view as? VarnCanvasView)?.commands = value as? [[String: Any]] ?? []

        case "accessibilityLabel":
            // A node that was named is one thing to a reader who cannot see it, rather than the tree of
            // boxes it is built from, so naming it is also what makes it one element rather than several.
            view.accessibilityLabel = value as? String
            view.isAccessibilityElement = value != nil

        case "testID":
            view.accessibilityIdentifier = value as? String

        default:
            break
        }
    }

    /// Sizes what a scrolling view scrolls over, which the engine has already measured for it.
    private static func applyContentExtent(_ value: Any?, to view: UIView) {
        let extent = VarnValue.number(value) ?? 0

        (view as? VarnCollectionView)?.setContentExtent(extent)
    }

    /// Shows what a picker holds, which is the label of the option the value names.
    private static func applyOptions(_ options: [[String: Any]], to view: UIView) {
        guard let button = view as? VarnChooserButton else {
            return
        }

        button.options = options.map { option in
            let label = option["label"] as? String ?? ""
            return (label: label, value: option["value"] as? String ?? label)
        }
    }

    /// Draws a rating as the stars it is worth, since UIKit has no control that is one.
    private static func applyStars(_ count: Int, to view: UIView) {
        (view as? VarnRatingView)?.count = count
    }

    private static func applyValue(_ value: Any?, to view: UIView, type: String) {
        if let check = view as? VarnCheckView {
            // A radio's value is the identity it reports when chosen, never whether it is chosen, which
            // is what `selected` says. Reading it as a state leaves every radio in a group unchecked.
            if type == "checkbox" {
                check.setChecked((value as? Bool) ?? false)
            }
            return
        }

        if let picker = view as? VarnDatePicker {
            picker.choose(value as? String)
            return
        }

        if let chooser = view as? VarnChooserButton {
            chooser.choose(value as? String)
            return
        }

        if let rating = view as? VarnRatingView {
            rating.value = Int(VarnValue.number(value) ?? 0)
            return
        }

        if let stepper = view as? UIStepper {
            stepper.value = VarnValue.number(value).map(Double.init) ?? 0
            return
        }

        if let well = view as? UIColorWell {
            well.selectedColor = VarnStyle.color(value)
            return
        }

        if let toggle = view as? UISwitch {
            toggle.isOn = (value as? Bool) ?? false
            return
        }

        if let slider = view as? UISlider {
            slider.value = Float((value as? Double) ?? 0)
            return
        }

        if let field = view as? VarnTextField {
            let text = value as? String

            if field.echoed(text) {
                return
            }

            if field.text != text {
                field.text = text
            }

            field.written()
            return
        }

        if let field = view as? UITextField {
            let text = value as? String

            if field.text != text {
                field.text = text
            }

            return
        }

        if let text = view as? UITextView {
            let content = value as? String ?? ""
            if text.text != content {
                text.text = content
            }
            return
        }

        if let progress = view as? UIProgressView {
            progress.progress = Float((value as? Double) ?? 0)
        }
    }

    /// Says how a picture fills the frame the engine gave it, which is never the frame's own shape.
    private static func applyResizeMode(_ mode: String?, to view: UIView) {
        guard let image = view as? UIImageView else {
            return
        }

        switch mode {
        case "contain": image.contentMode = .scaleAspectFit
        case "stretch": image.contentMode = .scaleToFill
        case "center": image.contentMode = .center
        default: image.contentMode = .scaleAspectFill
        }
    }

    /// Paints the mark a control draws, which is what a colour on a control rather than on text means.
    ///
    /// A style's colour is the colour of a string. A control that draws a tick, a spinner or a bar
    /// draws it in the colour the tree gave the control, and each of those was the platform's own.
    private static func applyControlColour(_ value: Any?, to view: UIView) {
        guard let colour = VarnStyle.color(value) else {
            return
        }

        (view as? VarnCheckView)?.paint(colour)
        (view as? UIActivityIndicatorView)?.color = colour
        (view as? UIProgressView)?.progressTintColor = colour
    }

    private static func applySource(_ value: Any?, to view: UIView, type: String) {
        guard let path = value as? String else {
            return
        }

        if let image = view as? UIImageView {
            image.image = UIImage(contentsOfFile: path)
            return
        }

        if let video = view as? VarnVideoView {
            video.play(AVPlayerItem(url: url(of: path)))
        }
    }

    /// Answers a source as the url a player takes, whether it names a file or somewhere else entirely.
    ///
    /// Reading every source with `URL(string:)` leaves a bundled file with no scheme and nothing that
    /// can be played, which is a video that never starts and says nothing about why.
    private static func url(of path: String) -> URL {
        if path.contains("://") {
            return URL(string: path) ?? URL(fileURLWithPath: path)
        }

        return URL(fileURLWithPath: path)
    }

    /// Draws a bar at the thickness it was given, which UIKit has no property for.
    ///
    /// A progress view is a hairline whatever frame it is put in, so the height the tree asked for is
    /// applied as a scale about its own middle.
    private static func applyThickness(_ thickness: CGFloat, to view: UIView) {
        guard let bar = view as? UIProgressView, bar.bounds.height > 0 else {
            return
        }

        bar.transform = CGAffineTransform(scaleX: 1, y: thickness / bar.bounds.height)
    }

    /// A bar with no value of its own moves on its own, which is what waiting for an unknown looks like.
    private static func applyIndeterminate(_ indeterminate: Bool, to view: UIView) {
        guard let bar = view as? UIProgressView else {
            return
        }

        bar.layer.removeAnimation(forKey: "varn.indeterminate")

        guard indeterminate else {
            return
        }

        let sweep = CABasicAnimation(keyPath: "progress")
        sweep.fromValue = 0
        sweep.toValue = 1
        sweep.duration = 1.2
        sweep.repeatCount = .infinity

        bar.progress = 1
        bar.layer.add(sweep, forKey: "varn.indeterminate")
    }

    private static func applyAnimating(_ animating: Bool, to view: UIView) {
        guard let indicator = view as? UIActivityIndicatorView else {
            return
        }

        if animating {
            indicator.startAnimating()
        } else {
            indicator.stopAnimating()
        }
    }

    /// Draws a paragraph made of runs that each carry a style of their own.
    ///
    /// A span flows inline within the paragraph, which only an attributed string can do, so this is one
    /// of the few places a renderer builds something rather than being handed it as nodes.
    private static func applySpans(_ spans: [[String: Any]], to view: UIView) {
        guard let label = view as? UILabel else {
            return
        }

        let paragraph = NSMutableAttributedString()

        for span in spans {
            let style = span["style"] as? [String: Any] ?? [:]
            var attributes: [NSAttributedString.Key: Any] = [.font: VarnStyle.font(from: style)]

            if let colour = VarnStyle.color(style["color"]) {
                attributes[.foregroundColor] = colour
            }

            if (style["textDecoration"] as? String) == "underline" {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }

            if (style["textDecoration"] as? String) == "line-through" {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            paragraph.append(NSAttributedString(string: span["text"] as? String ?? "", attributes: attributes))
        }

        label.attributedText = paragraph
    }

    private static func applySegments(_ segments: [String], to view: UIView) {
        guard let control = view as? UISegmentedControl else {
            return
        }

        // The props of one node arrive in no particular order, so the chosen segment is carried across
        // the rebuild of the titles rather than lost whenever it happens to be applied first.
        let chosen = control.selectedSegmentIndex
        control.removeAllSegments()

        for (index, title) in segments.enumerated() {
            control.insertSegment(withTitle: title, at: index, animated: false)
        }

        if chosen >= 0 && chosen < segments.count {
            control.selectedSegmentIndex = chosen
        }
    }

    /// Draws a picture in one colour, which is what an icon carried as an image is.
    private static func applyTint(_ value: Any?, to view: UIView) {
        guard let image = view as? UIImageView else {
            return
        }

        guard let colour = VarnStyle.color(value) else {
            image.image = image.image?.withRenderingMode(.alwaysOriginal)
            return
        }

        image.image = image.image?.withRenderingMode(.alwaysTemplate)
        image.tintColor = colour
    }

    private static func capitalisation(_ name: String?) -> UITextAutocapitalizationType {
        switch name {
        case "none": return .none
        case "words": return .words
        case "characters": return .allCharacters
        default: return .sentences
        }
    }

    /// Draws the words a field shows while it is empty in the colour it was asked for.
    private static func applyPlaceholderColour(_ value: Any?, to view: UIView) {
        guard let field = view as? UITextField, let colour = VarnStyle.color(value) else {
            return
        }

        field.attributedPlaceholder = NSAttributedString(
            string: field.placeholder ?? "",
            attributes: [.foregroundColor: colour]
        )
    }

    private static func keyboard(_ name: String?) -> UIKeyboardType {
        switch name {
        case "number": return .numberPad
        case "decimal": return .decimalPad
        case "email": return .emailAddress
        case "phone": return .phonePad
        case "url": return .URL
        case "search": return .webSearch
        default: return .default
        }
    }

    private static func returnKey(_ name: String?) -> UIReturnKeyType {
        switch name {
        case "go": return .go
        case "next": return .next
        case "search": return .search
        case "send": return .send
        default: return .done
        }
    }

    private static func bind(event: String, to view: UIView, id: Int, emit: @escaping EventSink) {
        let reporter = VarnEventReporter(id: id, event: event, emit: emit)
        VarnEventReporter.retain(reporter, on: view)?.detach(from: view)

        switch event {
        case "onPress":
            if let map = view as? VarnMapView {
                map.onPress = { at in reporter.report(at) }
            } else if let control = view as? UIControl {
                control.addTarget(reporter, action: #selector(VarnEventReporter.fired), for: .touchUpInside)
            } else {
                view.isUserInteractionEnabled = true
                reporter.attach(UITapGestureRecognizer(target: reporter,
                                                       action: #selector(VarnEventReporter.fired)), to: view)
            }

        case "onPressIn":
            (view as? UIControl)?.addTarget(reporter, action: #selector(VarnEventReporter.fired), for: .touchDown)

        case "onPressOut":
            (view as? UIControl)?.addTarget(reporter, action: #selector(VarnEventReporter.fired),
                                            for: [.touchUpInside, .touchUpOutside])

        case "onSwipe":
            view.isUserInteractionEnabled = true

            for direction in [UISwipeGestureRecognizer.Direction.left, .right, .up, .down] {
                let swipe = UISwipeGestureRecognizer(target: reporter,
                                                     action: #selector(VarnEventReporter.swiped))
                swipe.direction = direction
                reporter.attach(swipe, to: view)
            }

        case "onLongPress":
            view.isUserInteractionEnabled = true
            reporter.attach(UILongPressGestureRecognizer(target: reporter,
                                                         action: #selector(VarnEventReporter.held)), to: view)

        case "onChange", "onSelect":
            (view as? UIControl)?.addTarget(reporter, action: #selector(VarnEventReporter.changed), for: .valueChanged)
            (view as? UITextField)?.addTarget(reporter, action: #selector(VarnEventReporter.changed), for: .editingChanged)
            (view as? VarnTextView)?.onChange = { typed in reporter.report(typed) }
            (view as? VarnChooserButton)?.onChoose = { chosen in reporter.report(chosen) }
            (view as? VarnRatingView)?.onChoose = { score in reporter.report(score) }
            (view as? VarnLocationView)?.onChange = { fix in reporter.report(fix) }

        case "onPick":
            (view as? VarnFilePicker)?.onPick = { files in reporter.report(files) }

        case "onSubmit":
            (view as? UITextField)?.addTarget(reporter, action: #selector(VarnEventReporter.fired), for: .editingDidEndOnExit)

        case "onFocus":
            (view as? UITextField)?.addTarget(reporter, action: #selector(VarnEventReporter.fired), for: .editingDidBegin)
            (view as? VarnTextView)?.onFocus = { reporter.fired() }

        case "onBlur":
            (view as? UITextField)?.addTarget(reporter, action: #selector(VarnEventReporter.fired), for: .editingDidEnd)
            (view as? VarnTextView)?.onBlur = { reporter.fired() }

        case "onRefresh":
            VarnRefresh.onPull(view) { reporter.fired() }

        case "onScroll":
            (view as? VarnCollectionView)?.onScroll = { payload in reporter.report(payload) }

        case "onScrollEnd":
            (view as? VarnCollectionView)?.onScrollEnd = { payload in reporter.report(payload) }

        case "onError":
            (view as? VarnLocationView)?.onError = { problem in reporter.report(problem) }

        case "onRegionChange":
            (view as? VarnMapView)?.onRegionChange = { region in reporter.report(region) }

        case "onMarkerPress":
            (view as? VarnMapView)?.onMarkerPress = { marker in reporter.report(marker) }

        case "onProgress":
            (view as? VarnAudioView)?.onProgress = { at in reporter.report(at) }

        case "onReady":
            (view as? VarnAudioView)?.onReady = { about in reporter.report(about) }

        case "onEnd":
            (view as? VarnVideoView)?.onEnd = { reporter.fired() }
            (view as? VarnAudioView)?.onEnd = { reporter.fired() }

        case "onCommit":
            (view as? UISlider)?.addTarget(reporter, action: #selector(VarnEventReporter.changed),
                                           for: [.touchUpInside, .touchUpOutside])

        default:
            break
        }
    }
}

/// Carries one event from a view back to the engine, holding the identity the tree knows it by.
final class VarnEventReporter: NSObject {
    private static let key = UnsafeRawPointer(UnsafeMutablePointer<UInt8>.allocate(capacity: 1))

    private let id: Int
    let event: String
    private let emit: VarnProps.EventSink
    private var recognizers: [UIGestureRecognizer] = []

    init(id: Int, event: String, emit: @escaping VarnProps.EventSink) {
        self.id = id
        self.event = event
        self.emit = emit
    }

    /// Keeps the reporter alive for as long as the view reports that event, answering the one it replaces.
    ///
    /// A handler that comes and goes is bound again each time it comes back, and a reporter added beside
    /// the one already there leaves a single press reported twice, then three times.
    @discardableResult
    static func retain(_ reporter: VarnEventReporter, on view: UIView) -> VarnEventReporter? {
        var reporters = objc_getAssociatedObject(view, key) as? [String: VarnEventReporter] ?? [:]
        let replaced = reporters[reporter.event]

        reporters[reporter.event] = reporter
        objc_setAssociatedObject(view, key, reporters, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return replaced
    }

    func attach(_ recognizer: UIGestureRecognizer, to view: UIView) {
        recognizers.append(recognizer)
        view.addGestureRecognizer(recognizer)
    }

    /// Takes back whatever this reporter was listening through, so nothing it reported through is left.
    func detach(from view: UIView) {
        for recognizer in recognizers {
            view.removeGestureRecognizer(recognizer)
        }

        recognizers = []
        (view as? UIControl)?.removeTarget(self, action: nil, for: .allEvents)
    }

    @objc func fired() {
        emit(id, event, NSNull())
    }

    func report(_ payload: Any) {
        emit(id, event, payload)
    }

    /// Reports a long press once, when the finger has been held long enough for it to be one.
    ///
    /// A recogniser reports every state it passes through, so binding to it directly reported the same
    /// press again when the finger moved and again when it was lifted.
    @objc func held(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }

        emit(id, event, NSNull())
    }

    /// Reports a swipe by the way it went, which is what an item does something different for.
    @objc func swiped(_ recognizer: UISwipeGestureRecognizer) {
        let direction: String

        switch recognizer.direction {
        case .left: direction = "left"
        case .right: direction = "right"
        case .up: direction = "up"
        case .down: direction = "down"
        default: return
        }

        emit(id, event, ["direction": direction])
    }

    @objc func changed(_ sender: Any) {
        let payload = VarnEventReporter.value(of: sender)

        // What a field says is what it is answered with a commit later, by which time the reader has
        // typed again, so it remembers what it said and refuses to be written back to any of it.
        if let field = sender as? VarnTextField, let text = payload as? String {
            field.reported(text)
        }

        emit(id, event, payload)
    }

    private static func value(of sender: Any) -> Any {
        if let toggle = sender as? UISwitch { return toggle.isOn }
        if let slider = sender as? UISlider { return Double(slider.value) }
        if let field = sender as? UITextField { return field.text ?? "" }
        if let segmented = sender as? UISegmentedControl { return segmented.selectedSegmentIndex + 1 }
        if let stepper = sender as? UIStepper { return stepper.value }
        if let check = sender as? VarnCheckView { return check.isChecked }
        if let picker = sender as? VarnDatePicker { return picker.chosen }
        if let well = sender as? UIColorWell { return VarnStyle.hex(well.selectedColor) }
        return NSNull()
    }
}
