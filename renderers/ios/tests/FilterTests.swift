import XCTest
import UIKit
@testable import VarnGUIRenderer

/// How a picture is drawn through the colour matrix a filter came to.
///
/// The engine sends the matrix rather than the amounts it was written from, so what a caller asked for is
/// worked out once and three platforms cannot each round their own way. A tint and a filter both rewrite
/// the picture they are given, and the props of one batch arrive in no order at all, so what is loaded,
/// what tints it and what filters it are kept apart rather than written over each other.
final class FilterTests: XCTestCase {
    private var surface: UIView!
    private var renderer: VarnRenderer!

    private let grey: [Double] = [
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
    ]

    override func setUp() {
        super.setUp()
        surface = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        renderer = VarnRenderer(surface: surface) { _, _, _ in }
    }

    /// A picture of one colour, which is what a filter's effect is read back off.
    private func painted(_ colour: UIColor) -> UIImage {
        let size = CGSize(width: 4, height: 4)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            colour.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// What one pixel of a picture is worth, read back as the three channels it was drawn in.
    private func pixel(of image: UIImage) throws -> (r: Int, g: Int, b: Int) {
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixel: [UInt8] = [0, 0, 0, 0]

        let space = CGColorSpaceCreateDeviceRGB()
        let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: space,
            bitmapInfo: bitmap
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (r: Int(pixel[0]), g: Int(pixel[1]), b: Int(pixel[2]))
    }

    func testAMatrixDrawsThePictureItWasGivenThroughIt() throws {
        let filtered = try XCTUnwrap(VarnFilter.apply(grey, to: painted(.red)))
        let read = try pixel(of: filtered)

        XCTAssertEqual(read.r, read.g, accuracy: 2, "grey is the same on every channel")
        XCTAssertEqual(read.g, read.b, accuracy: 2, "on all three of them")
        XCTAssertEqual(read.r, 54, accuracy: 3, "and red is the share of brightness the eye reads it as")
    }

    func testAPictureWithNoFilterIsTheOneItWasGiven() {
        let source = painted(.red)

        XCTAssertTrue(VarnFilter.apply(nil, to: source) === source, "a picture with no filter is untouched")
    }

    func testACameraCarriesWhatItWasToldAndReportsThroughOneClosure() throws {
        var reported: [(String, Any)] = []

        let surface = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let renderer = VarnRenderer(surface: surface) { _, name, payload in
            reported.append((name, payload))
        }

        try renderer.apply([
            [
                "op": "create", "id": 1, "type": "camera",
                "props": ["facing": "front", "zoom": 2.0, "torch": true, "audio": true, "filter": grey,
                          "onCapture": true, "onError": true],
            ],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
        ])

        let camera = try XCTUnwrap(surface.subviews.first as? VarnCameraView)

        XCTAssertEqual(camera.facing, "front", "which way it is looking is what it was told")
        XCTAssertEqual(camera.zoom, 2, "and so is how far in it is")
        XCTAssertTrue(camera.torch, "and whether the light is on")
        XCTAssertEqual(camera.filter, grey, "and the look it is drawn through")

        // Everything a camera produces travels under the name it produced it as, since one closure
        // carries all four rather than a reporter being bound per event.
        camera.onEvent?("onCapture", ["path": "/somewhere/photo.jpg"])

        XCTAssertEqual(reported.first?.0, "onCapture", "what it produced is reported under its own name")
    }

    func testAFilmIsDrawnThroughTheSameMatrixAPictureIs() throws {
        let surface = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let renderer = VarnRenderer(surface: surface) { _, _, _ in }

        try renderer.apply([
            ["op": "create", "id": 1, "type": "video", "props": ["source": "clip.mp4", "filter": grey]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
        ])

        let film = try XCTUnwrap(surface.subviews.first as? VarnVideoView)

        XCTAssertEqual(film.filter, grey, "a film carries the matrix it was sent")
    }

    func testACameraIsTheOnlyThingThatCanBeAskedToCapture() throws {
        let surface = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let renderer = VarnRenderer(surface: surface) { _, _, _ in }

        try renderer.apply([
            ["op": "create", "id": 1, "type": "view", "props": [:]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
        ])

        XCTAssertThrowsError(try renderer.invoke(id: 1, method: "capturePhoto", arguments: [:]),
                             "asking a box for a picture is a caller's mistake rather than silence")
    }

    func testATintAndAFilterDoNotWriteOverEachOther() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "image", "props": ["filter": grey, "tint": "#ff0000ff"]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
        ])

        let picture = try XCTUnwrap(surface.subviews.first as? VarnPictureView)

        // A tint replaces the colours of a picture outright, so it is what a picture carrying both is
        // drawn in whichever order the props of a batch happened to arrive in.
        XCTAssertEqual(picture.tintColor, UIColor(red: 1, green: 0, blue: 0, alpha: 1), "the tint is the one it was given")
        XCTAssertEqual(picture.filter, grey, "and the filter is still there rather than written over")

        try renderer.apply([["op": "update", "id": 1, "props": ["tint": "__varn_removed__"]]])

        XCTAssertNil(picture.tint, "a tint taken away is gone")
        XCTAssertEqual(picture.filter, grey, "and the filter it was hiding is what draws the picture now")
    }
}
