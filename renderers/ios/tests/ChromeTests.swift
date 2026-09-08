import XCTest
import UIKit
@testable import VarnGUIRenderer

/// What a scrolling surface draws around itself, and what a screen says about the system's own bars.
///
/// Both were found by holding a device. Every list drew a bar along an axis it does not scroll, because
/// one prop was applied to both of them, and the status bar kept the style of a screen that had already
/// gone, because the style was a global that nothing ever gave up.
/// A touch that can be moved, since a real one is only ever made by the system.
///
/// It answers where it is against the window and against a view separately, which is the difference a
/// control inside a list depends on: the finger stands still while the content slides beneath it.
private final class VarnTravellingTouch: UITouch {
    private var at: CGPoint

    init(from point: CGPoint) {
        at = point
        super.init()
    }

    func move(to point: CGPoint) {
        at = point
    }

    override func location(in view: UIView?) -> CGPoint {
        guard let view else {
            return at
        }

        return CGPoint(x: at.x - view.frame.origin.x, y: at.y - view.frame.origin.y)
    }
}

final class ChromeTests: XCTestCase {
    private var surface: UIView!
    private var renderer: VarnRenderer!

    override func setUp() {
        super.setUp()
        surface = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        renderer = VarnRenderer(surface: surface) { _, _, _ in }
    }

    private func build(_ id: Int, _ type: String, _ props: [String: Any]) throws -> UIView {
        try renderer.apply([
            ["op": "create", "id": id, "type": type, "props": props],
            ["op": "insert", "id": id, "parent": 0, "index": 1],
            ["op": "frame", "id": id, "x": 0, "y": 0, "width": 390, "height": 400],
        ])

        return try XCTUnwrap(surface.subviews.last)
    }

    /// A node given a state to come from starts in it, or there is nothing for the arrival to move from.
    func testANodeThatArrivesStartsWhereItWasToldTo() throws {
        let panel = try build(20, "view", [
            "style": ["background": "#ffffffff"],
            "enter": ["opacity": 0, "transform": ["translateY": "100%"]],
            "transition": ["duration": 250, "delay": 0, "easing": [0.4, 0, 0.2, 1]],
        ])

        XCTAssertEqual(panel.alpha, 0, "an arriving node starts at the opacity it was given")
        XCTAssertEqual(
            panel.transform.ty,
            400,
            "and travelled by the whole of its own height, which the frame has just settled"
        )
    }

    /// And it is moved to where it settles, which is what makes the arrival an arrival.
    func testANodeThatArrivesIsMovedToWhereItSettles() throws {
        let panel = try build(21, "view", [
            "style": ["background": "#ffffffff"],
            "enter": ["opacity": 0],
            "transition": ["duration": 60, "delay": 0, "easing": [0.4, 0, 0.2, 1]],
        ])

        let settled = expectation(description: "the arrival finishes")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { settled.fulfill() }
        wait(for: [settled], timeout: 2)

        XCTAssertEqual(panel.alpha, 1, "an arrival must end at the state the node settles in")
    }

    /// A chosen file is reported by name, size and type, with its bytes when it is worth reading whole.
    func testAChosenFileIsReportedWithItsBytes() throws {
        let picker = try XCTUnwrap(build(30, "filepicker", ["onPick": true]) as? VarnFilePicker)
        let entry = picker.entry(name: "note.txt", type: "text/plain", data: Data("hello".utf8))

        XCTAssertEqual(entry["name"] as? String, "note.txt", "a chosen file is named")
        XCTAssertEqual(entry["size"] as? Int, 5, "and measured")
        XCTAssertEqual(entry["type"] as? String, "text/plain", "and typed")
        XCTAssertEqual(
            entry["bytes"] as? String,
            Data("hello".utf8).base64EncodedString(),
            "and carries what is in it"
        )
    }

    /// One larger than the cap arrives named and measured but unread, rather than as a string no device
    /// should be asked to build.
    func testAFileOverTheCapArrivesUnread() throws {
        let picker = try XCTUnwrap(build(31, "filepicker", ["maxBytes": 4]) as? VarnFilePicker)
        let entry = picker.entry(name: "big.bin", type: "application/octet-stream", data: Data(count: 64))

        XCTAssertEqual(entry["size"] as? Int, 64, "it is still measured")
        XCTAssertTrue(entry["bytes"] is NSNull, "and it is not read")
    }

    func testAFileThatCannotBeReadIsStillReported() throws {
        let picker = try XCTUnwrap(build(32, "filepicker", [:]) as? VarnFilePicker)
        let entry = picker.entry(name: "gone.txt", type: "text/plain", data: nil)

        XCTAssertEqual(entry["name"] as? String, "gone.txt", "a file that would not open is still named")
        XCTAssertTrue(entry["bytes"] is NSNull, "and reported as unread")
    }

    /// A press is given up by the gesture that beat it, never by a distance.
    ///
    /// A finger on a phone is never still: holding a press to ten points of travel meant an ordinary
    /// tap was thrown away, and a reader pressed the same control three times to be heard once. UIKit
    /// answers a press wherever the finger is lifted inside the control, and what takes a press away is
    /// something else recognising the gesture — a scroll that starts, or a swipe the tree asked for.
    func testAPressSurvivesAFingerThatWobbles() throws {
        let row = try XCTUnwrap(build(40, "pressable", ["onPress": true]) as? VarnPressableView)
        let touch = VarnTravellingTouch(from: CGPoint(x: 10, y: 20))

        XCTAssertTrue(row.beginTracking(touch, with: nil), "a finger landing on it starts a press")

        touch.move(to: CGPoint(x: 60, y: 44))
        XCTAssertTrue(row.continueTracking(touch, with: nil), "and a finger that wandered is still a press")

        touch.move(to: CGPoint(x: 200, y: 22))
        XCTAssertTrue(row.continueTracking(touch, with: nil), "however far it went inside the control")
    }

    /// A box the tree asked for a swipe on gives the press up to the swipe, which the system arbitrates.
    func testASwipeTakesThePressFromTheBoxItRanAcross() throws {
        let row = try XCTUnwrap(build(41, "pressable", ["onPress": true, "onSwipe": true]))
        let swipes = (row.gestureRecognizers ?? []).compactMap { $0 as? UISwipeGestureRecognizer }

        XCTAssertEqual(swipes.count, 4, "a swipe is watched for in each direction")
        for direction in [UISwipeGestureRecognizer.Direction.left, .right, .up, .down] {
            XCTAssertTrue(swipes.contains { $0.direction == direction }, "including \(direction)")
        }

        XCTAssertTrue(swipes.allSatisfy(\.cancelsTouchesInView),
                      "and the one that recognises takes the touch away from the press")
    }

    /// A control moving under a still finger is not that finger travelling.
    ///
    /// A row inside a list slides while a scroll settles, so a press measured against the row itself is
    /// cancelled by the content rather than by the reader — which is a button that answers every other
    /// tap and ignores the one before it.
    func testAFingerThatStaysPutWhileTheBoxMovesKeepsThePress() throws {
        let row = try XCTUnwrap(build(42, "pressable", ["onPress": true]) as? VarnPressableView)
        let touch = VarnTravellingTouch(from: CGPoint(x: 40, y: 300))

        XCTAssertTrue(row.beginTracking(touch, with: nil), "a finger landing on it starts a press")

        row.frame = row.frame.offsetBy(dx: 0, dy: -120)

        XCTAssertTrue(
            row.continueTracking(touch, with: nil),
            "a finger that never moved is still a press however far the row went"
        )
    }

    /// A scrolling surface hands a touch straight to what is inside it.
    ///
    /// A scroll view holds one back to see whether it is a scroll, which delivers a quick press late and
    /// swallows a quicker one, and every list in the gallery is one of these.
    func testAScrollingSurfaceDoesNotHoldATouchBack() throws {
        let list = try XCTUnwrap(build(43, "list", [:]) as? VarnCollectionView)

        XCTAssertFalse(list.delaysContentTouches, "a press inside a list is delivered as it lands")
        XCTAssertTrue(list.canCancelContentTouches, "and taken back when a scroll actually starts")
    }

    func testAListDrawsABarOnlyForTheAxisItScrolls() throws {
        let list = try XCTUnwrap(
            build(1, "list", ["showsIndicator": true, "horizontal": false]) as? VarnCollectionView
        )

        XCTAssertTrue(list.showsVerticalScrollIndicator, "a vertical list draws its own bar")
        XCTAssertFalse(
            list.showsHorizontalScrollIndicator,
            "and none along an axis it never moves along"
        )
    }

    func testACarouselDrawsABarOnlyForTheAxisItScrolls() throws {
        let carousel = try XCTUnwrap(
            build(2, "carousel", ["showsIndicator": true, "horizontal": true]) as? VarnCollectionView
        )

        XCTAssertTrue(carousel.showsHorizontalScrollIndicator, "a paged surface runs along x")
        XCTAssertFalse(carousel.showsVerticalScrollIndicator, "and never down")
    }

    /// The axis and the indicator arrive in no order, so the pair has to be worked out again on either.
    func testTheAxisArrivingAfterTheIndicatorIsStillRead() throws {
        let list = try XCTUnwrap(
            build(3, "list", ["showsIndicator": true]) as? VarnCollectionView
        )

        try renderer.apply([["op": "update", "id": 3, "props": ["horizontal": true]]])

        XCTAssertTrue(list.showsHorizontalScrollIndicator, "the axis that landed last still decides")
        XCTAssertFalse(list.showsVerticalScrollIndicator, "and takes the other bar away")
    }

    func testASurfaceToldToHideItsBarHidesBoth() throws {
        let list = try XCTUnwrap(
            build(4, "list", ["showsIndicator": false, "horizontal": false]) as? VarnCollectionView
        )

        XCTAssertFalse(list.showsVerticalScrollIndicator, "a surface told to draw none draws none")
        XCTAssertFalse(list.showsHorizontalScrollIndicator, "along either axis")
    }

    /// A travel written as a percentage is a share of the node's own size, which is how a panel says it
    /// leaves by its own edge without the tree knowing how tall the layout made it.
    func testAPanelTravelsTheWholeOfItsOwnHeight() throws {
        let panel = try build(8, "view", [
            "style": ["transform": ["translateY": "100%"]],
        ])

        XCTAssertEqual(
            panel.transform.ty,
            400,
            "a share of the node must be read against the node, which is 400 tall"
        )
    }

    func testATravelWrittenAsANumberIsStillPoints() throws {
        let panel = try build(9, "view", [
            "style": ["transform": ["translateY": 40]],
        ])

        XCTAssertEqual(panel.transform.ty, 40, "a number must still be points")
    }

    func testAScreenThatNamesNothingLeavesTheBarsToTheSystem() throws {
        _ = try build(5, "safearea", [:])

        XCTAssertEqual(
            VarnSystemBars.style,
            .default,
            "a tree that names nothing must leave the system the style it reads from the appearance"
        )
    }

    func testAScreenThatNamesTheBarsIsFollowed() throws {
        _ = try build(6, "safearea", ["barContent": "light"])

        XCTAssertEqual(VarnSystemBars.style, .lightContent, "a screen that names one is followed")

        try renderer.apply([["op": "update", "id": 6, "props": ["barContent": "dark"]]])
        XCTAssertEqual(VarnSystemBars.style, .darkContent, "and followed again when it changes its mind")
    }

    /// A screen that has gone does not decide what is drawn over the one that replaced it.
    ///
    /// The request is given up when the view is released, and reading a view out of the hierarchy leaves
    /// it in the pool, so the pool is drained before asking what the bars are drawn in.
    func testAScreenThatLeavesGivesUpWhatItAskedFor() throws {
        try autoreleasepool {
            _ = try build(7, "safearea", ["barContent": "light"])
            XCTAssertEqual(VarnSystemBars.style, .lightContent, "the screen on screen is followed")

            try renderer.apply([["op": "remove", "id": 7]])
        }

        XCTAssertEqual(
            VarnSystemBars.style,
            .default,
            "and once it is gone the system chooses again"
        )
    }

    /// A pinned box is held against the leading edge by the surface, not by the tree.
    ///
    /// A commit follows a finger rather than leading it, so a header placed from the tree drifts across
    /// the rows it is meant to cover on every flick, and grows and shrinks with the offset it was last
    /// told about. The tree says the range and the surface says where inside it the box goes.
    func testAPinnedBoxIsHeldWhileTheSurfaceScrolls() throws {
        let list = try XCTUnwrap(build(60, "list", ["contentExtent": 4000]) as? VarnCollectionView)

        try renderer.apply([
            ["op": "create", "id": 61, "type": "view",
             "props": ["pinned": ["from": 0, "to": 1200]]],
            ["op": "insert", "id": 61, "parent": 60, "index": 1],
            ["op": "frame", "id": 61, "x": 0, "y": 0, "width": 390, "height": 30],
        ])

        let header = try XCTUnwrap(list.contentView.subviews.last as? VarnView)

        XCTAssertEqual(header.frame.origin.y, 0, "it starts where the tree put it")

        list.contentOffset = CGPoint(x: 0, y: 400)
        XCTAssertEqual(header.frame.origin.y, 400, "and follows the edge with no commit behind it")

        list.contentOffset = CGPoint(x: 0, y: 1190)
        XCTAssertEqual(header.frame.origin.y, 1170, "until its range runs out and the next one pushes it off")

        list.contentOffset = CGPoint(x: 0, y: 2000)
        XCTAssertEqual(header.frame.origin.y, 1170, "and it stays pushed off past the end of its range")
    }

    /// A finger that lands on a drawing inside a control presses the control.
    ///
    /// A plain view takes a touch on iOS whether or not it has any use for one, so the icon inside a tab
    /// swallowed every press aimed at it: the bar looked right and answered nothing, and a reader who
    /// happened to land beside the icon got through, which is a control that has to be pressed twice.
    func testAPressOnWhatIsDrawnInsideAControlReachesTheControl() throws {
        let tab = try XCTUnwrap(build(70, "pressable", ["onPress": true]) as? VarnPressableView)

        try renderer.apply([
            ["op": "create", "id": 71, "type": "canvas", "props": ["commands": []]],
            ["op": "insert", "id": 71, "parent": 70, "index": 1],
            ["op": "frame", "id": 71, "x": 20, "y": 20, "width": 40, "height": 40],
        ])

        let icon = try XCTUnwrap(tab.subviews.last)

        XCTAssertTrue(icon.isUserInteractionEnabled, "a drawing takes a touch the way any view does")
        XCTAssertTrue(tab.hitTest(CGPoint(x: 40, y: 40), with: nil) === tab,
                      "and the control it is drawn in is what answers the press")
    }

    /// What is inside a control and answers a finger of its own keeps it.
    func testAControlInsideAControlKeepsItsOwnFinger() throws {
        let row = try XCTUnwrap(build(72, "pressable", ["onPress": true]) as? VarnPressableView)

        try renderer.apply([
            ["op": "create", "id": 73, "type": "switch", "props": ["value": true]],
            ["op": "insert", "id": 73, "parent": 72, "index": 1],
            ["op": "frame", "id": 73, "x": 300, "y": 10, "width": 60, "height": 30],
        ])

        let toggle = try XCTUnwrap(row.subviews.last)

        let hit = row.hitTest(CGPoint(x: 320, y: 20), with: nil)

        XCTAssertTrue(hit === toggle || hit?.isDescendant(of: toggle) == true,
                      "a switch inside a row answers its own finger, got \(String(describing: hit))")
    }

    /// A child drawn past the edge of the box it belongs to still answers a finger.
    ///
    /// A view answers a touch only within its own bounds, so the raised picture on a tab bar was drawn
    /// half above the bar and nothing above the bar's own edge ever reached it: the control was seen and
    /// could not be pressed.
    func testAChildDrawnOutsideItsBoxIsStillPressed() throws {
        let bar = try XCTUnwrap(build(80, "view", [:]) as? VarnView)

        try renderer.apply([
            ["op": "frame", "id": 80, "x": 0, "y": 0, "width": 390, "height": 56],
            ["op": "create", "id": 81, "type": "pressable", "props": ["onPress": true]],
            ["op": "insert", "id": 81, "parent": 80, "index": 1],
            ["op": "frame", "id": 81, "x": 160, "y": -26, "width": 68, "height": 68],
        ])

        let raised = try XCTUnwrap(bar.subviews.last)

        XCTAssertEqual(raised.frame.minY, -26, "the picture is drawn above the bar it belongs to")
        XCTAssertTrue(bar.hitTest(CGPoint(x: 194, y: -10), with: nil) === raised,
                      "and a finger that lands on it there reaches it")
        XCTAssertNil(bar.hitTest(CGPoint(x: 20, y: -10), with: nil),
                     "while the rest of what is above the bar belongs to whatever is behind it")
    }

    /// A screen that was left is drawn going, which is a style applied over time rather than at once.
    ///
    /// The stack keeps the screen it uncovered for as long as the move takes and hands it the state to
    /// travel towards. What proves the move happened is that the view is still where it was when the
    /// batch lands, and somewhere else a moment later.
    func testAScreenGivenAnExitIsMovedRatherThanCut() throws {
        let screen = try XCTUnwrap(build(90, "view", ["style": ["opacity": 1]]))

        try renderer.apply([["op": "frame", "id": 90, "x": 0, "y": 0, "width": 390, "height": 400]])

        try renderer.apply([[
            "op": "update",
            "id": 90,
            "props": [
                "transition": ["duration": 300],
                "style": ["opacity": 0, "transform": ["translateX": 390]],
            ],
        ]])

        let keys = screen.layer.animationKeys() ?? []

        XCTAssertFalse(keys.isEmpty, "the screen is animated towards where it is going rather than put there")
        XCTAssertEqual(keys.compactMap { screen.layer.animation(forKey: $0)?.duration }.max() ?? 0, 0.3,
                       accuracy: 0.05, "over the time the tree asked for")

        let settled = expectation(description: "the move finishes")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { settled.fulfill() }
        wait(for: [settled], timeout: 2)

        XCTAssertEqual(screen.transform.tx, 390, accuracy: 1, "and it has travelled the whole way")
        XCTAssertEqual(screen.alpha, 0, accuracy: 0.05, "fading as it went")
    }
}
