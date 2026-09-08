import AVKit
import XCTest
import UIKit
@testable import VarnGUIRenderer

/// What a video actually puts on screen, which for a long time was an opaque black rectangle.
///
/// An `AVPlayerViewController` whose view is added without containment never receives the callbacks it
/// lays itself out from: it draws black over everything and shows no controls at all. Nothing about
/// that is visible from the tree, so it is asserted here instead.
final class VideoTests: XCTestCase {
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

    private func video(_ props: [String: Any]) throws -> VarnVideoView {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "video", "props": props],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "frame", "id": 1, "x": 0, "y": 0, "width": 390, "height": 200],
        ])

        window.layoutIfNeeded()
        return try XCTUnwrap(surface.subviews.first as? VarnVideoView)
    }

    func testAPlayerCarriesThePlatformsOwnControls() throws {
        let player = try video(["controls": true])

        XCTAssertNotNil(player.controller.parent,
                        "the controls must belong to the controller that owns the surface")
        XCTAssertFalse(player.controller.view.isHidden, "controls asked for must be on screen")
        XCTAssertTrue(player.subviews.contains(player.controller.view),
                      "the controls must be inside the video, not floating beside it")
    }

    func testControlsThatWereNotAskedForAreNotThere() throws {
        let player = try video(["controls": false])

        XCTAssertTrue(player.controller.view.isHidden, "controls nobody asked for are not drawn")
    }

    func testThePosterStandsOverThePlayerUntilThereIsAFrame() throws {
        let player = try video(["controls": true])

        // The poster is drawn over the video layer and under the controls, so a still is what is seen
        // and the play button is still reachable on top of it.
        let poster = try XCTUnwrap(player.subviews.first(where: { $0 is UIImageView }))
        let controls = player.controller.view!

        let posterAt = try XCTUnwrap(player.subviews.firstIndex(of: poster))
        let controlsAt = try XCTUnwrap(player.subviews.firstIndex(of: controls))

        XCTAssertLessThan(posterAt, controlsAt, "the controls must sit over the poster, not under it")
    }
}
