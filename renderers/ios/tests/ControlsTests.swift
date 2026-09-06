import XCTest
import UIKit
@testable import VarnGUIRenderer

/// What a control reports when it is used, which for two of them on iOS was nothing at all.
///
/// A chooser was a button showing the first option's label and opening nothing, and a rating was a
/// label drawn as stars. Both are declared as controls a caller can change, so both answered a finger
/// with silence — which is what "I touch it and nothing happens" was on the phone.
final class ControlsTests: XCTestCase {
    private var surface: UIView!
    private var renderer: VarnRenderer!
    private var events: [(id: Int, name: String, payload: Any?)] = []

    override func setUp() {
        super.setUp()
        surface = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        events = []
        renderer = VarnRenderer(surface: surface) { id, name, payload in
            self.events.append((id: id, name: name, payload: payload))
        }
    }

    /// Builds one control and answers the view the renderer made for it.
    private func control(_ type: String, _ props: [String: Any]) throws -> UIView {
        try renderer.apply([
            ["op": "create", "id": 1, "type": type, "props": props],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "frame", "id": 1, "x": 0, "y": 0, "width": 200, "height": 40],
        ])

        return surface.subviews[0]
    }

    private func reported() -> [Any?] {
        events.filter { $0.name == "onChange" }.map { $0.payload }
    }

    func testAChooserOffersWhatItHoldsAndReportsTheChoice() throws {
        let options: [[String: Any]] = [["label": "One", "value": "1"], ["label": "Two", "value": "2"]]
        let chooser = try XCTUnwrap(try control("picker", ["options": options, "value": "1", "onChange": true])
            as? VarnChooserButton)

        let menu = try XCTUnwrap(chooser.menu)
        XCTAssertEqual(menu.children.count, 2, "a chooser must offer every option it holds")
        XCTAssertEqual(menu.children.map(\.title), ["One", "Two"], "an option is labelled with what it says")
        XCTAssertEqual(chooser.title(for: .normal), "One", "a chooser shows the option it is set to")

        chooser.pick("2")

        XCTAssertEqual(reported().count, 1, "choosing an option must report it once")
        XCTAssertEqual(reported().first as? String, "2", "a chooser reports the value of what was chosen")
        XCTAssertEqual(chooser.title(for: .normal), "Two", "a chooser shows what was chosen")
    }

    func testAChooserWrittenToReportsNothing() throws {
        let options: [[String: Any]] = [["label": "One", "value": "1"], ["label": "Two", "value": "2"]]
        _ = try control("picker", ["options": options, "value": "2", "onChange": true])

        XCTAssertEqual(reported().count, 0, "the tree writing a value back is not a person choosing one")
    }

    func testARatingIsBuiltOfItsStarsAndReportsTheOneTapped() throws {
        let rating = try XCTUnwrap(try control("rating", ["count": 5, "value": 2, "onChange": true])
            as? VarnRatingView)

        rating.layoutIfNeeded()
        XCTAssertEqual(rating.subviews.count, 5, "a rating must build the stars it was told to hold")

        rating.choose(at: CGPoint(x: rating.bounds.width * 0.7, y: 10))

        XCTAssertEqual(reported().first as? Int, 4, "a star reports the score it stands for")
        XCTAssertEqual(rating.value, 4, "a rating shows the score it was set to")
    }

    func testARatingNobodyIsListeningToReportsNothing() throws {
        let rating = try XCTUnwrap(try control("rating", ["count": 3, "value": 0]) as? VarnRatingView)

        rating.layoutIfNeeded()
        rating.choose(at: CGPoint(x: 10, y: 10))

        XCTAssertEqual(reported().count, 0, "a control nobody is listening to must report nothing")
    }
}
