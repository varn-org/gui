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
