import XCTest
import UIKit
@testable import VarnGUIRenderer

/// What a box says about itself to a reader who cannot see it.
///
/// A control the platform draws says this for itself. One the engine draws is a box with a colour in it,
/// and that is what VoiceOver reads, so a drawn checkbox that names no role is a checkbox nobody using
/// one can find, let alone tick.
final class AccessTests: XCTestCase {
    private var surface: UIView!
    private var renderer: VarnRenderer!

    override func setUp() {
        super.setUp()

        surface = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        renderer = VarnRenderer(surface: surface) { _, _, _ in }
    }

    private func box(_ props: [String: Any]) throws -> UIView {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "pressable", "props": props],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
        ])

        return try XCTUnwrap(surface.subviews.first)
    }

    func testADrawnControlSaysWhatItIsAndWhatItIsDoing() throws {
        let view = try box([
            "accessibilityLabel": "Keep it",
            "accessibilityRole": "checkbox",
            "accessibilityState": ["checked": true],
        ])

        XCTAssertEqual(view.accessibilityLabel, "Keep it", "the name reaches the control")
        XCTAssertTrue(view.accessibilityTraits.contains(.button), "a checkbox behaves like a button")
        XCTAssertTrue(view.isAccessibilityElement, "and it is one thing rather than the boxes it is built from")

        // UIKit has no trait for being ticked, so what is ticked is said the way VoiceOver reads one.
        XCTAssertEqual(view.accessibilityValue, "1", "a ticked box says it is ticked")

        try renderer.apply([["op": "update", "id": 1, "props": ["accessibilityState": ["checked": false]]]])

        XCTAssertEqual(view.accessibilityValue, "0", "and an unticked one says it is not")
    }

    func testAControlThatCannotBeUsedSaysSo() throws {
        let view = try box([
            "accessibilityRole": "button",
            "accessibilityState": ["disabled": true],
        ])

        XCTAssertTrue(view.accessibilityTraits.contains(.notEnabled),
                      "a control the tree disabled is announced as one a reader cannot use")
    }

    func testAControlThatHoldsANumberSaysWhereItIs() throws {
        let view = try box([
            "accessibilityRole": "slider",
            "accessibilityValue": ["now": 3, "least": 0, "most": 10],
        ])

        XCTAssertTrue(view.accessibilityTraits.contains(.adjustable), "a slider says it can be stepped")
        XCTAssertEqual(view.accessibilityValue, "30%", "and says where it is as a reader hears it")
    }

    func testAControlMaySayWhatItIsAtInItsOwnWords() throws {
        let view = try box([
            "accessibilityRole": "slider",
            "accessibilityValue": ["text": "Two of five"],
        ])

        XCTAssertEqual(view.accessibilityValue, "Two of five", "words the tree wrote are what is read")
    }

    func testABoxThatIsNothingInParticularIsNotOneToReach() throws {
        let view = try box(["accessibilityRole": "none"])

        XCTAssertFalse(view.isAccessibilityElement, "a box that is nothing is not held open for a reader")
    }
}
