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

    /// A film says when it can be played and where it has got to, which a sound already did.
    ///
    /// Both are declared on `Video` and neither existed here, so a tree drawing its own scrubber over a
    /// film had nothing to follow: the two events were promised by the reference page and answered by
    /// nobody on this platform.
    func testAFilmReportsWhenItIsReadyAndWhereItHasGot() throws {
        let player = try video(["source": "https://varn-storage.s3.us-east-1.amazonaws.com/stuff/big-buck-bunny-1080p-30sec.mp4"])
        let ready = expectation(description: "the film says it can be played")
        let moved = expectation(description: "the film says where it has got to")

        moved.assertForOverFulfill = false

        player.onReady = { about in
            XCTAssertGreaterThan(about["duration"] as? Double ?? 0, 0, "it carries how long it runs for")
            ready.fulfill()
        }

        player.onProgress = { _ in moved.fulfill() }
        player.player.play()

        wait(for: [ready, moved], timeout: 30)
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

    /// A page shown by a tree that said no to scripts does not get to run them.
    ///
    /// A `WKWebView` answers a copy of the configuration it was built with, so a preference written on
    /// it afterwards changes nothing: the flag has to reach the navigation, which is where the decision
    /// is actually taken.
    func testAWebViewIsToldWhetherThePageMayRunScripts() throws {
        try renderer.apply([
            ["op": "create", "id": 2, "type": "webview", "props": ["javaScriptEnabled": false]],
            ["op": "insert", "id": 2, "parent": 0, "index": 1],
        ])

        let quiet = try XCTUnwrap(surface.subviews.last as? VarnWebView)
        XCTAssertFalse(quiet.scripting, "a tree that said no to scripts is answered")
        XCTAssertTrue(quiet.navigationDelegate === quiet, "and the view is what takes the decision")

        try renderer.apply([
            ["op": "create", "id": 3, "type": "webview", "props": [:]],
            ["op": "insert", "id": 3, "parent": 0, "index": 2],
        ])

        let ordinary = try XCTUnwrap(surface.subviews.last as? VarnWebView)
        XCTAssertTrue(ordinary.scripting, "a page runs its scripts unless the tree says otherwise")
    }

    /// A video is told it has ended when it has ended, rather than when any player anywhere has.
    ///
    /// The notice a player raises at the end carries the item that reached it, and one observed with no
    /// object at all is every item in the process: a screen holding a video and a sound tells both of
    /// them that one of them finished, so a looping video starts again because a sound ran out.
    func testAVideoIsNotToldThatSomethingElseEnded() throws {
        let film = try video(["source": "https://example.test/film.mp4", "onEnd": true])

        var told = 0
        film.onEnd = { told += 1 }

        NotificationCenter.default.post(
            name: .AVPlayerItemDidPlayToEndTime,
            object: AVPlayerItem(url: URL(string: "https://example.test/something-else.mp3")!)
        )

        XCTAssertEqual(told, 0, "a video must not be told that a different player ended")

        NotificationCenter.default.post(
            name: .AVPlayerItemDidPlayToEndTime,
            object: film.player.currentItem
        )

        XCTAssertEqual(told, 1, "and it must be told when its own did")
    }
}
