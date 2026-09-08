import MapKit
import UIKit

/// A point the tree put on the map, carrying the name a press reports back.
final class VarnMapMarker: NSObject, MKAnnotation {
    let key: String
    let coordinate: CLLocationCoordinate2D
    let title: String?

    init(key: String, coordinate: CLLocationCoordinate2D, title: String?) {
        self.key = key
        self.coordinate = coordinate
        self.title = title
    }
}

/// The map the platform draws, looking where the tree told it to look.
///
/// MapKit owns the gestures over it and the tiles under it. Where it is looking and what is marked on
/// it are the tree's, so a drag reports the region it ended at and nothing moves the map but a prop.
final class VarnMapView: UIView, MKMapViewDelegate, UIGestureRecognizerDelegate, VarnSettling {
    private let map = MKMapView()

    private var looking = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    private var zoom = 14.0
    private var markers: [VarnMapMarker] = []
    private var placed = ""

    private let drags = UIPanGestureRecognizer()
    private let pinches = UIPinchGestureRecognizer()
    private var dragging = false

    var onRegionChange: (([String: Any]) -> Void)?
    var onMarkerPress: (([String: Any]) -> Void)?
    var onPress: (([String: Any]) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        map.delegate = self
        map.showsCompass = false
        addSubview(map)

        let tap = UITapGestureRecognizer(target: self, action: #selector(pressed(_:)))
        tap.delegate = self
        map.addGestureRecognizer(tap)

        // MapKit reports the region changing without saying what changed it, and a map re-fitting itself
        // to a new size changes it too. Watching the gestures alongside its own is what tells a reader
        // moving the map from the map answering a resize, and only the first of those is worth reporting.
        for recognizer in [drags, pinches] as [UIGestureRecognizer] {
            recognizer.addTarget(self, action: #selector(dragged(_:)))
            recognizer.delegate = self
            map.addGestureRecognizer(recognizer)
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()

        let changed = map.frame != bounds
        map.frame = bounds

        // How much of the world fits depends on how wide the map turned out to be, so a map that has
        // just been given its size is looking at the wrong region until it is told again.
        if changed {
            look()
        }
    }

    func setCenter(_ value: [String: Any]?) {
        guard let value,
              let latitude = VarnValue.number(value["latitude"]),
              let longitude = VarnValue.number(value["longitude"]) else {
            return
        }

        looking = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func setZoom(_ value: Double) {
        zoom = min(20, max(1, value))
    }

    func setMarkers(_ value: [[String: Any]]) {
        markers = value.compactMap { entry in
            guard let key = entry["key"] as? String,
                  let latitude = VarnValue.number(entry["latitude"]),
                  let longitude = VarnValue.number(entry["longitude"]) else {
                return nil
            }

            return VarnMapMarker(
                key: key,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                title: entry["title"] as? String
            )
        }
    }

    func setInteractive(_ value: Bool) {
        map.isScrollEnabled = value
        map.isZoomEnabled = value
        map.isRotateEnabled = value
        map.isPitchEnabled = value
    }

    func settle() {
        // MapKit keeps the region it is given against its own bounds, and a region set while a size
        // change is still pending is worked out against the size the map is leaving rather than the one
        // it is taking, so it is laid out before it is told where to look.
        map.frame = bounds
        map.layoutIfNeeded()

        look()
        mark()
    }

    /// Points the map where the props say, unless it is already close enough that moving it would fight
    /// with the reader's own drag.
    private func look() {
        guard bounds.width > 0 else {
            return
        }

        let wanted = region()
        let apart = abs(map.region.center.latitude - wanted.center.latitude)
            + abs(map.region.center.longitude - wanted.center.longitude)
        let scaled = abs(map.region.span.longitudeDelta - wanted.span.longitudeDelta)

        guard apart > wanted.span.longitudeDelta / 100 || scaled > wanted.span.longitudeDelta / 100 else {
            return
        }

        map.setRegion(wanted, animated: false)
    }

    private func region() -> MKCoordinateRegion {
        // A degree of longitude covers less ground the further from the equator it is, so a square view
        // spans fewer degrees of latitude than of longitude. MapKit works in degrees and widens what it
        // is given rather than refusing it, which is a map at a zoom nobody asked for.
        let across = 360 / pow(2, zoom) * Double(bounds.width) / 256
        let down = across * Double(bounds.height) / Double(bounds.width)
            * cos(looking.latitude * .pi / 180)

        return MKCoordinateRegion(
            center: looking,
            span: MKCoordinateSpan(latitudeDelta: min(180, down), longitudeDelta: min(360, across))
        )
    }

    /// Answers the zoom a region stands at, which is the same number every raster map is cut in.
    private func zoom(of region: MKCoordinateRegion) -> Double {
        guard bounds.width > 0, region.span.longitudeDelta > 0 else {
            return zoom
        }

        return log2(360 * Double(bounds.width) / 256 / region.span.longitudeDelta)
    }

    private func mark() {
        let wanted = markers
            .map { "\($0.key)@\($0.coordinate.latitude),\($0.coordinate.longitude):\($0.title ?? "")" }
            .joined(separator: "|")

        guard wanted != placed else {
            return
        }

        placed = wanted
        map.removeAnnotations(map.annotations)
        map.addAnnotations(markers)
    }

    func mapView(_ view: MKMapView, regionDidChangeAnimated animated: Bool) {
        guard dragging else {
            return
        }

        // A flick carries on after the finger has gone, so the drag is over once neither gesture is
        // still running and the region it left the map at has arrived.
        dragging = drags.state == .began || drags.state == .changed
            || pinches.state == .began || pinches.state == .changed

        looking = view.region.center
        zoom = zoom(of: view.region)

        onRegionChange?([
            "center": ["latitude": looking.latitude, "longitude": looking.longitude],
            "zoom": zoom,
        ])
    }

    func mapView(_ view: MKMapView, didSelect annotation: MKAnnotationView) {
        guard let marker = annotation.annotation as? VarnMapMarker else {
            return
        }

        onMarkerPress?(["key": marker.key])
        view.deselectAnnotation(marker, animated: false)
    }

    // A press on a mark is a press on that mark, so the map is not told about it as well.
    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view

        while view != nil {
            if view is MKAnnotationView {
                return false
            }

            view = view?.superview
        }

        return true
    }

    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    @objc private func dragged(_ recognizer: UIGestureRecognizer) {
        if recognizer.state == .began {
            dragging = true
        }
    }

    @objc private func pressed(_ recognizer: UITapGestureRecognizer) {
        let at = map.convert(recognizer.location(in: map), toCoordinateFrom: map)

        onPress?(["latitude": at.latitude, "longitude": at.longitude])
    }
}
