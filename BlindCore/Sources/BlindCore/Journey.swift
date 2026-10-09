import Foundation

public struct JourneyPoint: Codable, Equatable, Sendable {
    public var seconds: Double
    public var position: Point3
    public var segment: Int
}
public struct Journey: Codable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var points: [JourneyPoint] = []
    public init(id: UUID = UUID(), createdAt: Date = Date()) { self.id = id; self.createdAt = createdAt }
    public var distance: Double {
        zip(points, points.dropFirst()).reduce(0) { sum, pair in
            sum + (pair.0.segment == pair.1.segment ? pair.0.position.distance(to: pair.1.position) : 0)
        }
    }
}
/// History is an observation log, not proof that a route is still walkable.
public struct JourneyRecorder: Sendable {
    public private(set) var journey = Journey()
    public private(set) var distance = 0.0
    private var originTime: Double?
    private var previous: (Double, Point3)?
    private var segment = 0
    public init() {}
    public mutating func breakTracking() { if previous != nil { segment += 1 }; previous = nil }
    public mutating func observe(camera: Point3, time: Double, tracking: Bool) {
        guard tracking, camera.isFinite, time.isFinite else { breakTracking(); return }
        if let previous {
            guard time > previous.0 else { breakTracking(); return }
            if time - previous.0 > 0.5 || camera.distance(to: previous.1) / (time - previous.0) > 3 {
                breakTracking()
            }
        }
        previous = (time, camera)
        if originTime == nil { originTime = time }
        guard time >= originTime!, journey.points.count < 50_000 else { return }
        if let last = journey.points.last, last.segment == segment, last.position.distance(to: camera) < 0.4 { return }
        if let last = journey.points.last, last.segment == segment { distance += last.position.distance(to: camera) }
        journey.points.append(JourneyPoint(seconds: time - originTime!, position: camera, segment: segment))
    }
}
