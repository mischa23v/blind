import Foundation

public struct Venue: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radiusMeters: Double
    public var mapFile: String
    public init(id: String, name: String, latitude: Double, longitude: Double, radiusMeters: Double, mapFile: String) {
        self.id = id; self.name = name; self.latitude = latitude; self.longitude = longitude
        self.radiusMeters = radiusMeters; self.mapFile = mapFile
    }
}
public struct VenueCatalog: Codable, Sendable {
    public var venues: [Venue]
    public init(venues: [Venue]) { self.venues = venues }
    public func validate() throws {
        guard Set(venues.map(\.id)).count == venues.count,
              venues.allSatisfy({ !$0.id.isEmpty && !$0.name.isEmpty && $0.latitude.isFinite && $0.longitude.isFinite &&
                  abs($0.latitude) <= 90 && abs($0.longitude) <= 180 && $0.radiusMeters.isFinite &&
                  (10...2000).contains($0.radiusMeters) && !$0.mapFile.isEmpty &&
                  $0.mapFile.hasSuffix(".json") && !$0.mapFile.contains("/") && !$0.mapFile.contains("\\") &&
                  !$0.mapFile.contains("..") }) else { throw MapError.invalid }
    }
    /// A candidate venue selects map data only; it never establishes an indoor pose or floor.
    public func candidates(latitude: Double, longitude: Double, accuracy: Double, age: Double) -> [Venue] {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180,
              accuracy.isFinite, accuracy >= 0, accuracy <= 30, age >= 0, age <= 10,
              (try? validate()) != nil else { return [] }
        return venues.filter { venue in
            let lat1 = latitude * .pi / 180, lat2 = venue.latitude * .pi / 180
            let dLat = lat2 - lat1, dLon = (venue.longitude - longitude) * .pi / 180
            let a = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2)
            let distance = 6_371_000 * 2 * atan2(sqrt(min(1, a)), sqrt(max(0, 1 - a)))
            return distance + accuracy <= venue.radiusMeters
        }
    }
}
