// Research-only partial reference; NOT author code or movement authority.
// P/E references resolve to SPECIFICATION.md. No ARKit/app/network dependencies.
import Foundation

public struct Vector: Equatable {
    public var x: Double, y: Double, z: Double
    public init(_ x: Double, _ y: Double, _ z: Double) { self.x=x; self.y=y; self.z=z }
    public var finite: Bool { x.isFinite && y.isFinite && z.isFinite }
    public func dot(_ b: Vector) -> Double { x*b.x + y*b.y + z*b.z }
    public static func - (a: Vector, b: Vector) -> Vector { Vector(a.x-b.x,a.y-b.y,a.z-b.z) }
    public static prefix func - (a: Vector) -> Vector { Vector(-a.x,-a.y,-a.z) }
    public func unit() -> Vector? {
        let n = sqrt(dot(self))
        guard finite, n.isFinite, n > 0 else { return nil }
        return Vector(x/n,y/n,z/n)
    }
}
public enum Ray: String, CaseIterable { case forward, left, right, up, down1, down2, lower, floorDetector }
public enum Surface { case floor, wall, ceiling, other, unclassified }
public enum Tracking { case normal, limited, unavailable }
public struct Hit {
    public let position: Vector
    public let surface: Surface
    public let frameIndex: Int
    public let timestamp: Double
    public let coordinateFrame: String
    public init(position: Vector, surface: Surface, frameIndex: Int, timestamp: Double, coordinateFrame: String) {
        self.position=position; self.surface=surface; self.frameIndex=frameIndex
        self.timestamp=timestamp; self.coordinateFrame=coordinateFrame
    }
}
public struct Frame {
    public let index: Int
    public let timestamp: Double
    public let coordinateFrame: String
    public let tracking: Tracking
    // Caller-validated pose quality. No invented displacement/jitter threshold.
    public let poseAccepted: Bool
    public let origin: Vector
    public let forward: Vector
    public let gravity: Vector
    public let hits: [Ray: Hit]
    public init(index: Int, timestamp: Double, coordinateFrame: String, tracking: Tracking,
                poseAccepted: Bool, origin: Vector, forward: Vector, gravity: Vector, hits: [Ray: Hit]) {
        self.index=index; self.timestamp=timestamp; self.coordinateFrame=coordinateFrame
        self.tracking=tracking; self.poseAccepted=poseAccepted; self.origin=origin
        self.forward=forward; self.gravity=gravity; self.hits=hits
    }
}
public enum Pair: CaseIterable { case down2Floor, forwardLower, down1Down2 }
public enum EndpointOrder { case namedFirstToSecond, namedSecondToFirst }
public struct Interpretation {
    // Required: paper does not identify directed endpoint order. No default.
    public let down2Floor: EndpointOrder
    public let forwardLower: EndpointOrder
    public let down1Down2: EndpointOrder
    public init(down2Floor: EndpointOrder, forwardLower: EndpointOrder, down1Down2: EndpointOrder) {
        self.down2Floor=down2Floor; self.forwardLower=forwardLower; self.down1Down2=down1Down2
    }
    func order(_ pair: Pair) -> EndpointOrder {
        switch pair { case .down2Floor: return down2Floor; case .forwardLower: return forwardLower; case .down1Down2: return down1Down2 }
    }
}
public struct PairEvidence {
    public let pair: Pair
    public let tiltDegrees: Double
    public let verticalSpanMeters: Double
    public let forwardDot: Double
    public let qualifiesUnderExperimentalRules: Bool
}
public enum Branch<T> { case unknown(String), observed(T) }
public enum AscendingKind: Equatable { case wall, trippingHazard, staircase, noCandidateInSuppliedRays }
public struct AscendingEvidence {
    public let lowerTilt: Double
    public let upperTilt: Double
    public let kind: AscendingKind
}
public struct DescendingEvidence {
    public let pairs: [PairEvidence]
    public var candidate: Bool { pairs.filter { $0.qualifiesUnderExperimentalRules }.count >= 2 }
}
public struct FloorSummary {
    public let ray: Ray
    public let count: Int
    public let median: Double
    // Population variance is E diagnostic only, NOT author's confidence.
    public let populationVariance: Double
}
// E diagnostic tolerance only; does NOT time-normalize the 180-frame counter.
public enum CadenceObservation: Equatable {
    case unknown
    case nominal60HzWithinExperimentalTolerance
    case differentObservedCadence
}
public struct Output {
    public let ascending: Branch<AscendingEvidence>
    public let descending: Branch<DescendingEvidence>
    public let floor: [FloorSummary]
    public let floorIncompleteReason: String?
    public let cadence: CadenceObservation
    public let incompleteReason: String?
    public let descendingResearchMarker: Bool
    public let persistenceFrames: Int
    public let frameIntervalSeconds: Double?
    public let secondsSinceLastMarker: Double?
    // There is deliberately no clear/safe/direction/command property.
}
public final class ReferenceCore {
    private let interpretation: Interpretation
    private var previous: Frame?
    private var floorUp: Vector?
    private var floorSamples: [[Ray: Double]] = []
    private var persistence = 0
    private var lastMarker: (index: Int, time: Double)?
    public init(interpretation: Interpretation) { self.interpretation=interpretation }

    private func validHit(_ ray: Ray, _ frame: Frame) -> Hit? {
        guard let h=frame.hits[ray], h.position.finite, h.frameIndex == frame.index,
              h.timestamp == frame.timestamp, h.coordinateFrame == frame.coordinateFrame else { return nil }
        return h
    }
    private func tilt(_ segment: Vector, gravity: Vector) -> Double? {
        guard let s=segment.unit(), let g=gravity.unit() else { return nil }
        return acos(min(1, max(0, abs(s.dot(g))))) * 180 / .pi
    }
    private func ascending(_ f: Frame) -> Branch<AscendingEvidence> {
        guard let l=validHit(.lower,f), let w=validHit(.forward,f), let u=validHit(.up,f),
              let a=tilt(w.position-l.position,gravity:f.gravity),
              let b=tilt(u.position-w.position,gravity:f.gravity) else {
            return .unknown("missing/invalid ascending hit or degenerate segment")
        }
        let kind: AscendingKind
        // P06 wall-first precedence; no confidence formula manufactured.
        if b <= 25 { kind = .wall }
        else if b >= 65 && (10...50).contains(a) { kind = .trippingHazard }
        else if (10...50).contains(a) && (10...50).contains(b) && abs(a-b) <= 15 { kind = .staircase }
        else { kind = .noCandidateInSuppliedRays }
        return .observed(AscendingEvidence(lowerTilt:a,upperTilt:b,kind:kind))
    }
    private func descending(_ f: Frame) -> Branch<DescendingEvidence> {
        guard let forward=f.forward.unit(), let gravity=f.gravity.unit() else { return .unknown("invalid axes") }
        let pairs: [(Pair,Ray,Ray)] = [(.down2Floor,.down2,.floorDetector),(.forwardLower,.forward,.lower),(.down1Down2,.down1,.down2)]
        var evidence: [PairEvidence] = []
        for (id,a,b) in pairs {
            guard let ha=validHit(a,f), let hb=validHit(b,f) else { return .unknown("missing/invalid descending hit") }
            var d=hb.position-ha.position
            if interpretation.order(id) == .namedSecondToFirst { d = -d }
            guard let unit=d.unit(), let angle=tilt(d,gravity:gravity) else { return .unknown("degenerate descending segment") }
            let span=abs(d.dot(gravity)), dot=unit.dot(forward)
            // P03 first-pair rule generalized to all pairs as explicit E restriction.
            evidence.append(PairEvidence(pair:id,tiltDegrees:angle,verticalSpanMeters:span,forwardDot:dot,
                qualifiesUnderExperimentalRules: span >= 0.04 && dot < 0 && (5...50).contains(angle)))
        }
        return .observed(DescendingEvidence(pairs:evidence))
    }
    private func floor(_ f: Frame) -> Branch<[FloorSummary]> {
        if floorUp == nil, let gravity=f.gravity.unit() { floorUp = -gravity }
        guard let up=floorUp else { return .unknown("floor projection unavailable") }
        var samples: [Ray:Double] = [:]
        for ray in [Ray.floorDetector,.down1,.down2,.lower] {
            if let hit=validHit(ray,f), hit.surface == .floor {
                let height=hit.position.dot(up)
                guard height.isFinite else { return .unknown("nonfinite derived floor projection") }
                samples[ray]=height
            }
        }
        floorSamples.append(samples)
        if floorSamples.count > 30 { floorSamples.removeFirst() }
        var summaries: [FloorSummary] = []
        for ray in [Ray.floorDetector,.down1,.down2,.lower] {
            let values=floorSamples.compactMap { $0[ray] }.sorted()
            guard !values.isEmpty else { continue }
            let n=values.count, middle=n/2
            let median=n%2 == 0 ? values[middle-1]/2+values[middle]/2 : values[middle]
            let mean=values.reduce(0,+)/Double(n)
            let variance=values.reduce(0) { $0 + ($1-mean)*($1-mean) }/Double(n)
            guard median.isFinite, mean.isFinite, variance.isFinite else {
                return .unknown("nonfinite derived floor statistics")
            }
            summaries.append(FloorSummary(ray:ray,count:n,median:median,populationVariance:variance))
        }
        return .observed(summaries)
    }
    public func process(_ f: Frame) -> Output {
        let old=previous
        let changed=old.map { $0.coordinateFrame != f.coordinateFrame } ?? false
        let interval=old.map { f.timestamp-$0.timestamp }
        let ordered=old.map { f.index > $0.index && f.timestamp > $0.timestamp &&
            (f.timestamp-$0.timestamp).isFinite } ?? true
        let finiteInterval=interval.flatMap { $0.isFinite ? $0 : nil }
        let contiguous=old.map { $0.index < Int.max && f.index == $0.index+1 } ?? true
        let valid=f.index >= 0 && f.timestamp.isFinite && !f.coordinateFrame.isEmpty &&
            f.tracking == .normal && f.poseAccepted && f.origin.finite &&
            f.forward.unit() != nil && f.gravity.unit() != nil
        if changed { lastMarker=nil }
        if !valid || !ordered || changed {
            persistence=0; floorSamples=[]; floorUp=nil
            // Invalid/replayed frames cannot replace the accepted temporal watermark.
            if changed { previous = valid ? f : nil }
            let reason=changed ? "coordinate frame changed" : (!valid ? "invalid frame/tracking/pose/axes" : "nonmonotonic input")
            return Output(ascending:.unknown(reason),descending:.unknown(reason),floor:[],floorIncompleteReason:reason,cadence:.unknown,incompleteReason:reason,
                descendingResearchMarker:false,persistenceFrames:0,frameIntervalSeconds:finiteInterval,secondsSinceLastMarker:nil)
        }
        if !contiguous { persistence=0; floorSamples=[]; floorUp=nil }
        previous=f
        let cadence: CadenceObservation
        // E: absolute 1 microsecond interval tolerance, not a paper threshold.
        if old != nil, contiguous, let dt=finiteInterval, dt > 0 {
            cadence = abs(dt - 1.0/60.0) <= 0.000001
                ? .nominal60HzWithinExperimentalTolerance : .differentObservedCadence
        } else { cadence = .unknown }
        let asc=ascending(f), desc=descending(f)
        let floors: [FloorSummary]
        let floorIssue: String?
        switch floor(f) {
        case .observed(let summaries): floors=summaries; floorIssue=nil
        case .unknown(let reason):
            floors=[]; floorIssue=reason; floorSamples=[]; floorUp=nil
        }
        let candidate: Bool
        switch desc {
        case .observed(let e): candidate=e.candidate && floorIssue == nil
        case .unknown: candidate=false
        }
        persistence = candidate ? min(4,persistence+1) : 0
        // E boundary & accumulation; P05 only establishes four frames/3s nominal60Hz.
        let elapsed=lastMarker.flatMap { let dt=f.timestamp-$0.time; return dt.isFinite ? dt : nil }
        let eligible=lastMarker.map { f.index >= $0.index && f.index-$0.index >= 180 } ?? true
        let marker=candidate && persistence >= 4 && eligible
        if marker { lastMarker=(f.index,f.timestamp); persistence=0 }
        var reason: String? = validHit(.floorDetector,f) == nil ? "current floor detector unavailable" : nil
        if case .unknown(let s)=asc { reason=s }
        if case .unknown(let s)=desc { reason=s }
        if let issue=floorIssue { reason=issue }
        return Output(ascending:asc,descending:desc,floor:floors,floorIncompleteReason:floorIssue,
            cadence:cadence,incompleteReason:reason,
            descendingResearchMarker:marker,persistenceFrames:persistence,frameIntervalSeconds:finiteInterval,secondsSinceLastMarker:elapsed)
    }
}
