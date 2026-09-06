import XCTest
import UIKit
@testable import VarnGUIRenderer

/// The conformance cases of gui/bridge/conformance.lua, run against the real UIKit renderer.
///
/// The names match the Lua suite exactly, and gui/tests/conformance_test.lua asserts that they still
/// do, so a case added on one side cannot be forgotten on the other.
final class ConformanceTests: XCTestCase {
    private var surface = UIView()
    private var renderer: VarnRenderer!
    private var events: [(Int, String, Any)] = []

    override func setUp() {
        super.setUp()

        surface = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        events = []
        renderer = VarnRenderer(surface: surface) { [weak self] id, name, payload in
            self?.events.append((id, name, payload))
        }
    }

    /// The tree a renderer built, read back the way the Lua suite reads its own.
    private func tree(_ holder: UIView? = nil) -> [UIView] {
        let container = holder ?? surface
        return VarnViewFactory.contentView(of: container).subviews.filter { $0.tag != 0 }
    }

    private func only(_ views: [UIView], _ message: String = "expected one root") throws -> UIView {
        try XCTUnwrap(views.count == 1 ? views.first : nil, "\(message), found \(views.count)")
    }

    func testCreatesAndAttachesARoot() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "view", "props": [:]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
        ])

        let root = try only(tree())
        XCTAssertTrue(root is VarnView, "the root must be the node that was created")
        XCTAssertEqual(tree(root).count, 0, "a fresh root has no children")
    }

    func testNestsChildrenInTheOrderTheyWereInserted() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "view", "props": [:]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "create", "id": 2, "type": "text", "props": ["text": "a"]],
            ["op": "insert", "id": 2, "parent": 1, "index": 1],
            ["op": "create", "id": 3, "type": "text", "props": ["text": "b"]],
            ["op": "insert", "id": 3, "parent": 1, "index": 2],
        ])

        let children = tree(try only(tree()))
        XCTAssertEqual((children[0] as? UILabel)?.text, "a", "the first child must come first")
        XCTAssertEqual((children[1] as? UILabel)?.text, "b", "the second child must come second")
    }

    func testUpdatesOnlyThePropsItWasGiven() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "view", "props": ["style": ["opacity": 1.0], "testID": "root"]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "update", "id": 1, "props": ["style": ["opacity": 0.5]]],
        ])

        let root = try only(tree())
        XCTAssertEqual(root.alpha, 0.5, accuracy: 0.001, "the changed prop must be applied")
        XCTAssertEqual(root.accessibilityIdentifier, "root", "an untouched prop must survive")
    }

    func testDropsAPropAnUpdateMarkedRemoved() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "view", "props": ["testID": "root"]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "update", "id": 1, "props": ["testID": "__varn_removed__"]],
        ])

        XCTAssertNil(try only(tree()).accessibilityIdentifier, "a removed prop must be gone")
    }

    func testMovesAChildWithoutRebuildingIt() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "view", "props": [:]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "create", "id": 2, "type": "text", "props": ["text": "a"]],
            ["op": "insert", "id": 2, "parent": 1, "index": 1],
            ["op": "create", "id": 3, "type": "text", "props": ["text": "b"]],
            ["op": "insert", "id": 3, "parent": 1, "index": 2],
        ])

        let root = try only(tree())
        let before = tree(root)[0]

        try renderer.apply([["op": "move", "id": 2, "parent": 1, "index": 2]])

        let children = tree(root)
        XCTAssertEqual((children[0] as? UILabel)?.text, "b", "the moved node must leave its place")
        XCTAssertEqual((children[1] as? UILabel)?.text, "a", "the moved node must arrive at the new one")
        XCTAssertTrue(children[1] === before, "a move must keep the widget it moved")
    }

    func testRemovesASubtreeWhole() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "view", "props": [:]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "create", "id": 2, "type": "view", "props": [:]],
            ["op": "insert", "id": 2, "parent": 1, "index": 1],
            ["op": "create", "id": 3, "type": "text", "props": ["text": "deep"]],
            ["op": "insert", "id": 3, "parent": 2, "index": 1],
        ])

        try renderer.apply([
            ["op": "remove", "id": 3],
            ["op": "remove", "id": 2],
        ])

        XCTAssertEqual(tree(try only(tree())).count, 0, "the subtree must be gone")
        XCTAssertThrowsError(try renderer.invoke(id: 2, method: "focus", arguments: [:]),
                             "a removed node must be forgotten")
    }

    func testPlacesANodeAtTheFrameItWasGiven() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "view", "props": [:]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "frame", "id": 1, "x": 12, "y": 24, "width": 100, "height": 40],
        ])

        XCTAssertEqual(try only(tree()).frame, CGRect(x: 12, y: 24, width: 100, height: 40),
                       "the node must sit where it was placed, at the size it was given")
    }

    func testReparentsANodeRatherThanDuplicatingIt() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "view", "props": [:]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "create", "id": 2, "type": "view", "props": [:]],
            ["op": "insert", "id": 2, "parent": 0, "index": 2],
            ["op": "create", "id": 3, "type": "text", "props": ["text": "moved"]],
            ["op": "insert", "id": 3, "parent": 1, "index": 1],
        ])

        try renderer.apply([["op": "move", "id": 3, "parent": 2, "index": 1]])

        let roots = tree()
        XCTAssertEqual(tree(roots[0]).count, 0, "the old parent must have let go")
        XCTAssertEqual(tree(roots[1]).count, 1, "the new parent must have taken it")
        XCTAssertEqual((tree(roots[1])[0] as? UILabel)?.text, "moved", "the node itself must have moved")
    }

    func testRefusesABatchThatBreaksTheContract() {
        XCTAssertThrowsError(try renderer.apply([["op": "update", "id": 1]]),
                             "an update with no props must be refused")
        XCTAssertThrowsError(try renderer.apply([["op": "nonsense", "id": 1]]),
                             "an unknown operation must be refused")
    }

    func testAnswersAMeasurementForAString() {
        let size = renderer.measureText("hello", style: ["fontSize": CGFloat(16)], bound: nil)

        XCTAssertGreaterThan(size["width"] ?? 0, 0, "a measurement must carry a width")
        XCTAssertGreaterThan(size["height"] ?? 0, 0, "a measurement must carry a height")
    }

    func testAnswersAFiniteMeasurementHoweverItIsBounded() {
        for bound in [CGFloat(0), 1, 40, nil] {
            let size = renderer.measureText("a longer sentence", style: ["fontSize": CGFloat(16)], bound: bound)
            let named = bound.map { "\($0)" } ?? "none"
            let width = size["width"] ?? .nan
            let height = size["height"] ?? .nan

            XCTAssertTrue(width.isFinite && height.isFinite, "a measurement must be finite at bound \(named)")
            XCTAssertGreaterThan(height, 0, "a line of text is never zero high, at bound \(named)")
        }
    }

    func testReportsAnEventAsWhatTheEventCarries() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "switch", "props": ["value": false, "onChange": true]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "create", "id": 2, "type": "textinput", "props": ["value": "", "onChange": true]],
            ["op": "insert", "id": 2, "parent": 0, "index": 2],
        ])

        let toggle = try XCTUnwrap(tree()[0] as? UISwitch)
        XCTAssertFalse(toggle.allTargets.isEmpty, "a declared handler must be bound to the control")

        toggle.isOn = true
        toggle.sendActions(for: .valueChanged)

        XCTAssertFalse(events.isEmpty, "the control reported nothing, targets=\(toggle.allTargets.count)")

        let changed = try XCTUnwrap(events.last)
        XCTAssertEqual(changed.1, "onChange", "a change is reported by the name of the prop that declared it")
        XCTAssertEqual(changed.2 as? Bool, true, "a change carries the value itself, not a table holding it")

        let field = try XCTUnwrap(tree()[1] as? UITextField)
        XCTAssertFalse(field.allTargets.isEmpty, "a field's handler must be bound to it as well")
    }

    func testReadsARadioValueAsItsIdentityRatherThanItsState() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "radio", "props": ["value": "monthly", "selected": true]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "create", "id": 2, "type": "radio", "props": ["value": "yearly", "selected": false]],
            ["op": "insert", "id": 2, "parent": 0, "index": 2],
        ])

        let chosen = try XCTUnwrap(tree()[0] as? VarnCheckView)
        let other = try XCTUnwrap(tree()[1] as? VarnCheckView)

        XCTAssertTrue(chosen.isChecked, "the chosen radio must be the one marked selected")
        XCTAssertFalse(other.isChecked, "the other radio must be left alone")
    }

    func testLeavesAFieldAloneWhenItsValueHasNotChanged() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "textinput", "props": ["value": "Ada", "onChange": true]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
        ])

        let field = try XCTUnwrap(tree()[0] as? UITextField)
        let caret = try XCTUnwrap(field.position(from: field.beginningOfDocument, offset: 1))
        field.selectedTextRange = field.textRange(from: caret, to: caret)

        try renderer.apply([["op": "update", "id": 1, "props": ["value": "Ada"]]])

        XCTAssertEqual(field.text, "Ada", "the field must hold the value it was given")

        let range = try XCTUnwrap(field.selectedTextRange)
        XCTAssertEqual(field.offset(from: field.beginningOfDocument, to: range.start), 1,
                       "the caret must not have moved")
    }

    func testDeclaresWhatItCanDo() {
        let known = [
            "text", "image", "list", "scroll", "input", "video", "webview", "canvas",
            "picker", "datepicker", "haptics", "safearea",
        ]

        for name in renderer.capabilities.keys {
            XCTAssertTrue(known.contains(name), "\(name) is not a capability the contract names")
        }

        XCTAssertTrue(renderer.capabilities["text"] == true, "a renderer that draws text must say so")
    }
}
