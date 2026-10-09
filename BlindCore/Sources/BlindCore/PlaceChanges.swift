import Foundation

public struct MappedObject: Codable, Equatable, Sendable {
    public var id: String
    public var category: String
    public var center: Point3
    public init(id: String, category: String, center: Point3) {
        self.id = id; self.category = category; self.center = center
    }
}
public enum PlaceChange: Equatable, Sendable {
    case moved(category: String, distance: Double)
    case added(category: String)
    case notObserved(category: String)
}
public enum PlaceComparison {
    /// Compare ONLY scans sharing a continuous or explicitly relocalized AR world.
    /// RoomPlan identifiers can change between scans; nearest category matches
    /// are a heuristic and ambiguous same-category objects are left unassigned.
    public static func changes(baseline: [MappedObject], current: [MappedObject],
                               relocalized: Bool, movementThreshold: Double = 0.35) -> [PlaceChange] {
        guard relocalized else { return [] }
        var unmatched = current
        var results: [PlaceChange] = []
        for old in baseline {
            let matches = unmatched.enumerated().filter { $0.element.category == old.category }
                .sorted { $0.element.center.distance(to: old.center) < $1.element.center.distance(to: old.center) }
            guard let best = matches.first else { results.append(.notObserved(category: old.category)); continue }
            let distance = best.element.center.distance(to: old.center)
            if matches.count > 1 && abs(matches[1].element.center.distance(to: old.center) - distance) < 0.15 {
                continue
            }
            unmatched.remove(at: best.offset)
            if distance > movementThreshold { results.append(.moved(category: old.category, distance: distance)) }
        }
        for item in unmatched { results.append(.added(category: item.category)) }
        return results
    }
}
