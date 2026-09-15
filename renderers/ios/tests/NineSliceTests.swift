import XCTest
import UIKit
@testable import VarnGUIRenderer

/// A picture cut into nine, which the platform draws from a layer told where the middle of it is.
///
/// None of this is visible from the tree: a frame with the wrong middle still has the right type, the
/// right props and the right size, and what is wrong with it is that the ornament on its corners has
/// been pulled out of shape. So the layer is what is read here.
final class NineSliceTests: XCTestCase {
    private var window: UIWindow!
    private var surface: UIView!
    private var renderer: VarnRenderer!

    override func setUp() {
        super.setUp()

        let controller = UIViewController()
        surface = controller.view!

        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false

        renderer = VarnRenderer(surface: surface) { _, _, _ in }
    }

    /// Writes a picture of a size out to a file, since a frame is cut in the pixels of a real one.
    private func drawn(_ size: CGSize) throws -> String {
        let renderer = UIGraphicsImageRenderer(size: size, format: {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return format
        }())

        let picture = renderer.image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let path = NSTemporaryDirectory() + "/frame-\(UUID().uuidString).png"
        try XCTUnwrap(picture.pngData()).write(to: URL(fileURLWithPath: path))

        return path
    }

    private func frame(_ props: [String: Any]) throws -> VarnNineSliceView {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "nineslice", "props": props],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "frame", "id": 1, "x": 0, "y": 0, "width": 300, "height": 120],
        ])

        window.layoutIfNeeded()
        return try XCTUnwrap(surface.subviews.first as? VarnNineSliceView)
    }

    /// The middle is the part of the picture between the cuts, as a share of the whole of it.
    func testTheMiddleIsWhatLiesBetweenTheCuts() throws {
        let picture = try drawn(CGSize(width: 100, height: 50))

        let view = try frame([
            "source": picture,
            "slice": ["top": 5, "right": 20, "bottom": 15, "left": 10],
            "sliceScale": 1,
        ])

        let middle = view.layer.contentsCenter

        XCTAssertEqual(middle.minX, 0.1, accuracy: 0.0001, "the middle starts where the left cut is")
        XCTAssertEqual(middle.minY, 0.1, accuracy: 0.0001, "and where the top cut is")
        XCTAssertEqual(middle.width, 0.7, accuracy: 0.0001, "and runs to the right cut")
        XCTAssertEqual(middle.height, 0.6, accuracy: 0.0001, "and down to the bottom cut")
    }

    /// A layer keeps the pieces outside its middle at one pixel per point it is scaled by, which is
    /// what decides how thick the border comes out.
    func testTheScaleSaysHowThickTheBorderIsDrawn() throws {
        let picture = try drawn(CGSize(width: 48, height: 48))

        let one = try frame(["source": picture, "slice": ["top": 14, "right": 14, "bottom": 14, "left": 14]])
        XCTAssertEqual(one.layer.contentsScale, 1, accuracy: 0.0001, "one point per pixel by default")

        try renderer.apply([["op": "update", "id": 1, "props": ["sliceScale": 2]]])
        XCTAssertEqual(one.layer.contentsScale, 0.5, accuracy: 0.0001, "and half of one when it is drawn twice as thick")
    }

    /// The pieces stretch, which they do not unless the layer is told to resize its contents.
    func testThePiecesStretchRatherThanSittingInTheMiddle() throws {
        let picture = try drawn(CGSize(width: 48, height: 48))
        let view = try frame(["source": picture, "slice": ["top": 14, "right": 14, "bottom": 14, "left": 14]])

        XCTAssertEqual(view.layer.contentsGravity, .resize, "a frame fills the box it was given")
        XCTAssertNotNil(view.layer.contents, "and it has the picture to fill it with")
    }

    /// A picture cut wider than itself has no middle left to stretch, so it is drawn whole instead.
    func testAPictureCutWiderThanItselfIsDrawnWhole() throws {
        let picture = try drawn(CGSize(width: 20, height: 20))
        let view = try frame(["source": picture, "slice": ["top": 30, "right": 30, "bottom": 30, "left": 30]])

        XCTAssertEqual(view.layer.contentsCenter, CGRect(x: 0, y: 0, width: 1, height: 1),
                       "the whole picture is the middle when there is nothing else left of it")
    }

    /// A frame holds what is written inside it, which is what makes the same thing a window.
    func testAFrameHoldsWhatIsInsideIt() throws {
        let picture = try drawn(CGSize(width: 48, height: 48))

        try renderer.apply([
            ["op": "create", "id": 1, "type": "nineslice",
             "props": ["source": picture, "slice": ["top": 14, "right": 14, "bottom": 14, "left": 14]]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "create", "id": 2, "type": "text", "props": ["text": "inside"]],
            ["op": "insert", "id": 2, "parent": 1, "index": 1],
        ])

        let view = try XCTUnwrap(surface.subviews.first as? VarnNineSliceView)
        XCTAssertEqual(view.subviews.count, 1, "what was written inside the frame is inside it")
    }

    /// The renderer says it draws one, so a screen can ask before it builds itself out of frames.
    func testTheRendererSaysItDrawsOne() {
        XCTAssertEqual(renderer.capabilities["nineSlice"], true)
    }
}
