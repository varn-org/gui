import XCTest
import UIKit
@testable import VarnGUIRenderer

/// What a label draws inside the frame it was given, which is not always where UIKit would draw it.
final class TextTests: XCTestCase {
    private var surface: UIView!
    private var renderer: VarnRenderer!

    override func setUp() {
        super.setUp()
        surface = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        renderer = VarnRenderer(surface: surface) { _, _, _ in }
    }

    private func label(_ style: [String: Any]) throws -> VarnLabel {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "text", "props": ["text": "Shows", "style": style]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "frame", "id": 1, "x": 0, "y": 0, "width": 390, "height": 40],
        ])

        return try XCTUnwrap(surface.subviews.first as? VarnLabel)
    }

    /// A label draws its text against its own bounds, so padding the engine worked into the frame is
    /// invisible unless the text is inset within it: a heading told to keep a margin drew flush against
    /// the side of the screen.
    func testTextKeepsThePaddingItWasGiven() throws {
        let heading = try label(["paddingHorizontal": 16, "fontSize": 28])

        XCTAssertEqual(heading.insets.left, 16, "a label must keep the padding it was given")
        XCTAssertEqual(heading.insets.right, 16, "on both sides")
        XCTAssertEqual(heading.insets.top, 0, "and nothing it was not given")
    }

    func testTextWithNoPaddingIsNotInset() throws {
        let plain = try label(["fontSize": 17])

        XCTAssertEqual(plain.insets, .zero, "a label told nothing is drawn where UIKit draws it")
    }

    func testEveryEdgeIsTakenOnItsOwn() throws {
        let boxed = try label(["paddingTop": 4, "paddingLeft": 12, "paddingBottom": 8, "paddingRight": 2])

        XCTAssertEqual(boxed.insets, UIEdgeInsets(top: 4, left: 12, bottom: 8, right: 2))
    }
}
