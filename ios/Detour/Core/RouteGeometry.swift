import Foundation

struct RouteStroke: Sendable {
    var coordinates: [Coordinate]
    var detour = false
    var preview = false
}

// Shared, deterministic geometry for fixture routes and ordering stops.
enum RouteGeometry {
    // Splice each detour into the visible journey, removing the section it replaces.
    // Later previews can also replace part of an already accepted detour.
    static func replacingDetours(_ baseline: [Coordinate], accepted: [[Coordinate]], preview: [[Coordinate]]) -> [RouteStroke] {
        guard baseline.count > 1 else { return [] }
        var strokes = [RouteStroke(coordinates: baseline)]
        let cosine = cos(baseline[0].latitude * .pi / 180)
        func length(_ a: Coordinate, _ b: Coordinate) -> Double {
            hypot(b.latitude - a.latitude, (b.longitude - a.longitude) * cosine)
        }
        func distances(_ points: [Coordinate]) -> [Double] {
            var values = [0.0]
            for index in 1..<points.count { values.append(values.last! + length(points[index - 1], points[index])) }
            return values
        }
        func projection(_ point: Coordinate, points: [Coordinate], distances: [Double]) -> (distance: Double, coordinate: Coordinate) {
            var nearest = Double.infinity, result = (0.0, points[0])
            for index in 1..<points.count {
                let a = points[index - 1], b = points[index]
                let dx = (b.longitude - a.longitude) * cosine, dy = b.latitude - a.latitude
                let x = (point.longitude - a.longitude) * cosine, y = point.latitude - a.latitude
                let squared = dx * dx + dy * dy
                let t = squared > 0 ? max(0, min(1, (x * dx + y * dy) / squared)) : 0
                let separation = hypot(x - t * dx, y - t * dy)
                if separation < nearest {
                    nearest = separation
                    result = (distances[index - 1] + t * (distances[index] - distances[index - 1]),
                              Coordinate(latitude: a.latitude + t * (b.latitude - a.latitude), longitude: a.longitude + t * (b.longitude - a.longitude)))
                }
            }
            return result
        }
        func slice(_ points: [Coordinate], from lower: Double, to upper: Double) -> [Coordinate] {
            guard upper - lower > 1e-10 else { return [] }
            let values = distances(points)
            func coordinate(at distance: Double) -> Coordinate {
                for index in 1..<points.count where values[index] >= distance {
                    let span = values[index] - values[index - 1]
                    let t = span > 0 ? max(0, min(1, (distance - values[index - 1]) / span)) : 0
                    return Coordinate(latitude: points[index - 1].latitude + t * (points[index].latitude - points[index - 1].latitude),
                                      longitude: points[index - 1].longitude + t * (points[index].longitude - points[index - 1].longitude))
                }
                return points.last!
            }
            return [coordinate(at: lower)] + points.indices.filter { values[$0] > lower && values[$0] < upper }.map { points[$0] } + [coordinate(at: upper)]
        }
        for (branches, isPreview) in [(accepted, false), (preview, true)] {
            for branch in branches where branch.count > 1 {
                let journey = strokes.flatMap(\.coordinates), values = distances(journey)
                let entry = projection(branch.first!, points: journey, distances: values)
                let exit = projection(branch.last!, points: journey, distances: values)
                // Preserve traversal direction when directions return a backwards leg.
                guard exit.distance + 1e-10 >= entry.distance else { continue }
                var before: [RouteStroke] = [], after: [RouteStroke] = [], offset = 0.0
                for stroke in strokes {
                    let span = distances(stroke.coordinates).last!
                    let left = slice(stroke.coordinates, from: 0, to: min(span, max(0, entry.distance - offset)))
                    let right = slice(stroke.coordinates, from: min(span, max(0, exit.distance - offset)), to: span)
                    if left.count > 1 { before.append(RouteStroke(coordinates: left, detour: stroke.detour, preview: stroke.preview)) }
                    if right.count > 1 { after.append(RouteStroke(coordinates: right, detour: stroke.detour, preview: stroke.preview)) }
                    offset += span
                }
                var replacement = branch
                replacement[0] = entry.coordinate; replacement[replacement.count - 1] = exit.coordinate
                if !before.isEmpty { before[before.count - 1].coordinates[before.last!.coordinates.count - 1] = entry.coordinate }
                if !after.isEmpty { after[0].coordinates[0] = exit.coordinate }
                strokes = before + [RouteStroke(coordinates: replacement, detour: true, preview: isPreview)] + after
            }
        }
        return strokes
    }

    // Compare road geometry using a local grid, avoiding a full route scan for every point.
    // The 35 m tolerance absorbs lane offsets and encoded-polyline rounding.
    static func detourSegments(_ proposed: [Coordinate], baseline: [Coordinate]) -> [[Coordinate]] {
        guard proposed.count > 1, baseline.count > 1 else { return [] }
        struct Cell: Hashable { let x: Int; let y: Int }
        let latitudeScale = 111_000.0, longitudeScale = 111_000 * cos(baseline[0].latitude * .pi / 180)
        let reference = baseline[0]
        func point(_ coordinate: Coordinate) -> (x: Double, y: Double) {
            ((coordinate.longitude - reference.longitude) * longitudeScale, (coordinate.latitude - reference.latitude) * latitudeScale)
        }
        func cell(_ x: Double, _ y: Double) -> Cell { Cell(x: Int(floor(x / 1000)), y: Int(floor(y / 1000))) }
        let points = baseline.map(point)
        var grid: [Cell: Set<Int>] = [:]
        for index in 1..<points.count {
            let a = points[index - 1], b = points[index]
            let samples = max(1, Int(ceil(hypot(b.x - a.x, b.y - a.y) / 500)))
            for sample in 0...samples {
                let t = Double(sample) / Double(samples)
                grid[cell(a.x + t * (b.x - a.x), a.y + t * (b.y - a.y)), default: []].insert(index)
            }
        }
        func matchingPoint(_ coordinate: Coordinate) -> Coordinate? {
            let p = point(coordinate), key = cell(p.x, p.y)
            var indices: Set<Int> = []
            for x in -1...1 { for y in -1...1 { indices.formUnion(grid[Cell(x: key.x + x, y: key.y + y)] ?? []) } }
            var nearest = Double.infinity, matched = coordinate
            for index in indices {
                let a = points[index - 1], b = points[index]
                let dx = b.x - a.x, dy = b.y - a.y
                let squared = dx * dx + dy * dy
                let t = squared > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / squared)) : 0
                let distance = hypot(p.x - a.x - t * dx, p.y - a.y - t * dy)
                if distance < nearest {
                    nearest = distance
                    matched = Coordinate(latitude: reference.latitude + (a.y + t * dy) / latitudeScale,
                                         longitude: reference.longitude + (a.x + t * dx) / longitudeScale)
                }
            }
            return nearest <= 35 ? matched : nil
        }
        var branches: [[Coordinate]] = [], branch: [Coordinate] = []
        var lastOnRoute: Coordinate?
        for coordinate in proposed {
            if let onRoute = matchingPoint(coordinate) {
                if !branch.isEmpty { branch.append(onRoute); branches.append(branch); branch = [] }
                lastOnRoute = onRoute
            } else {
                if branch.isEmpty, let lastOnRoute { branch.append(lastOnRoute) }
                branch.append(coordinate)
            }
        }
        if branch.count > 1 { branches.append(branch) }
        return branches.filter { $0.count > 2 }
    }
    // Reveal by distance, rather than point count, so sparse and dense sections draw evenly.
    static func prefix(_ route: [Coordinate], fraction: Double) -> [Coordinate] {
        guard let first = route.first else { return [] }
        guard fraction > 0 else { return [first] }
        guard fraction < 1 else { return route }
        let lengths = zip(route, route.dropFirst()).map { a, b in
            hypot(b.latitude - a.latitude, (b.longitude - a.longitude) * cos(a.latitude * .pi / 180))
        }
        var remaining = lengths.reduce(0, +) * fraction
        var result = [first]
        for index in lengths.indices {
            if remaining >= lengths[index] { result.append(route[index + 1]); remaining -= lengths[index] }
            else {
                let t = lengths[index] > 0 ? remaining / lengths[index] : 0
                let a = route[index], b = route[index + 1]
                result.append(Coordinate(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                         longitude: a.longitude + (b.longitude - a.longitude) * t))
                break
            }
        }
        return result
    }
    static func decode(_ encoded: String) -> [Coordinate] {
        let bytes = Array(encoded.utf8)
        var index = 0, latitude = 0, longitude = 0
        func component() -> Int? {
            var result = 0, shift = 0, byte = 0
            repeat {
                guard index < bytes.count, shift <= 30, bytes[index] >= 63 else { return nil }
                byte = Int(bytes[index]) - 63; index += 1
                result |= (byte & 31) << shift; shift += 5
            } while byte >= 32
            return result & 1 != 0 ? ~(result >> 1) : result >> 1
        }
        var result: [Coordinate] = []
        while index < bytes.count {
            guard let lat = component(), let lon = component() else { return [] }
            latitude += lat; longitude += lon
            result.append(Coordinate(latitude: Double(latitude) / 1e5, longitude: Double(longitude) / 1e5))
        }
        return result
    }
    static func encode(_ coordinates: [Coordinate]) -> String {
        var lastLat = 0, lastLon = 0, result = ""
        func component(_ delta: Int) -> String {
            var value = delta < 0 ? ~(delta << 1) : delta << 1
            var bytes: [UInt8] = []
            while value >= 32 { bytes.append(UInt8((32 | (value & 31)) + 63)); value >>= 5 }
            bytes.append(UInt8(value + 63))
            return String(decoding: bytes, as: UTF8.self)
        }
        for coordinate in coordinates {
            let lat = Int((coordinate.latitude * 1e5).rounded()), lon = Int((coordinate.longitude * 1e5).rounded())
            result += component(lat - lastLat) + component(lon - lastLon)
            lastLat = lat; lastLon = lon
        }
        return result
    }
    static func progress(_ point: Coordinate, along route: [Coordinate]) -> Double {
        projection(point, along: route).progress
    }
    static func distanceFromRoute(_ point: Coordinate, along route: [Coordinate]) -> Double {
        projection(point, along: route).distanceMetres
    }
    private static func projection(_ point: Coordinate, along route: [Coordinate]) -> (progress: Double, distanceMetres: Double) {
        guard route.count > 1 else { return (0, 0) }
        var best = 0.0, nearest = Double.infinity, travelled = 0.0
        let cosine = cos(point.latitude * .pi / 180)
        for index in 1..<route.count {
            let a = route[index - 1], b = route[index]
            let dx = (b.longitude - a.longitude) * cosine, dy = b.latitude - a.latitude
            let squared = dx * dx + dy * dy
            let x = (point.longitude - a.longitude) * cosine, y = point.latitude - a.latitude
            let t = squared > 0 ? max(0, min(1, (x * dx + y * dy) / squared)) : 0
            let distance = pow(x - t * dx, 2) + pow(y - t * dy, 2)
            let length = sqrt(squared)
            if distance < nearest { nearest = distance; best = travelled + t * length }
            travelled += length
        }
        return (travelled > 0 ? best / travelled : 0, sqrt(nearest) * 111_000)
    }
}
