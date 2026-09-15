import XCTest
import UIKit
@testable import VarnGUIRenderer

/// What a node reports back, and how often.
///
/// Each of these was a node that looked right and answered nothing, or answered too much: a textarea
/// that never said what was typed into it, a long press that fired three times for one press, a
/// paragraph whose line count was undone by the style that followed it, and a scroll view that reported
/// no scrolling at all because only a list had ever been given a delegate.
final class EventTests: XCTestCase {
    private var surface: UIView!
    private var renderer: VarnRenderer!
    private var reported: [(Int, String, Any?)] = []

    override func setUp() {
        super.setUp()
        reported = []
        surface = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        renderer = VarnRenderer(surface: surface) { [weak self] id, name, payload in
            self?.reported.append((id, name, payload))
        }
    }

    private func build(_ type: String, _ props: [String: Any]) throws -> UIView {
        try renderer.apply([
            ["op": "create", "id": 1, "type": type, "props": props],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "frame", "id": 1, "x": 0, "y": 0, "width": 390, "height": 200],
        ])

        return try XCTUnwrap(surface.subviews.first)
    }

    func testTypingIntoATextareaIsReported() throws {
        let area = try XCTUnwrap(build("textarea", ["onChange": true]) as? VarnTextView)

        area.text = "written"
        area.delegate?.textViewDidChange?(area)

        XCTAssertEqual(reported.count, 1, "typing must be reported")
        XCTAssertEqual(reported.first?.1, "onChange", "and reported as a change")
        XCTAssertEqual(reported.first?.2 as? String, "written", "carrying what was typed")
    }

    func testALongPressIsReportedOnce() throws {
        let box = try build("pressable", ["onLongPress": true])
        let recognizer = try XCTUnwrap(box.gestureRecognizers?.first as? UILongPressGestureRecognizer)
        let target = try XCTUnwrap(recognizer.value(forKey: "targets") as? [AnyObject])

        XCTAssertFalse(target.isEmpty, "the press must be watched for")

        // A recogniser reports every state it passes through, and only the first of them is the press.
        let reporter = VarnEventReporter(id: 1, event: "onLongPress") { [weak self] id, name, payload in
            self?.reported.append((id, name, payload))
        }

        reporter.held(FakeRecognizer(.began))
        reporter.held(FakeRecognizer(.changed))
        reporter.held(FakeRecognizer(.ended))

        XCTAssertEqual(reported.count, 1, "one press is one report, got \(reported.count)")
    }

    func testALineCountSurvivesTheStyleThatFollowsIt() throws {
        let label = try XCTUnwrap(build("text", ["text": "long", "numberOfLines": 2]) as? VarnLabel)

        XCTAssertEqual(label.numberOfLines, 2, "the line count must be applied")

        // A style and a prop arrive in no order at all, so applying one may not undo the other.
        try renderer.apply([["op": "update", "id": 1, "props": ["style": ["fontSize": 17]]]])

        XCTAssertEqual(label.numberOfLines, 2, "and must survive a style applied after it")
    }

    func testAFrameLandsWhereItWasAskedForWhileTheViewIsMoving() throws {
        let box = try build("view", ["style": ["opacity": 1]])

        // A screen arriving carries a transform for as long as it takes to arrive, and a commit lands
        // whenever it lands. Writing a frame through a transform is undefined, and it moved the view
        // for good by however far the animation had travelled.
        box.transform = CGAffineTransform(translationX: 40, y: 0)

        try renderer.apply([["op": "frame", "id": 1, "x": 0, "y": 0, "width": 390, "height": 200]])

        box.transform = .identity

        XCTAssertEqual(box.frame.origin.x, 0, "a moving view is placed where it was asked for")
        XCTAssertEqual(box.frame.width, 390, "at the size it was asked for")
    }

    func testPlacingAScrollingViewLeavesItWhereItWasScrolledTo() throws {
        let scroll = try XCTUnwrap(build("scroll", ["onScroll": true]) as? VarnCollectionView)

        scroll.setContentExtent(4000)
        scroll.contentOffset = CGPoint(x: 0, y: 600)

        // A commit lands whenever it lands, and a list is usually somewhere other than its top by then.
        try renderer.apply([["op": "frame", "id": 1, "x": 0, "y": 0, "width": 390, "height": 400]])

        XCTAssertEqual(scroll.contentOffset.y, 600, "placing a list may not scroll it back to the top")
    }

    func testAPlainScrollViewReportsScrolling() throws {
        let scroll = try XCTUnwrap(build("scroll", ["onScroll": true]) as? VarnCollectionView)

        scroll.contentOffset = CGPoint(x: 0, y: 120)

        XCTAssertFalse(reported.isEmpty, "a scroll view must report scrolling")
        XCTAssertEqual(reported.first?.1, "onScroll", "and report it as one")
    }


    /// A field being typed into is not written back to what it said a moment ago.
    ///
    /// A tree answers a keystroke with the value it has just been told, and by the time that lands the
    /// reader has typed again: writing it back put the field where it was and "Are you there" arrived
    /// as "Are".
    func testAFieldKeepsWhatWasTypedWhileTheTreeCatchesUp() throws {
        let field = try XCTUnwrap(build("textinput", ["value": "", "onChange": true]) as? VarnTextField)

        field.becomeFirstResponder()
        field.text = "Are"
        field.sendActions(for: .editingChanged)

        field.text = "Are you"
        field.sendActions(for: .editingChanged)

        // The reader carries on typing while the commits for both of those are still on their way.
        field.text = "Are you there"

        try renderer.apply([["op": "update", "id": 1, "props": ["value": "Are"]]])
        try renderer.apply([["op": "update", "id": 1, "props": ["value": "Are you"]]])

        XCTAssertEqual(field.text, "Are you there", "nothing the field itself said is written back to it")

        try renderer.apply([["op": "update", "id": 1, "props": ["value": ""]]])
        XCTAssertEqual(field.text, "", "and a value the tree really did change is applied")
    }
    /// Where the caret went is reported through the one moment the platform publishes for it.
    ///
    /// A field's `selectedTextRange` is set by UIKit without going through anything a subclass can
    /// observe, so a handler hung on the property is one that never fires — which is a promise in the
    /// reference that nothing keeps.
    func testMovingTheCaretInAFieldIsReported() throws {
        let field = try XCTUnwrap(build("textinput", ["onSelectionChange": true]) as? VarnTextField)

        field.text = "Ada Lovelace"
        field.selectedTextRange = field.textRange(
            from: try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 4)),
            to: try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 12))
        )

        let told = reported.filter { $0.1 == "onSelectionChange" }

        // The platform calls the delegate itself when the range is set, which is the whole point of
        // reporting through it: a handler hung on the property would never have been reached at all.
        XCTAssertFalse(told.isEmpty, "moving the caret must be reported")

        let where_ = try XCTUnwrap(told.last?.2 as? [String: Any])

        XCTAssertEqual(where_["start"] as? Int, 4, "carrying where the selection starts")
        XCTAssertEqual(where_["end"] as? Int, 12, "and where it ends")
    }

    /// A box listening for a key takes the keyboard, since that is what a key is delivered through.
    func testABoxListeningForAKeyCanTakeTheKeyboard() throws {
        let plain = try XCTUnwrap(build("pressable", ["onPress": true]) as? VarnPressableView)

        XCTAssertFalse(plain.canBecomeFirstResponder, "a box nobody is listening to takes no keyboard")

        try renderer.apply([
            ["op": "create", "id": 2, "type": "pressable", "props": ["onKeyDown": true]],
            ["op": "insert", "id": 2, "parent": 0, "index": 2],
        ])

        let listening = try XCTUnwrap(surface.subviews.last as? VarnPressableView)

        XCTAssertTrue(listening.canBecomeFirstResponder, "and one that is can be reached by a key")
    }

    /// A double press is the platform's own gesture rather than two presses counted here.
    func testADoublePressIsItsOwnGesture() throws {
        let box = try build("pressable", ["onDoublePress": true])

        let twice = box.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }
            .first { $0.numberOfTapsRequired == 2 }

        XCTAssertNotNil(twice, "a box listening for a double press carries the gesture for one")
    }

    /// An editor draws its marks once the whole batch is in, since a style in it decides the face.
    ///
    /// Writing a font onto a text view replaces the font of every run it holds, and the props of one
    /// batch arrive in no order: the same document came out in one weight or in two depending on which
    /// of the two happened to be applied last.
    func testAnEditorDrawsItsMarksWhateverOrderTheBatchArrivesIn() throws {
        let document: [[String: Any]] = [
            ["text": "plain ", "marks": [String: Any]()],
            ["text": "heavy", "marks": ["bold": true]],
        ]

        try renderer.apply([
            ["op": "create", "id": 3, "type": "richeditor", "props": [
                "value": document,
                "style": ["fontSize": 20],
            ]],
            ["op": "insert", "id": 3, "parent": 0, "index": 1],
            ["op": "frame", "id": 3, "x": 0, "y": 0, "width": 390, "height": 200],
        ])

        let editor = try XCTUnwrap(surface.subviews.compactMap { $0 as? VarnRichEditor }.first)
        let whole = try XCTUnwrap(editor.attributedText)

        XCTAssertEqual(whole.string, "plain heavy", "the editor holds the document it was given")

        let heavy = whole.attribute(.font, at: 7, effectiveRange: nil) as? UIFont
        let plain = whole.attribute(.font, at: 1, effectiveRange: nil) as? UIFont

        XCTAssertEqual(heavy?.fontDescriptor.symbolicTraits.contains(.traitBold), true,
                       "a run marked bold is drawn in the platform's own bold")
        XCTAssertEqual(plain?.fontDescriptor.symbolicTraits.contains(.traitBold), false,
                       "and one that is not is not")
        XCTAssertEqual(heavy?.pointSize, 20, "both at the size the style asked for")
    }

    /// What the editor reports is the document, read back out of what the platform is holding.
    func testAnEditorReportsTheDocumentItHolds() throws {
        try renderer.apply([
            ["op": "create", "id": 4, "type": "richeditor", "props": [
                "value": [["text": "one", "marks": ["italic": true]]],
                "onChange": true,
            ]],
            ["op": "insert", "id": 4, "parent": 0, "index": 1],
            ["op": "frame", "id": 4, "x": 0, "y": 0, "width": 390, "height": 200],
        ])

        let editor = try XCTUnwrap(surface.subviews.compactMap { $0 as? VarnRichEditor }.first)
        let runs = editor.document()

        XCTAssertEqual(runs.count, 1, "one run went in and one came back")
        XCTAssertEqual(runs.first?["text"] as? String, "one", "carrying what was written")

        let marks = try XCTUnwrap(runs.first?["marks"] as? [String: Any])

        XCTAssertEqual(marks["italic"] as? Bool, true, "and the mark it was given")
    }

    /// A mark applied to a selection changes the document rather than a copy of it.
    func testTogglingAMarkOverASelectionChangesTheDocument() throws {
        try renderer.apply([
            ["op": "create", "id": 5, "type": "richeditor", "props": [
                "value": [["text": "one two", "marks": [String: Any]()]],
                "onChange": true,
            ]],
            ["op": "insert", "id": 5, "parent": 0, "index": 1],
            ["op": "frame", "id": 5, "x": 0, "y": 0, "width": 390, "height": 200],
        ])

        let editor = try XCTUnwrap(surface.subviews.compactMap { $0 as? VarnRichEditor }.first)

        editor.selectedRange = NSRange(location: 0, length: 3)
        _ = try renderer.invoke(id: 5, method: "toggleMark", arguments: ["mark": "bold"])

        let runs = editor.document()

        XCTAssertEqual(runs.count, 2, "the selection is a run of its own now, got \(runs.count)")
        XCTAssertEqual((runs.first?["marks"] as? [String: Any])?["bold"] as? Bool, true,
                       "and it carries the mark")
        XCTAssertNil((runs.last?["marks"] as? [String: Any])?["bold"], "while the rest does not")
    }

}

/// A recogniser standing in a state of its own, since a real one only ever reports what a finger did.
private final class FakeRecognizer: UIGestureRecognizer {
    private let held: UIGestureRecognizer.State

    init(_ state: UIGestureRecognizer.State) {
        held = state
        super.init(target: nil, action: nil)
    }

    override var state: UIGestureRecognizer.State {
        get { held }
        set { _ = newValue }
    }

}
