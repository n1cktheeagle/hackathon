import SwiftUI
import GoogleMaps
import MapKit

struct MapPin: Identifiable {
    var place: PlaceReference
    var number: Int?
    var candidate = false
    var id: String { place.id }
}

// The same native map stays mounted from choosing a destination through the itinerary.
struct TripMap: View {
    let planner: TripPlanner
    var padding: UIEdgeInsets
    var usesGoogleMaps = false
    var showsUserLocation = false
    var cameraRevision = 0
    var body: some View {
        if usesGoogleMaps {
            GoogleTripMap(route: planner.directRoute ?? planner.route, strokes: strokes, pins: pins, padding: padding, home: planner.stage == .home,
                          center: center, showsUserLocation: showsUserLocation, cameraRevision: cameraRevision, select: select)
        } else {
            AppleTripMap(route: planner.directRoute ?? planner.route, strokes: strokes, pins: pins, padding: padding, home: planner.stage == .home,
                         center: center, showsUserLocation: showsUserLocation, cameraRevision: cameraRevision, select: select)
        }
    }
    private var center: Coordinate { planner.trip.origin?.coordinate ?? Fixtures.capeTown.coordinate }
    private var strokes: [RouteStroke] {
        guard planner.stage != .home else { return [] }
        guard let route = planner.directRoute ?? planner.route else { return [] }
        let preview = planner.stage == .suggestions ? planner.current?.detourBranches ?? [] : []
        return RouteGeometry.replacingDetours(RouteGeometry.decode(route.encodedPolyline), accepted: planner.detourBranches, preview: preview)
    }
    private func select(_ id: String) {
        if let place = pins.first(where: { $0.id == id })?.place { planner.sheet = .details(place) }
    }
    private var pins: [MapPin] {
        if planner.stage == .home {
            return planner.nearby.map { MapPin(place: $0) } +
                [planner.trip.origin, planner.trip.destination].compactMap { $0 }.filter { $0.id != "current-location" }.map { MapPin(place: $0) }
        }
        var values = [planner.trip.origin, planner.trip.destination].compactMap { $0 }.map { MapPin(place: $0) }
        values += planner.trip.stops.enumerated().map { MapPin(place: $0.element.place, number: $0.offset + 1) }
        if planner.stage == .suggestions, let current = planner.current { values.append(MapPin(place: current.place, candidate: true)) }
        return values
    }
}

struct GoogleTripMap: UIViewRepresentable {
    let route: RoutePlan?
    var strokes: [RouteStroke] = []
    let pins: [MapPin]
    var padding: UIEdgeInsets
    var home: Bool
    var center: Coordinate
    var showsUserLocation: Bool
    var cameraRevision: Int
    var select: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(select: select) }
    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition(latitude: center.latitude, longitude: center.longitude, zoom: 14)
        let map = GMSMapView(options: options)
        map.delegate = context.coordinator
        map.settings.compassButton = false; map.settings.rotateGestures = false; map.settings.tiltGestures = false
        map.mapStyle = try? GMSMapStyle(jsonString: """
        [{"featureType":"poi","stylers":[{"visibility":"off"}]},{"featureType":"transit","stylers":[{"visibility":"off"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#d8e7ec"}]},{"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f2f4f2"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]}]
        """)
        return map
    }
    func updateUIView(_ map: GMSMapView, context: Context) {
        let c = context.coordinator
        c.select = select
        let candidateID = pins.first(where: \.candidate)?.id
        let candidateChanged = c.candidateID != candidateID
        let paddingChanged = map.padding != padding
        map.padding = padding; map.isMyLocationEnabled = showsUserLocation
        let signature = pins.map { "\($0.id):\($0.number ?? 0):\($0.candidate)" }.joined()
        if c.signature != signature {
            c.signature = signature
            c.markers.forEach { $0.map = nil }; c.markers = []
            for pin in pins {
                let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: pin.place.coordinate.latitude, longitude: pin.place.coordinate.longitude))
                marker.title = pin.place.name; marker.userData = pin.id
                marker.icon = GMSMarker.markerImage(with: UIColor(pin.candidate ? DetourTheme.orange : DetourTheme.ink))
                if let number = pin.number {
                    let label = UILabel(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
                    label.text = String(number); label.textAlignment = .center; label.font = .systemFont(ofSize: 14, weight: .semibold)
                    label.textColor = .white; label.backgroundColor = UIColor(DetourTheme.ink)
                    label.layer.cornerRadius = 14; label.clipsToBounds = true; marker.iconView = label
                }
                marker.map = map; c.markers.append(marker)
            }
        }
        let routeChanged = c.encoded != route?.encodedPolyline
        c.encoded = route?.encodedPolyline
        let branchSignature = strokes.map { "\($0.detour):\($0.preview):\(RouteGeometry.encode($0.coordinates))" }.joined()
        let branchesChanged = c.branchSignature != branchSignature
        if branchesChanged {
            c.timer?.invalidate(); c.stroke = nil
            c.branchSignature = branchSignature
            c.branchStrokes.forEach { $0.map = nil }; c.junctions.forEach { $0.map = nil }
            c.branchStrokes = []; c.junctions = []
            for branch in strokes {
                let path = GMSMutablePath()
                branch.coordinates.forEach { path.add(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
                let line = GMSPolyline(path: path); line.strokeColor = UIColor(branch.detour ? DetourTheme.orange : DetourTheme.ink); line.strokeWidth = branch.preview ? 3 : 4
                if branch.preview { line.spans = GMSStyleSpans(path, [GMSStrokeStyle.solidColor(UIColor(DetourTheme.orange)), GMSStrokeStyle.solidColor(.clear)], [80, 50], .rhumb) }
                line.map = map; c.branchStrokes.append(line)
                if routeChanged && strokes.count == 1 && !branch.detour { c.stroke = line; c.animateRoute(branch.coordinates) }
                guard branch.detour else { continue }
                for (index, coordinate) in [branch.coordinates.first, branch.coordinates.last].compactMap({ $0 }).enumerated() {
                    let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
                    let dot = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 12))
                    dot.backgroundColor = UIColor(DetourTheme.orange); dot.layer.cornerRadius = 6; dot.layer.borderWidth = 2; dot.layer.borderColor = UIColor.white.cgColor
                    marker.iconView = dot; marker.title = index == 0 ? "Detour starts" : "Rejoin route"; marker.map = map; c.junctions.append(marker)
                }
            }
        }
        if home {
            if c.center != center || c.cameraRevision != cameraRevision || c.home != home {
                map.animate(to: GMSCameraPosition(latitude: center.latitude, longitude: center.longitude, zoom: 14))
            }
        } else if routeChanged || branchesChanged || c.home != home || paddingChanged || candidateChanged || c.cameraRevision != cameraRevision {
            var bounds = GMSCoordinateBounds()
            let points = strokes.isEmpty ? pins.map { $0.place.coordinate } : strokes.flatMap(\.coordinates)
            for point in points { bounds = bounds.includingCoordinate(CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)) }
            if let candidate = pins.first(where: \.candidate) { bounds = bounds.includingCoordinate(CLLocationCoordinate2D(latitude: candidate.place.coordinate.latitude, longitude: candidate.place.coordinate.longitude)) }
            if !points.isEmpty { map.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 20)) }
        }
        c.center = center; c.home = home; c.cameraRevision = cameraRevision; c.candidateID = candidateID
    }
    static func dismantleUIView(_ uiView: GMSMapView, coordinator: Coordinator) { coordinator.timer?.invalidate() }
    @MainActor final class Coordinator: NSObject, @preconcurrency GMSMapViewDelegate {
        var signature = "", encoded: String?
        var candidateID: String?
        var branchSignature = ""
        var branchStrokes: [GMSPolyline] = [], junctions: [GMSMarker] = []
        var center: Coordinate?, home: Bool?, cameraRevision = -1
        var markers: [GMSMarker] = [], stroke: GMSPolyline?, timer: Timer?
        var select: (String) -> Void
        private var coordinates: [Coordinate] = []
        private var began = Date()
        func animateRoute(_ coordinates: [Coordinate]) {
            self.coordinates = coordinates; began = Date()
            drawRoute(UIAccessibility.isReduceMotionEnabled ? 1 : 0)
            if !UIAccessibility.isReduceMotionEnabled {
                timer = Timer.scheduledTimer(timeInterval: 1 / 30, target: self, selector: #selector(advanceRoute(_:)), userInfo: nil, repeats: true)
            }
        }
        @objc private func advanceRoute(_ timer: Timer) {
            let progress = min(1, Date().timeIntervalSince(began) / 1.4)
            drawRoute(progress); if progress >= 1 { timer.invalidate() }
        }
        private func drawRoute(_ progress: Double) {
            let path = GMSMutablePath()
            for point in RouteGeometry.prefix(coordinates, fraction: progress) { path.add(CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)) }
            stroke?.path = path
        }
        init(select: @escaping (String) -> Void) { self.select = select }
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let id = marker.userData as? String { select(id) }; return true
        }
    }
}

struct AppleTripMap: UIViewRepresentable {
    let route: RoutePlan?
    var strokes: [RouteStroke] = []
    let pins: [MapPin]
    var padding = UIEdgeInsets(top: 100, left: 32, bottom: 300, right: 32)
    var home = false
    var center = Fixtures.capeTown.coordinate
    var showsUserLocation = false
    var cameraRevision = 0
    var select: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(select: select) }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll; map.preferredConfiguration = configuration
        map.delegate = context.coordinator; map.isRotateEnabled = false; map.isPitchEnabled = false
        map.showsCompass = false; map.showsScale = true; map.accessibilityIdentifier = "trip-map"
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
                                        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)), animated: false)
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.select = select; map.showsUserLocation = showsUserLocation
        let candidateID = pins.first(where: \.candidate)?.id
        let candidateChanged = c.candidateID != candidateID
        let paddingChanged = c.padding != padding
        c.padding = padding
        // Native attribution must stay in the exposed map area above the drawer.
        // Fit with these margins once, rather than adding the same camera padding twice.
        map.layoutMargins = padding
        map.layoutIfNeeded()
        let signature = pins.map { "\($0.id):\($0.place.coordinate.latitude):\($0.place.coordinate.longitude):\($0.number ?? 0):\($0.candidate)" }.joined()
        if c.signature != signature {
            c.signature = signature
            map.removeAnnotations(map.annotations.compactMap { $0 as? PlaceAnnotation })
            map.addAnnotations(pins.map { PlaceAnnotation(pin: $0) })
        }
        let routeChanged = c.encoded != route?.encodedPolyline
        if routeChanged {
            c.encoded = route?.encodedPolyline; c.renderer?.stopAnimation(); map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations.compactMap { $0 as? JunctionAnnotation })
            c.branchSignature = ""
        }
        let branchSignature = strokes.map { "\($0.detour):\($0.preview):\(RouteGeometry.encode($0.coordinates))" }.joined()
        let branchesChanged = c.branchSignature != branchSignature
        if branchesChanged {
            c.branchSignature = branchSignature
            c.renderer?.stopAnimation(); map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations.compactMap { $0 as? JunctionAnnotation })
            for branch in strokes {
                let coordinates = branch.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                let line = MKPolyline(coordinates: coordinates, count: coordinates.count)
                line.title = branch.detour ? (branch.preview ? "detour-preview" : "detour-accepted") : (routeChanged && strokes.count == 1 ? "route-reveal" : "route-ink")
                map.addOverlay(line, level: .aboveRoads)
                guard branch.detour else { continue }
                if let first = branch.coordinates.first, let last = branch.coordinates.last {
                    map.addAnnotations([JunctionAnnotation(first, title: "Detour starts"), JunctionAnnotation(last, title: "Rejoin route")])
                }
            }
        }
        if home {
            if c.center != center || c.cameraRevision != cameraRevision || c.home != home {
                map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
                                                span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)), animated: c.home != nil && !UIAccessibility.isReduceMotionEnabled)
            }
        } else if routeChanged || branchesChanged || c.home != home || paddingChanged || candidateChanged || c.cameraRevision != cameraRevision {
            var bounds = map.overlays.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
            for pin in pins {
                let point = MKMapPoint(CLLocationCoordinate2D(latitude: pin.place.coordinate.latitude, longitude: pin.place.coordinate.longitude))
                bounds = bounds.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
            }
            if !bounds.isNull {
                c.fit(map, bounds: bounds, padding: padding)
            }
        }
        c.center = center; c.home = home; c.cameraRevision = cameraRevision; c.candidateID = candidateID
    }
    static func dismantleUIView(_ uiView: MKMapView, coordinator: Coordinator) { coordinator.renderer?.stopAnimation(); coordinator.fitTask?.cancel() }
    final class PlaceAnnotation: NSObject, MKAnnotation {
        let pin: MapPin
        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: pin.place.coordinate.latitude, longitude: pin.place.coordinate.longitude) }
        var title: String? { pin.place.name }
        init(pin: MapPin) { self.pin = pin }
    }
    final class JunctionAnnotation: NSObject, MKAnnotation {
        var coordinate: CLLocationCoordinate2D
        var title: String?
        init(_ coordinate: Coordinate, title: String) {
            self.coordinate = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude); self.title = title
        }
    }
    @MainActor final class Coordinator: NSObject, MKMapViewDelegate {
        var signature = "", encoded: String?
        var candidateID: String?
        var branchSignature = ""
        var center: Coordinate?, home: Bool?, cameraRevision = -1
        var padding: UIEdgeInsets?
        var renderer: AnimatedRouteRenderer?
        var fitTask: Task<Void, Never>?
        private var pendingFit: (bounds: MKMapRect, padding: UIEdgeInsets)?
        private var fitRevision = UUID(), fitPasses = 0
        var select: (String) -> Void
        init(select: @escaping (String) -> Void) { self.select = select }
        func fit(_ map: MKMapView, bounds: MKMapRect, padding: UIEdgeInsets) {
            fitTask?.cancel(); fitRevision = UUID(); fitPasses = 0; pendingFit = (bounds, padding)
            let revision = fitRevision
            // Complete fitting in sequence. An older camera animation must not
            // overwrite corrections after the header or drawer changes height.
            map.setVisibleMapRect(bounds, edgePadding: .zero, animated: false)
            fitTask = Task { @MainActor [weak self, weak map] in
                try? await Task.sleep(for: .milliseconds(400))
                // Region callbacks can arrive before MapKit has finished applying
                // a camera. Read each correction on a later frame instead of
                // recursively fitting from those callbacks with stale projections.
                for _ in 0..<3 {
                    guard !Task.isCancelled, let self, let map, self.fitRevision == revision, self.pendingFit != nil else { return }
                    self.correctFit(map)
                    try? await Task.sleep(for: .milliseconds(150))
                }
                guard let self, self.fitRevision == revision else { return }
                self.pendingFit = nil
            }
        }
        private func correctFit(_ map: MKMapView) {
            guard let fit = pendingFit, map.bounds.width > 0, map.bounds.height > 0 else { return }
            guard fitPasses < 3 else { pendingFit = nil; return }
            // Read screen positions after MapKit has applied its camera, rather than while it is still moving.
            let corners = [MKMapPoint(x: fit.bounds.minX, y: fit.bounds.minY), MKMapPoint(x: fit.bounds.maxX, y: fit.bounds.maxY)]
            let projected = corners.reduce(CGRect.null) { rect, point in
                let position = map.convert(point.coordinate, toPointTo: map)
                return rect.union(CGRect(x: position.x, y: position.y, width: 1, height: 1))
            }
            let width = max(80, map.bounds.width - fit.padding.left - fit.padding.right)
            let height = max(40, map.bounds.height - fit.padding.top - fit.padding.bottom - 40)
            let target = CGPoint(x: fit.padding.left + width / 2, y: fit.padding.top + height / 2)
            let scale = max(projected.width / width, projected.height / height) * 1.12
            if abs(projected.midX - target.x) < 3, abs(projected.midY - target.y) < 3, abs(scale - 1) < 0.08 { pendingFit = nil; return }
            fitPasses += 1
            // MapKit moves the camera's screen anchor when layout margins change.
            // Project the actual anchor so fitting and attribution use the same viewport.
            let middle = map.convert(map.camera.centerCoordinate, toPointTo: map)
            let offset = CGPoint(x: projected.midX - middle.x - scale * (target.x - middle.x),
                                 y: projected.midY - middle.y - scale * (target.y - middle.y))
            let camera = map.camera.copy() as! MKMapCamera
            camera.centerCoordinate = map.convert(CGPoint(x: middle.x + offset.x, y: middle.y + offset.y), toCoordinateFrom: map)
            camera.altitude *= scale
            map.setCamera(camera, animated: false)
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            if line.title?.hasPrefix("detour") == true {
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = UIColor(DetourTheme.orange); renderer.lineWidth = 4
                if line.title == "detour-preview" { renderer.lineDashPattern = [6, 5] }
                renderer.lineCap = .round; renderer.lineJoin = .round; return renderer
            }
            if line.title == "route-reveal" {
                let renderer = AnimatedRouteRenderer(polyline: line); self.renderer = renderer; renderer.animate(); return renderer
            }
            let renderer = MKPolylineRenderer(polyline: line)
            renderer.strokeColor = UIColor(DetourTheme.ink); renderer.lineWidth = 4
            renderer.lineCap = .round; renderer.lineJoin = .round; return renderer
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if annotation is JunctionAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "junction") ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "junction")
                view.annotation = annotation; view.frame.size = CGSize(width: 12, height: 12)
                view.backgroundColor = UIColor(DetourTheme.orange); view.layer.cornerRadius = 6; view.layer.borderWidth = 2; view.layer.borderColor = UIColor.white.cgColor
                view.displayPriority = .required; view.accessibilityLabel = annotation.title ?? "Detour junction"; return view
            }
            guard let annotation = annotation as? PlaceAnnotation else { return nil }
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "place") as? MKMarkerAnnotationView) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "place")
            view.annotation = annotation; view.markerTintColor = UIColor(annotation.pin.candidate ? DetourTheme.orange : DetourTheme.ink)
            view.glyphText = annotation.pin.number.map(String.init)
            view.glyphImage = annotation.pin.number == nil ? UIImage(systemName: annotation.pin.place.category.symbol) : nil
            view.displayPriority = .required; view.titleVisibility = .adaptive
            view.accessibilityLabel = annotation.pin.number.map { "Stop \($0), \(annotation.pin.place.name)" } ?? annotation.pin.place.name
            return view
        }
        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            guard let annotation = annotation as? PlaceAnnotation else { return }
            select(annotation.pin.id); mapView.deselectAnnotation(annotation, animated: false)
        }
    }
}

final class AnimatedRouteRenderer: MKPolylineRenderer {
    private var timer: Timer?
    private var revealed: [Coordinate] = []
    private var coordinates: [Coordinate] = []
    private var began = Date()
    private let revealLock = NSLock()
    private func reveal(_ coordinates: [Coordinate]) {
        revealLock.lock(); revealed = coordinates; revealLock.unlock(); setNeedsDisplay()
    }
    @MainActor func animate() {
        coordinates = (0..<polyline.pointCount).map { i in
            let point = polyline.points()[i].coordinate
            return Coordinate(latitude: point.latitude, longitude: point.longitude)
        }
        if UIAccessibility.isReduceMotionEnabled { reveal(coordinates); return }
        began = Date()
        reveal(RouteGeometry.prefix(coordinates, fraction: 0))
        timer = Timer.scheduledTimer(timeInterval: 1 / 30, target: self, selector: #selector(advanceRoute(_:)), userInfo: nil, repeats: true)
    }
    @MainActor @objc private func advanceRoute(_ timer: Timer) {
        let fraction = min(1, Date().timeIntervalSince(began) / 1.4)
        reveal(RouteGeometry.prefix(coordinates, fraction: fraction))
        if fraction >= 1 { timer.invalidate() }
    }
    @MainActor func stopAnimation() { timer?.invalidate() }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // MapKit can render tiles off the main thread while the animation advances.
        revealLock.lock(); let revealed = self.revealed; revealLock.unlock()
        guard revealed.count > 1 else { return }
        context.saveGState(); context.setStrokeColor(UIColor(DetourTheme.ink).cgColor)
        context.setLineWidth(4 / zoomScale); context.setLineCap(.round); context.setLineJoin(.round)
        context.beginPath()
        for (index, coordinate) in revealed.enumerated() {
            let point = point(for: MKMapPoint(CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)))
            if index == 0 { context.move(to: point) } else { context.addLine(to: point) }
        }
        context.strokePath(); context.restoreGState()
    }
}
