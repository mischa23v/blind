import Foundation

public struct SurveyCell: Hashable, Codable, Sendable { public var x: Int; public var z: Int }
public struct SurveyCoverage: Sendable {
    public enum State: String, Sendable { case needsTracking, needsFloor, collecting, limitReached }
    public let resolution = 0.25
    public private(set) var floorCells = Set<SurveyCell>()
    public private(set) var trail: [Point3] = []
    public private(set) var camera: Point3?
    public private(set) var state: State = .needsTracking
    public private(set) var resets = 0
    private var previous: (time: Double, point: Point3)?
    private var lastSample = -Double.infinity
    public init() {}
    public mutating func invalidate() {
        if previous != nil || !floorCells.isEmpty { resets += 1 }
        floorCells.removeAll(keepingCapacity: true); trail.removeAll(keepingCapacity: true)
        camera = nil; previous = nil; lastSample = -.infinity; state = .needsTracking
    }
    public mutating func observe(_ frame: Observation, floor: Double?) {
        guard frame.trackingNormal, frame.timestamp.isFinite, frame.camera.isFinite else { invalidate(); return }
        if let previous {
            let delta = frame.timestamp - previous.time
            guard delta > 0, delta <= 0.5, frame.camera.distance(to: previous.point) / delta <= 3 else { invalidate(); return }
        }
        previous = (frame.timestamp, frame.camera); camera = frame.camera
        if trail.count < 5000, trail.last.map({ $0.distance(to: frame.camera) >= 0.3 }) ?? true { trail.append(frame.camera) }
        guard let floor, floor.isFinite else { state = .needsFloor; return }
        guard floorCells.count < 10000, trail.count < 5000 else { state = .limitReached; return }
        state = .collecting
        guard frame.timestamp - lastSample >= 0.5 else { return }; lastSample = frame.timestamp
        var counts: [SurveyCell: Int] = [:]
        for sample in frame.samples where sample.confidence >= 2 && sample.position.isFinite {
            let p = sample.position
            guard abs(p.y - floor) <= 0.09, abs(p.x) <= 1000, abs(p.z) <= 1000,
                  p.distance(to: frame.camera) <= 5 else { continue }
            let cell = SurveyCell(x: Int((p.x / resolution).rounded(.down)), z: Int((p.z / resolution).rounded(.down)))
            counts[cell, default: 0] += 1
        }
        // Do not fill the camera's view cone or the walked trail with invented floor.
        for (cell, count) in counts where count >= 3 && floorCells.count < 10000 { floorCells.insert(cell) }
    }
}
