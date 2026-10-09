import Foundation

/// An authored rectangle on one floor, in the same metre coordinates as IndoorMap.
/// This is a route restriction, not a physical barrier or evidence of live localization.
public struct KeepOutZone: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var nameArabic: String?
    public var level: String
    public var minX: Double
    public var maxX: Double
    public var minZ: Double
    public var maxZ: Double
    public init(id: String, name: String, level: String, minX: Double, maxX: Double, minZ: Double, maxZ: Double, nameArabic: String? = nil) {
        self.id = id; self.name = name; self.nameArabic = nameArabic; self.level = level
        self.minX = minX; self.maxX = maxX; self.minZ = minZ; self.maxZ = maxZ
    }
    public var valid: Bool {
        !id.isEmpty && !name.isEmpty && !level.isEmpty &&
        [minX, maxX, minZ, maxZ].allSatisfy { $0.isFinite && abs($0) <= 100_000 } &&
        minX < maxX && minZ < maxZ
    }
    public func localizedName(arabic: Bool) -> String { arabic ? (nameArabic ?? name) : name }

    /// Exact line/expanded-box intersection. Square expansion is conservative at corners.
    /// Invalid geometry fails closed. Touching the expanded boundary also counts.
    public func intersects(from a: Point3, to b: Point3, padding: Double) -> Bool {
        guard valid, a.isFinite, b.isFinite, padding.isFinite, padding >= 0 else { return true }
        var entry = 0.0, exit = 1.0
        for (start, end, low, high) in [(a.x, b.x, minX - padding, maxX + padding),
                                       (a.z, b.z, minZ - padding, maxZ + padding)] {
            let delta = end - start
            guard delta.isFinite else { return true }
            if abs(delta) < 1e-12 {
                if start < low || start > high { return false }
            } else {
                let first = (low - start) / delta, last = (high - start) / delta
                entry = max(entry, min(first, last)); exit = min(exit, max(first, last))
                if entry > exit { return false }
            }
        }
        return true
    }
}
