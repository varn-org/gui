import XCTest
import UIKit
@testable import VarnGUIRenderer

/// What the engine is told a string measures has to be what the platform needs to draw it whole.
///
/// The engine sends finished frames, so a label is given exactly the width it was measured at and has
/// no chance to ask for more. A measurement a fraction short is a label that truncates or wraps, which
/// is the one class of defect a tree-based conformance case cannot see.
final class MeasurementTests: XCTestCase {
    private var renderer: VarnRenderer!

    override func setUp() {
        super.setUp()
        renderer = VarnRenderer(surface: UIView()) { _, _, _ in }
    }

    private static let strings = [
        "Left", "Middle", "Right", "Subscribe to updates", "Fifty thousand rows",
        "A taller cell of its own kind", "you@example.com", "Varn GUI", "Wi",
    ]

    private static let weights = ["400", "500", "600", "700"]

    func testMeasuresAStringWideEnoughToDrawItWhole() {
        for text in Self.strings {
            for weight in Self.weights {
                for size in [CGFloat(12), 13, 16, 17, 22, 34] {
                    let style: [String: Any] = ["fontSize": size, "fontWeight": weight]
                    let measured = renderer.measureText(text, style: style, bound: nil)
                    let width = try! XCTUnwrap(measured["width"])

                    let label = UILabel()
                    label.font = VarnStyle.font(from: style)
                    label.text = text
                    label.numberOfLines = 1

                    let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                           height: CGFloat.greatestFiniteMagnitude)
                    let needed = label.sizeThatFits(unbounded).width

                    XCTAssertGreaterThanOrEqual(width, needed,
                        "\(text) at \(size) weight \(weight) measured \(width) but needs \(needed)")
                }
            }
        }
    }

    func testMeasuresAStringTallEnoughToDrawItWhole() {
        for text in Self.strings {
            for size in [CGFloat(12), 16, 22] {
                let style: [String: Any] = ["fontSize": size]
                let measured = renderer.measureText(text, style: style, bound: nil)
                let height = try! XCTUnwrap(measured["height"])

                let label = UILabel()
                label.font = VarnStyle.font(from: style)
                label.text = text
                label.numberOfLines = 1

                let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                       height: CGFloat.greatestFiniteMagnitude)
                let needed = label.sizeThatFits(unbounded).height

                XCTAssertGreaterThanOrEqual(height, needed,
                    "\(text) at \(size) measured \(height) high but needs \(needed)")
            }
        }
    }

    /// The size a control draws itself at, which the engine has to know to leave room for it.
    ///
    /// A control with a size of its own is not measured like a string: the engine is told what the type
    /// is worth and sends a finished frame. A platform that draws it larger than that spills it out of
    /// the box it was given, so what each of them is worth is checked here rather than assumed.
    func testControlsAreWorthWhatTheEngineIsToldTheyAre() {
        for type in ["switch", "slider", "stepper", "segmented", "datepicker", "timepicker", "colorpicker"] {
            let answered = renderer.measureControl(type, variant: nil)

            XCTAssertGreaterThan(answered["height"] ?? 0, 0, "\(type) must be worth a height to the engine")
            XCTAssertEqual(renderer.measureControl(type, variant: nil)["width"], answered["width"],
                           "\(type) must be worth the same thing every time it is asked")
        }
    }

    /// A wheel and a compact date are two different controls to lay out, and asking about the type alone
    /// answers for whichever one the factory makes by default. Stretched to whatever width was going, a
    /// wheel is three columns of dates across a tablet and a screen that scrolls badly for it.
    func testAWheelIsWorthWhatAWheelIsWorth() {
        for type in ["datepicker", "timepicker"] {
            let wheel = renderer.measureControl(type, variant: "wheel")
            let compact = renderer.measureControl(type, variant: nil)

            XCTAssertGreaterThan(wheel["width"] ?? 0, 0, "a wheel is worth a width of its own")
            XCTAssertGreaterThan(wheel["height"] ?? 0, compact["height"] ?? 0,
                                 "and it is taller than the compact one, which is what a wheel is")
        }
    }

    func testWrapsWithinTheBoundItWasGiven() {
        let style: [String: Any] = ["fontSize": CGFloat(16)]
        let text = "A sentence long enough that it has to wrap onto a second line and then a third"
        let measured = renderer.measureText(text, style: style, bound: 200)

        let width = try! XCTUnwrap(measured["width"])
        let height = try! XCTUnwrap(measured["height"])

        XCTAssertLessThanOrEqual(width, 200, "a bounded measurement must fit the bound it was given")

        let label = UILabel()
        label.font = VarnStyle.font(from: style)
        label.text = text
        label.numberOfLines = 0

        let needed = label.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
        XCTAssertGreaterThanOrEqual(height, needed, "a wrapped measurement must carry every line it takes")
    }

    /// A control with no opinion about an axis says nothing about it, and fills the room it is given.
    ///
    /// Asking one to fit answers the smallest it can be drawn at, which is not an opinion: a slider
    /// answered 37 points across and was laid out as a thumb with no track beside it.
    func testAControlThatFillsItsRowMeasuresNothingAcross() {
        let slider = renderer.measureControl("slider", variant: nil)

        XCTAssertEqual(slider["width"], 0, "a slider fills the row it is in")
        XCTAssertGreaterThan(slider["height"] ?? 0, 0, "and stands as tall as the platform draws one")

        for name in ["segmented", "progress"] {
            XCTAssertEqual(renderer.measureControl(name, variant: nil)["width"], 0, "a \(name) fills its row")
        }
    }

    /// A control the platform sizes on both axes says so, or it would be stretched down a tablet.
    func testAControlSizedByThePlatformMeasuresBothWays() {
        for name in ["switch", "stepper", "activity", "datepicker"] {
            let size = renderer.measureControl(name, variant: nil)

            XCTAssertGreaterThan(size["width"] ?? 0, 0, "a \(name) is as wide as the platform draws one")
            XCTAssertGreaterThan(size["height"] ?? 0, 0, "and as tall")
        }
    }
}
