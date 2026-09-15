import AVFoundation
import XCTest
import UIKit
@testable import VarnGUIRenderer

/// Whether a sound the tree asked for is actually running.
///
/// Nothing about the player a reader sees is the platform's — the button, the clock and the scrubber are
/// all drawn by the tree — so the only thing that says the sound is running is the player itself. A tree
/// case cannot see it, and pressing play and hearing nothing is what a reader gets when it is not.
final class SoundTests: XCTestCase {
    private var surface: UIView!
    private var renderer: VarnRenderer!

    private static let address = "https://varn-storage.s3.us-east-1.amazonaws.com/stuff/audio-loop-africa.mp3"

    override func setUp() {
        super.setUp()

        surface = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        renderer = VarnRenderer(surface: surface) { _, _, _ in }
    }

    private func sound(_ props: [String: Any]) throws -> VarnAudioView {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "audio", "props": props],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "frame", "id": 1, "x": 0, "y": 0, "width": 0, "height": 0],
        ])

        return try XCTUnwrap(surface.subviews.first as? VarnAudioView)
    }

    /// A sound given an address opens it, which is what an application plays from rather than a file.
    func testASoundOverTheNetworkIsOpened() throws {
        let player = try sound(["source": SoundTests.address])
        let opened = expectation(description: "the item is ready to play")

        wait(for: player, until: opened) { $0.currentItem?.status != .unknown }
        wait(for: [opened], timeout: 30)

        let item = player.player.currentItem

        XCTAssertEqual(item?.status, .readyToPlay,
                       "the sound opened, it said \(String(describing: item?.error))")
    }

    /// Told to play it plays, which is the one thing the tree cannot see for itself.
    func testTellingASoundToPlayStartsIt() throws {
        let player = try sound(["source": SoundTests.address])
        let running = expectation(description: "the sound is running")

        try renderer.apply([["op": "update", "id": 1, "props": ["playing": true]]])
        wait(for: player, until: running) { $0.rate > 0 && $0.currentTime().seconds > 0 }
        wait(for: [running], timeout: 30)
    }

    /// Seeking is asked for rather than described, which is what lets a reader drag twice to one moment.
    ///
    /// A prop is sent only when it differs from the last one, and a moment a reader has already been at
    /// does not, so a scrubber dragged back to it would be answered by nothing.
    func testSeekingMovesTheSoundAndAskingTwiceMovesItTwice() throws {
        let player = try sound(["source": SoundTests.address])
        let opened = expectation(description: "the item is ready to play")

        wait(for: player, until: opened) { $0.currentItem?.status == .readyToPlay }
        wait(for: [opened], timeout: 30)

        let arrived = expectation(description: "the sound moved")

        _ = try renderer.invoke(id: 1, method: "seek", arguments: ["seconds": 12])
        wait(for: player, until: arrived) { abs($0.currentTime().seconds - 12) < 0.5 }
        wait(for: [arrived], timeout: 30)

        // Asking for a moment the sound is already at is still an ask, since a reader dragged for it.
        let again = expectation(description: "the sound moved again")

        _ = try renderer.invoke(id: 1, method: "seek", arguments: ["seconds": 4])
        wait(for: player, until: again) { abs($0.currentTime().seconds - 4) < 0.5 }
        wait(for: [again], timeout: 30)
    }

    /// A sound is told it has ended when it has ended, rather than when any sound anywhere has.
    ///
    /// The notice a player raises at the end carries the item that reached it, and one observed with no
    /// object at all is every item in the process: a screen holding two sounds tells both of them that
    /// one of them finished, so a looping sound starts again because something unrelated ran out.
    func testASoundIsNotToldThatAnotherSoundEnded() throws {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "audio", "props": ["source": SoundTests.address]],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "create", "id": 2, "type": "audio", "props": ["source": SoundTests.address, "onEnd": true]],
            ["op": "insert", "id": 2, "parent": 0, "index": 2],
        ])

        let sounds = surface.subviews.compactMap { $0 as? VarnAudioView }

        XCTAssertEqual(sounds.count, 2, "the screen holds two sounds")

        var told = 0
        sounds[1].onEnd = { told += 1 }

        NotificationCenter.default.post(
            name: .AVPlayerItemDidPlayToEndTime,
            object: sounds[0].player.currentItem
        )

        XCTAssertEqual(told, 0, "a sound must not be told that a different sound ended")

        NotificationCenter.default.post(
            name: .AVPlayerItemDidPlayToEndTime,
            object: sounds[1].player.currentItem
        )

        XCTAssertEqual(told, 1, "and it must be told when its own did")
    }

    /// An action asked of a node that cannot perform it is refused by name on every platform.
    func testSeekingSomethingThatIsNotASoundIsRefused() throws {
        try renderer.apply([
            ["op": "create", "id": 2, "type": "text", "props": ["text": "nothing to play"]],
            ["op": "insert", "id": 2, "parent": 0, "index": 1],
        ])

        XCTAssertThrowsError(try renderer.invoke(id: 2, method: "seek", arguments: ["seconds": 1]))
    }

    private func wait(
        for view: VarnAudioView,
        until met: XCTestExpectation,
        _ answered: @escaping (AVPlayer) -> Bool
    ) {
        var timer: Timer?

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            guard answered(view.player) else {
                return
            }

            timer?.invalidate()
            met.fulfill()
        }
    }
}
