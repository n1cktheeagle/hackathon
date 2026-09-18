import Foundation

// Shared, deterministic geometry for fixture routes and ordering stops.
enum RouteGeometry {
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
        guard route.count > 1 else { return 0 }
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
        return travelled > 0 ? best / travelled : 0
    }
}
