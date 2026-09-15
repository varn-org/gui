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

    /// A stepper goes as far as the tree said, in the steps the tree said, and no further.
    ///
    /// The platform's own control refuses a bound that crosses the other and a step that is not
    /// positive, and the props of one batch arrive in no order, so both are read once the batch has
    /// landed. A stepper told nothing about its bounds goes as far as a number goes, which is what the
    /// browser and Android both do rather than the nought to a hundred `UIStepper` starts at.
    func testAStepperTakesTheBoundsAndTheStepItWasGiven() throws {
        let stepper = try XCTUnwrap(try control("stepper", [
            "value": 4,
            "minimum": 2,
            "maximum": 8,
            "step": 0.5,
        ]) as? VarnStepper)

        XCTAssertEqual(stepper.minimumValue, 2, "a stepper is held to what it was told")
        XCTAssertEqual(stepper.maximumValue, 8, "at both ends")
        XCTAssertEqual(stepper.stepValue, 0.5, "and moves by what it was told")
        XCTAssertEqual(stepper.value, 4, "carrying the value it was given")

        let unbounded = try XCTUnwrap(try control("stepper", ["value": 5000]) as? VarnStepper)

        XCTAssertEqual(unbounded.value, 5000, "a stepper nobody bounded keeps what it was given")
    }

    /// A spinner fills the box the engine sized it into, which is what the named size turns into.
    ///
    /// The platform has two sizes where the framework names three, so the renderer read the name and
    /// drew the default one at the larger of the two: every spinner nobody had named came out oversized,
    /// and the two sizes above the smallest drew the same. Nothing reads the name now.
    func testASpinnerIsDrawnAtTheSizeItWasGiven() throws {
        let drawn = { (side: CGFloat) throws -> CGFloat in
            try self.renderer.apply([
                ["op": "create", "id": 1, "type": "activity", "props": ["animating": true]],
                ["op": "insert", "id": 1, "parent": 0, "index": 1],
                ["op": "frame", "id": 1, "x": 0, "y": 0, "width": side, "height": side],
            ])

            let box = try XCTUnwrap(self.surface.subviews.first as? VarnActivityView)

            box.layoutIfNeeded()

            let spinner = try XCTUnwrap(box.subviews.first)

            try self.renderer.apply([["op": "remove", "id": 1]])
            return spinner.bounds.width * spinner.transform.a
        }

        let small = try drawn(20)
        let large = try drawn(44)

        XCTAssertEqual(small, 20, accuracy: 0.5, "a spinner given twenty points is twenty across")
        XCTAssertEqual(large, 44, accuracy: 0.5, "and one given forty-four is forty-four")
    }

    /// A field over several lines shows the words an empty one is meant to show.
    ///
    /// A one-line field is a `UITextField` and carries a placeholder of its own. A field over several
    /// lines is a `UITextView`, which the platform gives none at all, so the same tree showed the words
    /// on a page and nothing on a phone. Nothing about the tree says so — the field has the right type,
    /// the right size and the right prop — which is why it is read off the view here.
    func testAFieldOverSeveralLinesShowsItsPlaceholder() throws {
        let view = try control("textarea", ["value": "", "placeholder": "Write something"])
        let field = try XCTUnwrap(view as? VarnTextView)

        view.layoutIfNeeded()

        let hint = field.subviews.compactMap { $0 as? UILabel }.first

        XCTAssertEqual(hint?.text, "Write something", "an empty field shows the words it was given")
        XCTAssertEqual(hint?.isHidden, false, "and they are on screen")

        field.text = "typed"

        XCTAssertEqual(hint?.isHidden, true, "and they go as soon as there is something to read")
    }
}
