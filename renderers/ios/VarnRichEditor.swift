import UIKit

/// An editor over styled text, which is one box a reader types into rather than two that mirror.
///
/// The platform holds a document as an attributed string, which is what this is: the marks the tree
/// carries are turned into attributes going in and read back out of them coming out. Every mark is drawn
/// with what the platform draws its own with — its bold face, its italic, its monospace — so what a
/// reader sees is the system's typography rather than a weight the tree named.
final class VarnRichEditor: UITextView, UITextViewDelegate, VarnKeyed, VarnSettling {
    var onChange: (([[String: Any]]) -> Void)?
    var onSelection: (([String: Any]) -> Void)?
    var onFocus: (() -> Void)?
    var onBlur: (() -> Void)?

    var limit: Int?
    var onKey: ((String, [String: Any]) -> Void)?

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

    /// The colour a link is drawn in, which is the look's rather than the platform's own blue.
    var linkColor: UIColor? {
        didSet { rewrite() }
    }

    /// The words shown while there is nothing written, which a text view has none of on this platform.
    private let hint = UILabel()

    var placeholder: String? {
        didSet {
            hint.text = placeholder
            showHint()
        }
    }

    /// What the words in an empty editor are drawn in, which the look decides rather than the platform.
    var placeholderColor: UIColor? {
        didSet { hint.textColor = placeholderColor ?? .placeholderText }
    }

    /// The document the tree last gave it, kept so a change of look can be drawn again from it.
    private var runs: [[String: Any]] = []

    /// What this has reported since it was last written to, which is what a write may ignore.
    ///
    /// A tree answers a keystroke with the document it has just been told, and by then the reader has
    /// typed two more, so writing that back takes the caret to the end of it on every keystroke.
    private var said: [String] = []

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)

        delegate = self
        backgroundColor = .clear
        isEditable = true

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

    /// What the document was last drawn with, so a change of face is drawn again and nothing else is.
    private var drawnWith: UIFont?

    /// Whether the tree has written a document that has not been drawn yet.
    private var owed = false

    /// Draws the document once the whole batch is in, since a style in it decides what a mark is drawn at.
    ///
    /// Writing a font onto a text view replaces the font of every run it is holding, and the props of one
    /// batch arrive in no order, so a document written before the style came out in one weight throughout
    /// and one written after came out correctly — the same tree, drawn two ways by the order of a table.
    /// Nothing is redrawn otherwise, or every keystroke would put the caret back where the document starts.
    func settle() {
        guard owed || font != drawnWith else {
            return
        }

        owed = false
        drawnWith = font
        rewrite()
    }

    /// Takes the document the tree holds, unless it is one this editor said itself.
    func setValue(_ given: [[String: Any]]) {
        runs = given

        let written = VarnRichEditor.plain(given)

        if said.contains(written), written == text {
            said.removeAll()
            return
        }

        said.removeAll()
        owed = true
    }

    /// Draws the document again, keeping the caret where the reader left it.
    private func rewrite() {
        let where_ = selectedRange

        attributedText = built(from: runs)
        selectedRange = NSRange(
            location: min(where_.location, (text ?? "").utf16.count),
            length: 0
        )

        showHint()
    }

    /// Answers the attributed string a document comes to, which is what the platform edits.
    private func built(from given: [[String: Any]]) -> NSAttributedString {
        let whole = NSMutableAttributedString()

        for run in given {
            let text = run["text"] as? String ?? ""
            let marks = run["marks"] as? [String: Any] ?? [:]

            whole.append(NSAttributedString(string: text, attributes: attributes(of: marks)))
        }

        return whole
    }

    /// Answers what one set of marks is drawn with, which is the platform's own faces and nothing named.
    private func attributes(of marks: [String: Any]) -> [NSAttributedString.Key: Any] {
        let size = font?.pointSize ?? UIFont.preferredFont(forTextStyle: .body).pointSize
        var face = font ?? UIFont.systemFont(ofSize: size)

        if marks["code"] as? Bool == true {
            face = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }

        var traits: UIFontDescriptor.SymbolicTraits = []

        if marks["bold"] as? Bool == true {
            traits.insert(.traitBold)
        }

        if marks["italic"] as? Bool == true {
            traits.insert(.traitItalic)
        }

        if !traits.isEmpty, let descriptor = face.fontDescriptor.withSymbolicTraits(traits) {
            face = UIFont(descriptor: descriptor, size: size)
        }

        var held: [NSAttributedString.Key: Any] = [.font: face, .foregroundColor: textColor ?? .label]

        if marks["underline"] as? Bool == true {
            held[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if marks["strikethrough"] as? Bool == true {
            held[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        if let where_ = marks["link"] as? String {
            held[.link] = where_
            held[.foregroundColor] = linkColor ?? .link
            held[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        return held
    }

    /// Answers the document as runs, which is what the tree holds and what a screen draws from.
    func document() -> [[String: Any]] {
        var found: [[String: Any]] = []

        attributedText.enumerateAttributes(
            in: NSRange(location: 0, length: attributedText.length),
            options: []
        ) { attributes, range, _ in
            let text = (attributedText.string as NSString).substring(with: range)
            let marks = VarnRichEditor.marks(of: attributes)

            if let last = found.last,
               VarnRichEditor.same(last["marks"] as? [String: Any] ?? [:], marks) {
                found[found.count - 1]["text"] = (last["text"] as? String ?? "") + text
                return
            }

            found.append(["text": text, "marks": marks])
        }

        return found
    }

    /// Answers the marks one set of attributes stands for, which is the other half of what draws them.
    static func marks(of attributes: [NSAttributedString.Key: Any]) -> [String: Any] {
        var held: [String: Any] = [:]

        if let face = attributes[.font] as? UIFont {
            let traits = face.fontDescriptor.symbolicTraits

            if traits.contains(.traitBold) {
                held["bold"] = true
            }

            if traits.contains(.traitItalic) {
                held["italic"] = true
            }

            if traits.contains(.traitMonoSpace) {
                held["code"] = true
            }
        }

        if attributes[.underlineStyle] != nil {
            held["underline"] = true
        }

        if attributes[.strikethroughStyle] != nil {
            held["strikethrough"] = true
        }

        if let where_ = attributes[.link] {
            held["link"] = (where_ as? String) ?? (where_ as? URL)?.absoluteString ?? ""
            held["underline"] = nil
        }

        return held
    }

    static func same(_ one: [String: Any], _ other: [String: Any]) -> Bool {
        if one.count != other.count {
            return false
        }

        for (name, value) in one where String(describing: other[name]) != String(describing: value) {
            return false
        }

        return true
    }

    static func plain(_ given: [[String: Any]]) -> String {
        given.map { $0["text"] as? String ?? "" }.joined()
    }

    /// Turns a mark on or off over what is selected, or over what is typed next when nothing is.
    func toggle(_ mark: String) {
        let range = selectedRange

        if range.length == 0 {
            var marks = VarnRichEditor.marks(of: typingAttributes)

            marks[mark] = marks[mark] == nil ? true : nil
            typingAttributes = attributes(of: marks)
            report()
            return
        }

        let written = NSMutableAttributedString(attributedString: attributedText)
        let on = !carries(mark, in: range)

        written.enumerateAttributes(in: range, options: []) { attributes, at, _ in
            var marks = VarnRichEditor.marks(of: attributes)

            marks[mark] = on ? true : nil
            written.setAttributes(self.attributes(of: marks), range: at)
        }

        replace(written, keeping: range)
    }

    /// Points what is selected at an address, or takes the address off it.
    func link(_ where_: String?) {
        let range = selectedRange

        guard range.length > 0 else {
            return
        }

        let written = NSMutableAttributedString(attributedString: attributedText)

        written.enumerateAttributes(in: range, options: []) { attributes, at, _ in
            var marks = VarnRichEditor.marks(of: attributes)

            marks["link"] = where_
            written.setAttributes(self.attributes(of: marks), range: at)
        }

        replace(written, keeping: range)
    }

    private func carries(_ mark: String, in range: NSRange) -> Bool {
        var everywhere = true

        attributedText.enumerateAttributes(in: range, options: []) { attributes, _, _ in
            if VarnRichEditor.marks(of: attributes)[mark] == nil {
                everywhere = false
            }
        }

        return everywhere
    }

    private func replace(_ written: NSAttributedString, keeping range: NSRange) {
        attributedText = written
        selectedRange = range

        runs = document()
        onChange?(runs)
        report()
    }

    /// Says where the caret is and what is on there, which is what a toolbar draws itself from.
    func report() {
        let range = selectedRange
        var marks: [String: Any] = [:]

        if range.length == 0 {
            marks = VarnRichEditor.marks(of: typingAttributes)
        } else {
            attributedText.enumerateAttributes(in: range, options: []) { attributes, _, _ in
                for (name, value) in VarnRichEditor.marks(of: attributes) {
                    marks[name] = value
                }
            }
        }

        onSelection?(["start": range.location, "end": range.location + range.length, "marks": marks])
    }

    func textView(_ text: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
        VarnLimit.allows(text.text, range, replacementText, limit)
    }

    func textViewDidChange(_ text: UITextView) {
        showHint()

        runs = document()
        said.append(VarnRichEditor.plain(runs))

        if said.count > 64 {
            said.removeFirst()
        }

        onChange?(runs)
        report()
    }

    func textViewDidChangeSelection(_ text: UITextView) {
        report()
    }

    func textViewDidBeginEditing(_ text: UITextView) {
        onFocus?()
    }

    func textViewDidEndEditing(_ text: UITextView) {
        onBlur?()
    }
}
