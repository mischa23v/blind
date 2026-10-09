import Foundation

public enum GuidanceState: String, Sendable {
    case needsPosition, needsCalibration, unknownTerrain, blocked, candidatePath
}

public struct LocalPlan: Sendable {
    public var state: GuidanceState
    public var points: [Point3]
    public var sector: Int?
    public var observedCells: Int
    public var minimumElevation: Double?
    public var maximumElevation: Double?
    public init(_ state: GuidanceState, points: [Point3] = [], sector: Int? = nil,
                observedCells: Int = 0, minimumElevation: Double? = nil, maximumElevation: Double? = nil) {
        self.state = state; self.points = points; self.sector = sector
        self.observedCells = observedCells; self.minimumElevation = minimumElevation; self.maximumElevation = maximumElevation
    }
}

/// Short-horizon, camera-relative terrain planner. Unknown cells are impassable.
/// It proposes a path through observed level terrain; it cannot certify walking clearance.
/// Rebuilt from each depth observation so old geometry never silently becomes current evidence.
public struct LocalPlanner: Sendable {
    public var resolution = 0.2
    public var bodyRadius = 0.28
    public var maximumElevation = 0.09
    public var horizon = 1.8
    public init() {}
    private struct Cell: Hashable { var x: Int; var z: Int }
    public func plan(observation: Observation, floor: Double?, target: Point3?, now: Double) -> LocalPlan {
        guard observation.trackingNormal, observation.camera.isFinite, observation.forward.isFinite,
              now.isFinite, observation.timestamp.isFinite, now >= observation.timestamp,
              now - observation.timestamp <= 0.5,
              abs(hypot(observation.forward.x, observation.forward.z) - 1) < 0.05 else { return LocalPlan(.needsPosition) }
        guard let floor, floor.isFinite else { return LocalPlan(.needsCalibration) }
        guard let target, target.isFinite else { return LocalPlan(.needsPosition) }
        guard resolution >= 0.1, bodyRadius >= 0.1, horizon >= 0.5, horizon <= 3 else { return LocalPlan(.unknownTerrain) }
        var heights: [Cell: [Double]] = [:]
        for sample in observation.samples where sample.confidence >= 2 && sample.position.isFinite {
            let c = observation.coordinates(sample.position)
            guard abs(c.side) <= 3, c.ahead >= 0, c.ahead <= 3 else { continue }
            let cell = Cell(x: Int(floorValue(c.side / resolution)), z: Int(floorValue(c.ahead / resolution)))
            heights[cell, default: []].append(sample.position.y - floor)
        }
        // Require multiple independent returns and reject cells with obstacles, rises, or drops.
        let supported = Set(heights.compactMap { cell, values -> Cell? in
            guard values.count >= 3, values.allSatisfy({ abs($0) <= maximumElevation }) else { return nil }
            return cell
        })
        let elevations = heights.values.flatMap { $0 }
        var result = LocalPlan(.unknownTerrain, observedCells: heights.count,
                               minimumElevation: elevations.min(), maximumElevation: elevations.max())
        let inflation = Int(ceil(bodyRadius / resolution))
        func traversable(_ cell: Cell) -> Bool {
            for dx in -inflation...inflation {
                for dz in -inflation...inflation where hypot(Double(dx), Double(dz)) * resolution <= bodyRadius {
                    if !supported.contains(Cell(x: cell.x + dx, z: cell.z + dz)) { return false }
                }
            }
            return true
        }
        // This is a look-ahead plan. The unobserved ground directly under the wearer is not asserted safe.
        let start = Cell(x: 0, z: Int(0.6 / resolution))
        guard traversable(start) else { return result }
        let direction = observation.coordinates(target)
        let length = hypot(direction.side, direction.ahead)
        guard length > 0.3 else { return LocalPlan(.needsPosition) }
        let scale = min(1, horizon / length)
        let goal = Cell(x: Int(floorValue(direction.side * scale / resolution)),
                        z: Int(floorValue(direction.ahead * scale / resolution)))
        guard traversable(goal) else {
            result.state = heights[goal] == nil ? .unknownTerrain : .blocked
            return result
        }
        var open: Set<Cell> = [start], visited = Set<Cell>(), costs = [start: 0.0], previous: [Cell: Cell] = [:]
        func heuristic(_ cell: Cell) -> Double { hypot(Double(goal.x - cell.x), Double(goal.z - cell.z)) }
        while let current = open.min(by: { costs[$0, default: .infinity] + heuristic($0) < costs[$1, default: .infinity] + heuristic($1) }) {
            if current == goal {
                var cells = [goal]
                while cells.last != start {
                    guard let parent = previous[cells.last!] else { return result }
                    cells.append(parent)
                }
                let path = cells.reversed().map { cell -> Point3 in
                    let ahead = (Double(cell.z) + 0.5) * resolution, side = (Double(cell.x) + 0.5) * resolution
                    let f = observation.forward, c = observation.camera
                    return Point3(c.x + ahead * f.x - side * f.z, floor, c.z + ahead * f.z + side * f.x)
                }
                let cue = observation.coordinates(path[min(3, path.count - 1)])
                result.state = .candidatePath; result.points = path
                result.sector = (Int((atan2(cue.side, cue.ahead) / (.pi / 4)).rounded()) + 8) % 8
                return result
            }
            open.remove(current); visited.insert(current)
            for dx in -1...1 {
                for dz in -1...1 where dx != 0 || dz != 0 {
                    let next = Cell(x: current.x + dx, z: current.z + dz)
                    guard !visited.contains(next), traversable(next) else { continue }
                    if dx != 0 && dz != 0 && (!traversable(Cell(x: current.x + dx, z: current.z)) ||
                        !traversable(Cell(x: current.x, z: current.z + dz))) { continue }
                    let cost = costs[current]! + hypot(Double(dx), Double(dz))
                    if cost < costs[next, default: .infinity] { costs[next] = cost; previous[next] = current; open.insert(next) }
                }
            }
        }
        result.state = .blocked
        return result
    }
    private func floorValue(_ value: Double) -> Double { value.rounded(.down) }
}
