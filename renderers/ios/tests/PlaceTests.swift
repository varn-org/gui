import MapKit
import XCTest
import UIKit
@testable import VarnGUIRenderer

/// What the map is told and what it answers, which is the whole of the contract a tree writes against.
///
/// MapKit draws the map and answers the gestures over it, so what is worth testing is the translation
/// between a zoom, which is the number every raster map is cut in, and the region MapKit thinks in.
/// A map an ocean out at a zoom nobody asked for is what getting that wrong looks like.
final class PlaceTests: XCTestCase {
    private var surface: UIView!
    private var renderer: VarnRenderer!
    private var events: [(Int, String, Any?)] = []

    override func setUp() {
        super.setUp()

        surface = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        events = []
        renderer = VarnRenderer(surface: surface) { [weak self] id, name, payload in
            self?.events.append((id, name, payload))
        }
    }

    private func map(_ props: [String: Any]) throws -> VarnMapView {
        try renderer.apply([
            ["op": "create", "id": 1, "type": "map", "props": props],
            ["op": "insert", "id": 1, "parent": 0, "index": 1],
            ["op": "frame", "id": 1, "x": 0, "y": 0, "width": 300, "height": 300],
        ])

        let map = try XCTUnwrap(surface.subviews.last as? VarnMapView)

        // Nothing lays out a view that is in no window, and how much of the world fits depends on how
        // wide the map turned out to be.
        map.setNeedsLayout()
        map.layoutIfNeeded()

        return map
    }

    private var london: [String: Any] { ["latitude": 51.5074, "longitude": -0.1278] }

    /// A centre and a zoom put the map exactly where a browser and an Android view put it.
    func testAMapLooksWhereItWasTold() throws {
        let map = try map(["center": london, "zoom": 12.0, "interactive": true])
        let inner = try XCTUnwrap(map.subviews.first as? MKMapView)

        XCTAssertEqual(inner.region.center.latitude, 51.5074, accuracy: 0.01)
        XCTAssertEqual(inner.region.center.longitude, -0.1278, accuracy: 0.01)

        // 300 points at zoom 12 is 300 / 256 of a tile, and a tile at that zoom is 360 / 4096 across.
        XCTAssertEqual(inner.region.span.longitudeDelta, 360 / 4096 * 300 / 256, accuracy: 0.02)
    }

    /// A map told to look somewhere else looks there, rather than staying where the reader left it.
    func testAMapFollowsTheTreeThatDrawsIt() throws {
        let map = try map(["center": london, "zoom": 12.0, "interactive": true])
        let inner = try XCTUnwrap(map.subviews.first as? MKMapView)

        try renderer.apply([[
            "op": "update",
            "id": 1,
            "props": ["center": ["latitude": 35.6762, "longitude": 139.6503], "zoom": 8.0],
        ]])

        XCTAssertEqual(inner.region.center.latitude, 35.6762, accuracy: 0.05)
        XCTAssertEqual(inner.region.center.longitude, 139.6503, accuracy: 0.05)
        XCTAssertGreaterThan(inner.region.span.longitudeDelta, 360 / 4096 * 300 / 256)
    }

    /// Every mark the tree placed is on the map, carrying the name a press reports back.
    func testEveryMarkIsPlaced() throws {
        let map = try map([
            "center": london,
            "zoom": 12.0,
            "markers": [
                ["key": "home", "latitude": 51.5074, "longitude": -0.1278, "title": "Home"],
                ["key": "work", "latitude": 51.52, "longitude": -0.1],
            ],
        ])

        let inner = try XCTUnwrap(map.subviews.first as? MKMapView)
        let marks = inner.annotations.compactMap { $0 as? VarnMapMarker }

        XCTAssertEqual(marks.count, 2)
        XCTAssertEqual(Set(marks.map(\.key)), ["home", "work"])
        XCTAssertEqual(marks.first(where: { $0.key == "home" })?.title, "Home")

        try renderer.apply([["op": "update", "id": 1, "props": ["markers": []]]])
        XCTAssertTrue(inner.annotations.compactMap { $0 as? VarnMapMarker }.isEmpty)
    }

    /// A mark that was pressed reports which one it was, and is left ready to be pressed again.
    func testPressingAMarkReportsIt() throws {
        let map = try map([
            "center": london,
            "zoom": 12.0,
            "markers": [["key": "home", "latitude": 51.5074, "longitude": -0.1278]],
            "onMarkerPress": true,
        ])

        let inner = try XCTUnwrap(map.subviews.first as? MKMapView)
        let marker = try XCTUnwrap(inner.annotations.compactMap { $0 as? VarnMapMarker }.first)

        inner.selectAnnotation(marker, animated: false)

        let reported = events.filter { $0.1 == "onMarkerPress" }

        XCTAssertEqual(reported.count, 1)
        XCTAssertEqual((reported.first?.2 as? [String: Any])?["key"] as? String, "home")
        XCTAssertTrue(inner.selectedAnnotations.isEmpty)
    }

    /// A map told it may not be moved hands none of its gestures to the reader.
    func testAMapThatIsNotInteractiveIsNotMoved() throws {
        let map = try map(["center": london, "zoom": 12.0, "interactive": false])
        let inner = try XCTUnwrap(map.subviews.first as? MKMapView)

        XCTAssertFalse(inner.isScrollEnabled)
        XCTAssertFalse(inner.isZoomEnabled)
    }

    /// Asking where the device is takes no room at all, since a screen draws the answer itself.
    func testAskingWhereTheDeviceIsIsNotSeen() throws {
        try renderer.apply([
            ["op": "create", "id": 2, "type": "location", "props": ["watch": false, "accuracy": "fine"]],
            ["op": "insert", "id": 2, "parent": 0, "index": 1],
        ])

        let view = try XCTUnwrap(surface.subviews.last)

        XCTAssertTrue(view is VarnLocationView)
        XCTAssertTrue(view.isHidden)
    }

    /// What a node opened goes with the node, which on this platform means nothing holds it afterwards.
    ///
    /// A player that outlives its node is a sound still going after the screen it belonged to has gone,
    /// and a receiver that outlives one is a device still being asked where it is.
    func testWhatANodeOpenedGoesWithIt() throws {
        weak var sound: VarnAudioView?
        weak var fix: VarnLocationView?
        weak var map: VarnMapView?

        try autoreleasepool {
            try renderer.apply([
                ["op": "create", "id": 10, "type": "audio", "props": ["source": "loop.mp3"]],
                ["op": "insert", "id": 10, "parent": 0, "index": 1],
                ["op": "create", "id": 11, "type": "location", "props": ["watch": true]],
                ["op": "insert", "id": 11, "parent": 0, "index": 2],
                ["op": "create", "id": 12, "type": "map", "props": ["center": london, "zoom": 12.0]],
                ["op": "insert", "id": 12, "parent": 0, "index": 3],
            ])

            sound = surface.subviews.compactMap { $0 as? VarnAudioView }.first
            fix = surface.subviews.compactMap { $0 as? VarnLocationView }.first
            map = surface.subviews.compactMap { $0 as? VarnMapView }.first

            XCTAssertNotNil(sound)
            XCTAssertNotNil(fix)
            XCTAssertNotNil(map)

            try renderer.apply([
                ["op": "remove", "id": 10],
                ["op": "remove", "id": 11],
                ["op": "remove", "id": 12],
            ])
        }

        XCTAssertNil(sound, "the player goes with the node that carried it")
        XCTAssertNil(fix, "so does the receiver")
        XCTAssertNil(map, "and so does the map")
    }
}
