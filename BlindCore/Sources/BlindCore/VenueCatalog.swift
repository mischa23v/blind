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

/// Local directory references, not Google content, hierarchy or localization evidence.
/// An explicit selection pins immutable package bytes; no network provider is required.
public struct VenuePackageReference: Codable, Equatable, Sendable, Identifiable {
    public let venue: Venue
    public let packageID: String
    public let packageRevision: String
    public let digest: String
    public let googlePlaceID: String?
    public var id: String { venue.id }
    public init(venue: Venue, packageID: String, packageRevision: String, digest: String,
                googlePlaceID: String? = nil) {
        self.venue = venue; self.packageID = packageID; self.packageRevision = packageRevision
        self.digest = digest; self.googlePlaceID = googlePlaceID
    }
    public func validate() throws {
        try VenueCatalog(venues: [venue]).validate()
        guard PlacePackage.validID(venue.id), venue.name.count <= 300,
              PlacePackage.validID(packageID), PlacePackage.validID(packageRevision),
              digest.count == 64, digest.allSatisfy({ "0123456789abcdef".contains($0) }),
              venue.mapFile == digest + ".json",
              googlePlaceID == nil || (!googlePlaceID!.isEmpty && googlePlaceID!.count <= 256 &&
                googlePlaceID!.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || "_-".unicodeScalars.contains($0) }))
        else { throw MapError.invalid }
    }
    public func validate(package: PlacePackage, actualDigest: String) throws {
        try validate(); try package.validate()
        guard package.visibility == "public", package.id == packageID,
              package.revision == packageRevision, actualDigest == digest else { throw MapError.invalid }
    }
}

public struct VenuePackageCatalog: Codable, Sendable {
    public let schemaVersion: Int
    public let references: [VenuePackageReference]
    public static let maximumBytes = 128_000
    public init(references: [VenuePackageReference]) { schemaVersion = 1; self.references = references }
    public func validate() throws {
        guard schemaVersion == 1, references.count <= 128,
              Set(references.map(\.id)).count == references.count else { throw MapError.invalid }
        let google = references.compactMap(\.googlePlaceID)
        guard Set(google).count == google.count else { throw MapError.invalid }
        for reference in references { try reference.validate() }
    }
    public static func decode(_ data: Data) throws -> Self {
        guard !data.isEmpty, data.count <= maximumBytes else { throw MapError.invalid }
        let value = try JSONDecoder().decode(Self.self, from: data); try value.validate(); return value
    }
    /// Exact optional provider key lookup only; no request to Google or location assertion.
    public func reference(googlePlaceID: String) -> VenuePackageReference? {
        guard (try? validate()) != nil else { return nil }
        return references.first { $0.googlePlaceID == googlePlaceID }
    }
    public func candidates(latitude: Double, longitude: Double, accuracy: Double, age: Double) -> [VenuePackageReference] {
        guard (try? validate()) != nil else { return [] }
        let ids = Set(VenueCatalog(venues: references.map(\.venue))
            .candidates(latitude: latitude, longitude: longitude, accuracy: accuracy, age: age).map(\.id))
        return references.filter { ids.contains($0.id) }
    }
}
