import SwiftUI
import GoogleMaps
import MapKit

struct MapPin: Identifiable {
    var place: PlaceReference
    var number: Int?
    var candidate = false
    var id: String { place.id }
}
struct TripMap: View {
    let planner: TripPlanner
    var bottomPadding: CGFloat
    var body: some View {
        if planner.isDemo {
            GeometryReader { geometry in
                AppleTripMap(route: planner.route, pins: pins) { id in
                    if let place = pins.first(where: { $0.id == id })?.place { planner.sheet = .details(place) }
                }
                // Keep Apple's attribution and map controls above the planning panel.
                .frame(height: max(200, geometry.size.height - bottomPadding))
                .frame(maxHeight: .infinity, alignment: .top)
                .background(DetourTheme.muted)
            }
        } else {
            GoogleTripMap(route: planner.route, pins: pins, bottomPadding: bottomPadding) { id in
                if let place = pins.first(where: { $0.id == id })?.place { planner.sheet = .details(place) }
            }
        }
    }
    private var pins: [MapPin] {
        var values: [MapPin] = []
        if let origin = planner.trip.origin { values.append(MapPin(place: origin)) }
        if let destination = planner.trip.destination { values.append(MapPin(place: destination)) }
        values += planner.trip.stops.enumerated().map { MapPin(place: $0.element.place, number: $0.offset + 1) }
        if planner.stage == .finding { values += planner.found.map { MapPin(place: $0.place, candidate: true) } }
        else if planner.stage == .suggestions, let current = planner.current { values.append(MapPin(place: current.place, candidate: true)) }
        return values
    }
}
struct GoogleTripMap: UIViewRepresentable {
    let route: RoutePlan?
    let pins: [MapPin]
    var bottomPadding: CGFloat
    var select: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(select: select) }
    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition(latitude: -33.9, longitude: 20.5, zoom: 6)
        let map = GMSMapView(options: options)
        map.delegate = context.coordinator
        map.isMyLocationEnabled = false
        map.settings.compassButton = false
        map.settings.rotateGestures = false
        map.settings.tiltGestures = false
        map.mapStyle = try? GMSMapStyle(jsonString: """
        [{"featureType":"poi","stylers":[{"visibility":"off"}]},{"featureType":"transit","stylers":[{"visibility":"off"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#d8e7ec"}]},{"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f2f4f2"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]}]
        """)
        return map
    }
    func updateUIView(_ map: GMSMapView, context: Context) {
        context.coordinator.select = select
        let padding = UIEdgeInsets(top: 115, left: 34, bottom: bottomPadding + 20, right: 34)
        if map.padding != padding { map.padding = padding }
        let signature = (route?.encodedPolyline ?? "") + pins.map { "\($0.id):\($0.number ?? 0):\($0.candidate)" }.joined()
        guard context.coordinator.signature != signature else { return }
        context.coordinator.signature = signature
        map.clear()
        var bounds = GMSCoordinateBounds()
        if let encoded = route?.encodedPolyline, let path = GMSPath(fromEncodedPath: encoded) {
            let stroke = GMSPolyline(path: path)
            stroke.strokeColor = UIColor(DetourTheme.ink); stroke.strokeWidth = 4; stroke.map = map
            for index in 0..<path.count() { bounds = bounds.includingCoordinate(path.coordinate(at: index)) }
        }
        for pin in pins {
            let coordinate = CLLocationCoordinate2D(latitude: pin.place.coordinate.latitude, longitude: pin.place.coordinate.longitude)
            let marker = GMSMarker(position: coordinate)
            marker.title = pin.place.name; marker.userData = pin.id
            if let number = pin.number {
                let label = UILabel(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
                label.text = String(number); label.textAlignment = .center
                label.font = .systemFont(ofSize: 14, weight: .semibold); label.textColor = .white
                label.backgroundColor = UIColor(DetourTheme.ink); label.layer.cornerRadius = 14; label.clipsToBounds = true
                label.layer.borderWidth = 2; label.layer.borderColor = UIColor.white.cgColor
                marker.iconView = label
            } else { marker.icon = GMSMarker.markerImage(with: UIColor(pin.candidate ? DetourTheme.orange : DetourTheme.ink)) }
            marker.map = map
            bounds = bounds.includingCoordinate(coordinate)
        }
        if !pins.isEmpty { map.moveCamera(GMSCameraUpdate.fit(bounds, withPadding: 20)) }
    }
    final class Coordinator: NSObject, GMSMapViewDelegate {
        var signature = ""
        var select: (String) -> Void
        init(select: @escaping (String) -> Void) { self.select = select }
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let id = marker.userData as? String { select(id) }
            return true
        }
    }
}

// Native Apple Maps keeps development usable before Google credentials are set.
struct AppleTripMap: UIViewRepresentable {
    let route: RoutePlan?
    let pins: [MapPin]
    var select: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(select: select) }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = configuration
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.showsScale = true
        map.accessibilityIdentifier = "trip-map"
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -33.9, longitude: 20.7),
                                        span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 6)), animated: false)
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.select = select
        let signature = (route?.encodedPolyline ?? "") + pins.map {
            "\($0.id):\($0.place.coordinate.latitude):\($0.place.coordinate.longitude):\($0.number ?? 0):\($0.candidate)"
        }.joined()
        guard context.coordinator.signature != signature else { return }
        context.coordinator.signature = signature
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)
        var bounds = MKMapRect.null
        let coordinates = RouteGeometry.decode(route?.encodedPolyline ?? "").map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        if coordinates.count > 1 {
            let line = MKPolyline(coordinates: coordinates, count: coordinates.count)
            map.addOverlay(line, level: .aboveRoads)
            bounds = line.boundingMapRect
        }
        for pin in pins {
            let annotation = PlaceAnnotation(pin: pin)
            map.addAnnotation(annotation)
            let point = MKMapPoint(annotation.coordinate)
            bounds = bounds.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        if !bounds.isNull {
            map.setVisibleMapRect(bounds, edgePadding: UIEdgeInsets(top: 125, left: 42, bottom: 40, right: 42), animated: false)
        }
    }
    final class PlaceAnnotation: NSObject, MKAnnotation {
        let pin: MapPin
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: pin.place.coordinate.latitude, longitude: pin.place.coordinate.longitude)
        }
        var title: String? { pin.place.name }
        init(pin: MapPin) { self.pin = pin }
    }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var signature = ""
        var select: (String) -> Void
        init(select: @escaping (String) -> Void) { self.select = select }
        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: line)
            renderer.strokeColor = UIColor(DetourTheme.ink)
            renderer.lineWidth = 4
            renderer.lineCap = .round
            return renderer
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? PlaceAnnotation else { return nil }
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "place") as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "place")
            view.annotation = annotation
            view.markerTintColor = UIColor(annotation.pin.candidate ? DetourTheme.orange : DetourTheme.ink)
            view.glyphText = annotation.pin.number.map(String.init)
            view.glyphImage = annotation.pin.number == nil ? UIImage(systemName: "mappin") : nil
            view.displayPriority = .required
            view.titleVisibility = .adaptive
            view.accessibilityLabel = annotation.pin.number.map { "Stop \($0), \(annotation.pin.place.name)" } ?? annotation.pin.place.name
            return view
        }
        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            guard let annotation = annotation as? PlaceAnnotation else { return }
            select(annotation.pin.id)
            mapView.deselectAnnotation(annotation, animated: false)
        }
    }
}
