import AVFoundation
import UIKit
import WebKit

/// Applies one prop to the view that stands for a node, and wires the events it declares.
enum VarnProps {
    /// Tells a box drawn as a control when the keyboard has reached it, which is what draws a focus ring.
    ///
    /// One listener answers both names, since a view says only that focus changed and the name reported
    /// is the direction it went.
    static func watchFocus(_ view: UIView, _ reporter: VarnEventReporter) {
        (view as? VarnFocusing)?.onFocusChange = { focused in
            reporter.report(focused ? "onFocus" : "onBlur", NSNull())
        }
    }

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
            (view as? VarnTextView)?.placeholder = value as? String
            (view as? VarnRichEditor)?.placeholder = value as? String

            if let picture = view as? VarnPictureView, picture.source == nil, let path = value as? String {
                picture.source = UIImage(contentsOfFile: path)
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
            (view as? VarnStepper)?.by = Double(VarnValue.number(value) ?? 1)
            (view as? VarnSlider)?.step = VarnValue.number(value)

        case "continuous":
            (view as? UISlider)?.isContinuous = (value as? Bool) ?? true

        case "refreshing":
            VarnRefresh.show((value as? Bool) ?? false, on: view)

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

        case "bars":
            (view as? VarnSafeAreaView)?.setBars(value as? [String] ?? [])

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

        case "center":
            (view as? VarnMapView)?.setCenter(value as? [String: Any])

        // A map is zoomed to a level and a camera to a factor, which are two different numbers under one
        // name: each type reads the one it means rather than a second case never being reached.
        case "zoom":
            (view as? VarnMapView)?.setZoom(VarnValue.number(value) ?? 14)
            (view as? VarnCameraView)?.zoom = VarnValue.number(value) ?? 1

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
            (view as? VarnWebView)?.scripting = (value as? Bool) ?? true

        case "poster":
            (view as? VarnVideoView)?.showPoster(at: value as? String)

        case "resizeMode":
            applyResizeMode(value as? String, to: view)

        case "filter":
            (view as? VarnPictureView)?.filter = VarnValue.numbers(value)
            (view as? VarnCameraView)?.filter = VarnValue.numbers(value)
            (view as? VarnVideoView)?.filter = VarnValue.numbers(value)

        case "facing":
            (view as? VarnCameraView)?.facing = value as? String ?? "back"

        case "torch":
            (view as? VarnCameraView)?.torch = (value as? Bool) ?? false

        case "audio":
            (view as? VarnCameraView)?.wantsAudio = (value as? Bool) ?? false

        case "recording":
            (view as? VarnRecorderView)?.recording = (value as? Bool) ?? false

        case "source":
            applySource(value, to: view, type: type)

        case "slice":
            (view as? VarnNineSliceView)?.setSlice(slice(value))

        case "sliceScale":
            (view as? VarnNineSliceView)?.setSliceScale(VarnValue.number(value) ?? 1)

        case "sources":
            (view as? VarnNineSliceView)?.setSources(pictures(value))

        case "linkColor":
            (view as? VarnRichEditor)?.linkColor = VarnStyle.color(value)

        case "disabled":
            (view as? UIControl)?.isEnabled = !((value as? Bool) ?? false)

        case "editable":
            (view as? UITextField)?.isEnabled = (value as? Bool) ?? true
            (view as? UITextView)?.isEditable = (value as? Bool) ?? true

        case "autoFocus":
            if (value as? Bool) == true {
                DispatchQueue.main.async { view.becomeFirstResponder() }
            }

        case "maxLength":
            (view as? VarnTextField)?.limit = value as? Int
            (view as? VarnTextView)?.limit = value as? Int
            (view as? VarnRichEditor)?.limit = value as? Int

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


        case "thickness":
            applyThickness(VarnValue.number(value) ?? 4, to: view)

        case "indeterminate":
            applyIndeterminate((value as? Bool) ?? false, to: view)

        case "minimum":
            applyBound(VarnValue.number(value), to: view, least: true)

        case "maximum":
            applyBound(VarnValue.number(value), to: view, least: false)

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

        // What a box is, which UIKit carries as a trait rather than as a name.
        // Which axis this box claims a drag along, which is what lets a slider inside a list be dragged
        // sideways while the list still scrolls down.
        case "panAxis":
            (view as? VarnPressableView)?.panAxis = value as? String

        case "focusable":
            (view as? VarnFocusing)?.wanted = value as? Bool == true

        case "accessibilityRole":
            view.accessibilityTraits = VarnAccess.traits(value as? String)
            view.isAccessibilityElement = value != nil && value as? String != "none"

        // What a box is doing. UIKit has no checked trait, so what is ticked is said in the value the
        // way a screen reader reads one, and what cannot be used stops being reachable at all.
        case "accessibilityState":
            VarnAccess.state(view, value as? [String: Any])

        case "accessibilityValue":
            VarnAccess.reading(view, value as? [String: Any])

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
        // An editor holds a document rather than a string, which is the runs the tree carries.
        if let editor = view as? VarnRichEditor {
            editor.setValue(value as? [[String: Any]] ?? [])
            return
        }

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

        if let stepper = view as? VarnStepper {
            stepper.current = Double(VarnValue.number(value) ?? 0)
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

        // A word an input method is still composing is marked text the system is holding for the reader,
        // and writing the tree's own value over it takes the half-written word away.
        if let typing = view as? UITextInput, typing.markedTextRange != nil {
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
        (view as? VarnActivityView)?.color = colour
        (view as? UIProgressView)?.progressTintColor = colour
    }

    private static func applySource(_ value: Any?, to view: UIView, type: String) {
        guard let path = value as? String else {
            return
        }

        if let picture = view as? VarnPictureView {
            picture.source = UIImage(contentsOfFile: path)
            return
        }

        if let frame = view as? VarnNineSliceView {
            frame.setSource(UIImage(contentsOfFile: path))
            return
        }

        if let video = view as? VarnVideoView {
            video.play(AVPlayerItem(url: url(of: path)))
            return
        }

        (view as? VarnAudioView)?.setSource(path)
    }

    /// Answers the artwork a frame draws each state with, read from the paths the engine resolved.
    private static func pictures(_ value: Any?) -> [String: UIImage] {
        guard let named = value as? [String: Any] else {
            return [:]
        }

        var held: [String: UIImage] = [:]

        for (state, path) in named {
            if let file = path as? String, let picture = UIImage(contentsOfFile: file) {
                held[state] = picture
            }
        }

        return held
    }

    /// Answers where a picture is cut, which the engine sends as four numbers of the picture's own pixels.
    private static func slice(_ value: Any?) -> UIEdgeInsets {
        guard let cuts = value as? [String: Any] else {
            return .zero
        }

        return UIEdgeInsets(
            top: VarnValue.number(cuts["top"]) ?? 0,
            left: VarnValue.number(cuts["left"]) ?? 0,
            bottom: VarnValue.number(cuts["bottom"]) ?? 0,
            right: VarnValue.number(cuts["right"]) ?? 0
        )
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
    /// Says how far a control may be taken, which a slider takes at once and a stepper takes on settling.
    private static func applyBound(_ bound: CGFloat?, to view: UIView, least: Bool) {
        if let slider = view as? UISlider {
            if least {
                slider.minimumValue = Float(bound ?? 0)
            } else {
                slider.maximumValue = Float(bound ?? 1)
            }

            return
        }

        guard let stepper = view as? VarnStepper else {
            return
        }

        if least {
            stepper.least = Double(bound ?? -.greatestFiniteMagnitude)
            return
        }

        stepper.most = Double(bound ?? .greatestFiniteMagnitude)
    }

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
        (view as? VarnActivityView)?.animating = animating
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
        (view as? VarnPictureView)?.tint = VarnStyle.color(value)
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
        guard let colour = VarnStyle.color(value) else {
            return
        }

        if let editor = view as? VarnRichEditor {
            editor.placeholderColor = colour
            return
        }

        guard let field = view as? UITextField else {
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
        // A camera and a microphone report several different things through one closure of their own,
        // since what they produced arrives when the hardware is done with it rather than from a control
        // being used: the name travels with the report rather than being decided when it is bound.
        if let camera = view as? VarnCameraView {
            camera.onEvent = { name, payload in emit(id, name, payload) }
            return
        }

        if let recorder = view as? VarnRecorderView {
            recorder.onEvent = { name, payload in emit(id, name, payload) }
            return
        }

        let reporter = VarnEventReporter(id: id, event: event, emit: emit)
        VarnEventReporter.retain(reporter, on: view)?.detach(from: view)

        switch event {
        case "onPress":
            if let map = view as? VarnMapView {
                map.onPress = { at in reporter.report(at) }
            } else if let control = view as? UIControl {
                // A box that answers a press is a button to whatever reads the screen aloud and to the
                // keyboard that reaches one, however the box itself is built. A control is not announced
                // as one on its own — only `UIButton` is — so a pressable box and a frame drawn from
                // artwork were each reported as plain views to a reader who cannot see them.
                control.accessibilityTraits.insert(.button)
                control.addTarget(reporter, action: #selector(VarnEventReporter.fired), for: .touchUpInside)
            } else {
                view.isUserInteractionEnabled = true
                view.accessibilityTraits.insert(.button)
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

        case "onDoublePress":
            view.isUserInteractionEnabled = true

            let twice = UITapGestureRecognizer(target: reporter, action: #selector(VarnEventReporter.fired))
            twice.numberOfTapsRequired = 2
            reporter.attach(twice, to: view)

        case "onLongPress":
            view.isUserInteractionEnabled = true
            reporter.attach(UILongPressGestureRecognizer(target: reporter,
                                                         action: #selector(VarnEventReporter.held)), to: view)

        // A finger following a path, which is what a slider is. One recogniser reports all three, and
        // which one is reported is the phase it is in rather than the event this binding was made for.
        case "onPanStart", "onPanMove", "onPanEnd":
            view.isUserInteractionEnabled = true

            let dragged = VarnPanRecognizer(target: reporter, action: #selector(VarnEventReporter.dragged))

            dragged.axis = (view as? VarnPressableView)?.panAxis
            reporter.attach(dragged, to: view)

        // The second button on a pointer, and the same gesture made with a finger. A trackpad reports a
        // secondary click and a finger reports a long press, and the tree means one thing by both.
        case "onContextPress":
            view.isUserInteractionEnabled = true

            let secondary = UITapGestureRecognizer(target: reporter,
                                                   action: #selector(VarnEventReporter.pointedAt))
            secondary.buttonMaskRequired = .secondary
            reporter.attach(secondary, to: view)

            let held = UILongPressGestureRecognizer(target: reporter,
                                                    action: #selector(VarnEventReporter.pointedAt))
            reporter.attach(held, to: view)

        // A key reaches whatever has focus, which is what every platform delivers one to. The names are
        // the browser's published set, since that is the only one all three can be mapped onto.
        case "onKeyDown", "onKeyUp":
            (view as? VarnKeyed)?.onKey = { name, payload in reporter.report(name, payload) }

        case "onSelectionChange":
            (view as? VarnTextField)?.onSelection = { where_ in reporter.report(where_) }
            (view as? VarnTextView)?.onSelection = { where_ in reporter.report(where_) }
            (view as? VarnRichEditor)?.onSelection = { where_ in reporter.report(where_) }

        case "onHoverIn", "onHoverOut":
            view.isUserInteractionEnabled = true
            reporter.attach(UIHoverGestureRecognizer(target: reporter,
                                                     action: #selector(VarnEventReporter.hovered)), to: view)

        case "onChange", "onSelect":
            (view as? UIControl)?.addTarget(reporter, action: #selector(VarnEventReporter.changed), for: .valueChanged)
            (view as? UITextField)?.addTarget(reporter, action: #selector(VarnEventReporter.changed), for: .editingChanged)
            (view as? VarnTextView)?.onChange = { typed in reporter.report(typed) }
            (view as? VarnChooserButton)?.onChoose = { chosen in reporter.report(chosen) }
            (view as? VarnRatingView)?.onChoose = { score in reporter.report(score) }
            (view as? VarnLocationView)?.onChange = { fix in reporter.report(fix) }
            (view as? VarnRichEditor)?.onChange = { runs in reporter.report(runs) }

        case "onPick":
            (view as? VarnFilePicker)?.onPick = { files in reporter.report(files) }

        case "onSubmit":
            (view as? UITextField)?.addTarget(reporter, action: #selector(VarnEventReporter.fired), for: .editingDidEndOnExit)

        // A field and a box drawn as a control both say when the keyboard has reached them, and one case
        // answers for both: a second case by the same name is one this switch never reaches.
        case "onFocus":
            (view as? UITextField)?.addTarget(reporter, action: #selector(VarnEventReporter.fired), for: .editingDidBegin)
            (view as? VarnTextView)?.onFocus = { reporter.fired() }
            (view as? VarnRichEditor)?.onFocus = { reporter.fired() }
            VarnProps.watchFocus(view, reporter)

        case "onBlur":
            (view as? UITextField)?.addTarget(reporter, action: #selector(VarnEventReporter.fired), for: .editingDidEnd)
            (view as? VarnTextView)?.onBlur = { reporter.fired() }
            (view as? VarnRichEditor)?.onBlur = { reporter.fired() }
            VarnProps.watchFocus(view, reporter)

        case "onRefresh":
            VarnRefresh.onPull(view) { reporter.fired() }

        case "onScroll":
            if let surface = view as? VarnCollectionView {
                surface.onScroll = { payload in reporter.report(payload) }
                surface.reportOffset()
            }

        case "onScrollEnd":
            (view as? VarnCollectionView)?.onScrollEnd = { payload in reporter.report(payload) }

        // Every view that can fail is wired here: a second branch for the same name is unreachable, and
        // the one that was there left a sound, a film and a page unable to report a failure at all.
        case "onError":
            (view as? VarnLocationView)?.onError = { problem in reporter.report(problem) }
            (view as? VarnAudioView)?.onError = { problem in reporter.report(problem) }
            (view as? VarnVideoView)?.onError = { problem in reporter.report(problem) }
            (view as? VarnWebView)?.onError = { problem in reporter.report(problem) }

        case "onRegionChange":
            (view as? VarnMapView)?.onRegionChange = { region in reporter.report(region) }

        case "onMarkerPress":
            (view as? VarnMapView)?.onMarkerPress = { marker in reporter.report(marker) }

        case "onProgress":
            (view as? VarnAudioView)?.onProgress = { at in reporter.report(at) }
            (view as? VarnVideoView)?.onProgress = { at in reporter.report(at) }

        case "onReady":
            (view as? VarnAudioView)?.onReady = { about in reporter.report(about) }
            (view as? VarnVideoView)?.onReady = { about in reporter.report(about) }

        case "onEnd":
            (view as? VarnVideoView)?.onEnd = { reporter.fired() }
            (view as? VarnAudioView)?.onEnd = { reporter.fired() }

        case "onWillLoad":
            (view as? VarnWebView)?.onWillLoad = { about in reporter.report(about) }

        case "onLoad":
            (view as? VarnWebView)?.onLoad = { about in reporter.report(about) }

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

    /// Reports under a name of its own, which one listener answering two events needs.
    func report(_ named: String, _ payload: Any) {
        emit(id, named, payload)
    }

    /// Reports a pointer arriving over the view and leaving it, which is a trackpad or a mouse.
    ///
    /// One recogniser reports both, so the name it reports under is the phase it is in rather than the
    /// event this reporter was bound for: a view listening for only one of the two is sent only that
    /// one, since the engine drops what the node has no handler for.
    @objc func hovered(_ recognizer: UIGestureRecognizer) {
        if recognizer.state == .began {
            emit(id, "onHoverIn", NSNull())
        }

        if recognizer.state == .ended || recognizer.state == .cancelled {
            emit(id, "onHoverOut", NSNull())
        }
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

    /// Reports a finger following a path, from where it landed to where it was lifted.
    ///
    /// The phase the recogniser is in is the name reported, so one recogniser answers all three and a
    /// view listening for only one of them is sent only that one.
    @objc func dragged(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else {
            return
        }

        let at = recognizer.location(in: view)
        let travelled = recognizer.translation(in: view)
        let payload: [String: Any] = ["x": at.x, "y": at.y, "dx": travelled.x, "dy": travelled.y]

        switch recognizer.state {
        case .began:
            emit(id, "onPanStart", payload)
        case .changed:
            emit(id, "onPanMove", payload)
        case .ended, .cancelled, .failed:
            emit(id, "onPanEnd", payload)
        default:
            break
        }
    }

    /// Reports the second button, or the finger held that means the same thing, and where it happened.
    ///
    /// What it opens is drawn where the pointer was, so a menu does not appear in the corner of the box
    /// that raised it.
    @objc func pointedAt(_ recognizer: UIGestureRecognizer) {
        if recognizer is UILongPressGestureRecognizer && recognizer.state != .began {
            return
        }

        let at = recognizer.location(in: recognizer.view)

        emit(id, "onContextPress", ["x": at.x, "y": at.y])
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
