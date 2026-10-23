import Foundation
import CoreFoundation

/// Deterministic output gates for OpenCV local-feature evidence. Scores are NOT
/// probabilities. This does not identify a note, authenticate cash or prove that
/// an unknown/overlapping second note is absent. Only a reviewed build may speak a value.
public enum SaudiBanknoteReferencePolicy {
    public enum Algorithm: String, Codable, Sendable { case sift, orb, akaze }
    public static let labels = [1, 5, 10, 20, 50, 100, 200, 500]
    public enum Limits {
        public static let references = 48, manifestBytes = 256 * 1024, imageBytes = 8 * 1024 * 1024
        public static let totalReferenceBytes = 96 * 1024 * 1024, sourceSide = 4096, sourcePixels = 8_000_000
        public static let querySide = 1200, referenceSide = 800, features = 1800, regionsPerReference = 2
    }
    /// Frozen experimental defaults ported from reference_match.py, not calibrated
    /// currency thresholds. Altering any setting requires a new evaluation/profile.
    public struct Thresholds: Equatable, Sendable {
        public let ratioTest, ransacError, minimumInlierRatio, minimumReferenceSpread, minimumQuerySpread: Double
        public let minimumArea, maximumArea, minimumAngle, maximumAngle, maximumEdgeRatio: Double
        public let maximumOppositeEdgeRatio, maximumProjectiveRatio, maximumMedianError: Double
        public let minimumScore, differentLabelRatio, differentLabelGap, distinctRegionOverlap, minimumProposalOverlap: Double
        public let ransacIterations, minimumInliers, minimumGridCells: Int
        public init(ratioTest: Double, ransacError: Double, ransacIterations: Int, minimumInliers: Int,
                    minimumInlierRatio: Double, minimumReferenceSpread: Double, minimumQuerySpread: Double,
                    minimumGridCells: Int, minimumArea: Double, maximumArea: Double, minimumAngle: Double,
                    maximumAngle: Double, maximumEdgeRatio: Double, maximumOppositeEdgeRatio: Double,
                    maximumProjectiveRatio: Double, maximumMedianError: Double, minimumScore: Double,
                    differentLabelRatio: Double, differentLabelGap: Double, distinctRegionOverlap: Double, minimumProposalOverlap: Double = 0.80) {
            self.ratioTest = ratioTest; self.ransacError = ransacError; self.ransacIterations = ransacIterations
            self.minimumInliers = minimumInliers; self.minimumInlierRatio = minimumInlierRatio
            self.minimumReferenceSpread = minimumReferenceSpread; self.minimumQuerySpread = minimumQuerySpread
            self.minimumGridCells = minimumGridCells; self.minimumArea = minimumArea; self.maximumArea = maximumArea
            self.minimumAngle = minimumAngle; self.maximumAngle = maximumAngle; self.maximumEdgeRatio = maximumEdgeRatio
            self.maximumOppositeEdgeRatio = maximumOppositeEdgeRatio; self.maximumProjectiveRatio = maximumProjectiveRatio
            self.maximumMedianError = maximumMedianError; self.minimumScore = minimumScore
            self.differentLabelRatio = differentLabelRatio; self.differentLabelGap = differentLabelGap
            self.distinctRegionOverlap = distinctRegionOverlap; self.minimumProposalOverlap = minimumProposalOverlap
        }
        public static let experimental = Thresholds(ratioTest: 0.72, ransacError: 3, ransacIterations: 1500,
            minimumInliers: 14, minimumInlierRatio: 0.42, minimumReferenceSpread: 0.20, minimumQuerySpread: 0.20,
            minimumGridCells: 5, minimumArea: 0.04, maximumArea: 0.90, minimumAngle: 25, maximumAngle: 155,
            maximumEdgeRatio: 6, maximumOppositeEdgeRatio: 3, maximumProjectiveRatio: 3,
            maximumMedianError: 2.5, minimumScore: 7, differentLabelRatio: 1.6, differentLabelGap: 4,
            distinctRegionOverlap: 0.25)
        public var valid: Bool {
            let positive = [ratioTest, ransacError, minimumInlierRatio, minimumReferenceSpread, minimumQuerySpread,
                minimumArea, maximumArea, minimumAngle, maximumAngle, maximumEdgeRatio, maximumOppositeEdgeRatio,
                maximumProjectiveRatio, maximumMedianError, minimumScore, differentLabelRatio, differentLabelGap,
                distinctRegionOverlap, minimumProposalOverlap]
            return positive.allSatisfy { $0.isFinite && $0 > 0 } && ratioTest < 1 && ransacError <= 20
                && (1...5000).contains(ransacIterations) && (4...Limits.features).contains(minimumInliers)
                && minimumInlierRatio <= 1 && minimumReferenceSpread <= 1 && minimumQuerySpread <= 1
                && (1...9).contains(minimumGridCells) && minimumArea < maximumArea && maximumArea < 1
                && minimumAngle < maximumAngle && maximumAngle < 180 && maximumEdgeRatio >= 1
                && maximumOppositeEdgeRatio >= 1 && maximumProjectiveRatio >= 1
                && differentLabelRatio > 1 && distinctRegionOverlap <= 1 && minimumProposalOverlap <= 1
        }
    }
    public struct Point: Codable, Equatable, Sendable {
        public let x, y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }
    }
    /// Native computed evidence only. No confidence or class probabilities exist.
    public struct Candidate: Sendable {
        public let referenceID: String, label: Int, regionIndex: Int
        public let ratioMatches, inliers, gridCells: Int
        public let inlierRatio, score, areaFraction, referenceSpread, querySpread: Double
        public let edgeRatio, oppositeEdgeRatio, projectiveRatio, medianError, minimumEdge: Double
        public let angles: [Double], quad: [Point]
        public let finiteHomography, convex, fullyInFrame: Bool
        public init(referenceID: String, label: Int, regionIndex: Int, ratioMatches: Int, inliers: Int,
                    gridCells: Int, inlierRatio: Double, score: Double, areaFraction: Double,
                    referenceSpread: Double, querySpread: Double, edgeRatio: Double,
                    oppositeEdgeRatio: Double, projectiveRatio: Double, medianError: Double,
                    minimumEdge: Double, angles: [Double], quad: [Point], finiteHomography: Bool,
                    convex: Bool, fullyInFrame: Bool) {
            self.referenceID = referenceID; self.label = label; self.regionIndex = regionIndex
            self.ratioMatches = ratioMatches; self.inliers = inliers; self.gridCells = gridCells
            self.inlierRatio = inlierRatio; self.score = score; self.areaFraction = areaFraction
            self.referenceSpread = referenceSpread; self.querySpread = querySpread; self.edgeRatio = edgeRatio
            self.oppositeEdgeRatio = oppositeEdgeRatio; self.projectiveRatio = projectiveRatio
            self.medianError = medianError; self.minimumEdge = minimumEdge; self.angles = angles; self.quad = quad
            self.finiteHomography = finiteHomography; self.convex = convex; self.fullyInFrame = fullyInFrame
        }
    }
    public struct FrameProposal: Sendable {
        /// Full-frame Vision TL/TR/BR/BL corners, normalized top-left origin.
        public let corners: [Point]
        public init(corners: [Point]) { self.corners = corners }
        public init(x: Double, y: Double, width: Double, height: Double) {
            corners = [.init(x:x,y:y), .init(x:x+width,y:y),
                       .init(x:x+width,y:y+height), .init(x:x,y:y+height)]
        }
        var valid: Bool {
            corners.count == 4 && corners.allSatisfy { $0.x.isFinite && $0.y.isFinite &&
                (0...1.000001).contains($0.x) && (0...1.000001).contains($0.y) } && clockwiseConvex(corners)
        }
    }
    public struct Evidence: Sendable {
        public let candidates: [Candidate]
        /// Row-major n*n intersection/min(areaA,areaB), from cv::intersectConvexConvex.
        public let overlaps: [Double]
        public let queryWidth, queryHeight: Int
        public let frameProposals: [FrameProposal]
        public init(candidates: [Candidate], overlaps: [Double], queryWidth: Int, queryHeight: Int, frameProposals: [FrameProposal]) {
            self.candidates = candidates; self.overlaps = overlaps
            self.queryWidth = queryWidth; self.queryHeight = queryHeight; self.frameProposals = frameProposals
        }
    }
    /// Source-reviewed, immutable activation evidence. Strings are audit references,
    /// not automatic proof of accuracy. The app's selected production profile is nil.
    public struct ReleaseApproval: Sendable {
        public let evaluationIdentifier, calibrationIdentifier, referencePackSHA256: String
        public let humanReviewed, wholeFrameAcceptanceReviewed, appleDeviceAcceptanceReviewed: Bool
        public init(evaluationIdentifier: String, calibrationIdentifier: String, referencePackSHA256: String,
                    humanReviewed: Bool, wholeFrameAcceptanceReviewed: Bool, appleDeviceAcceptanceReviewed: Bool) {
            self.evaluationIdentifier = evaluationIdentifier; self.calibrationIdentifier = calibrationIdentifier
            self.referencePackSHA256 = referencePackSHA256; self.humanReviewed = humanReviewed
            self.wholeFrameAcceptanceReviewed = wholeFrameAcceptanceReviewed
            self.appleDeviceAcceptanceReviewed = appleDeviceAcceptanceReviewed
        }
        public var valid: Bool {
            validText(evaluationIdentifier) && validText(calibrationIdentifier) && validSHA(referencePackSHA256)
                && humanReviewed && wholeFrameAcceptanceReviewed && appleDeviceAcceptanceReviewed
        }
    }
    /// Explicit developer-device testing permission, not a release approval,
    /// human review, calibration result or claim of recognition reliability.
    /// The app must additionally restrict selection to its device-test Debug
    /// build and verify these exact manifest bytes before loading references.
    public struct DeviceTestAuthorization: Sendable {
        public let referencePackSHA256: String
        public init(referencePackSHA256: String) { self.referencePackSHA256 = referencePackSHA256 }
        public var valid: Bool { validSHA(referencePackSHA256) }
    }
    public enum ExperimentalDecision: Equatable, Sendable {
        case unknown, multiple, clipped, tooSmall, hypothesis(Int)
    }
    public static func decide(_ evidence: Evidence, thresholds: Thresholds,
                              approval: ReleaseApproval?) -> SaudiBanknotePolicy.Result {
        guard let approval, approval.valid else { return .unknown }
        switch experimentalDecision(evidence, thresholds: thresholds) {
        case .unknown: return .unknown
        case .multiple: return .multiple
        case .clipped: return .clipped
        case .tooSmall: return .tooSmall
        case .hypothesis(let label): return .denomination(label)
        }
    }
    /// Separate, explicitly authorized device-test output using the same frozen
    /// geometry, secondary-scene veto, proposal and competing-label gates. Never
    /// manufacture ReleaseApproval to exercise this path. The production decide
    /// entry point remains unchanged and still requires its full release evidence.
    public static func decideForDeviceTest(_ evidence: Evidence, thresholds: Thresholds = .experimental,
                                           authorization: DeviceTestAuthorization?) -> SaudiBanknotePolicy.Result {
        guard let authorization, authorization.valid, thresholds == .experimental else { return .unknown }
        switch experimentalDecision(evidence, thresholds: thresholds) {
        case .unknown: return .unknown
        case .multiple: return .multiple
        case .clipped: return .clipped
        case .tooSmall: return .tooSmall
        case .hypothesis(let label): return .denomination(label)
        }
    }
    /// Shared deterministic experiment, not release validation or profile calibration.
    /// App output requires one of the explicit authorization entry points above.
    public static func experimentalDecision(_ e: Evidence, thresholds t: Thresholds = .experimental) -> ExperimentalDecision {
        guard t.valid, e.frameProposals.count <= 32, e.frameProposals.allSatisfy(\.valid) else { return .unknown }
        // Reference matches alone miss unrecognized notes/composite images. Rectangle
        // proposals are an additional veto, not proof that all notes were detected.
        guard !e.frameProposals.isEmpty else { return .unknown }
        guard e.frameProposals.count == 1 else { return .multiple }
        guard (32...Limits.querySide).contains(e.queryWidth), (32...Limits.querySide).contains(e.queryHeight),
              !e.candidates.isEmpty, e.candidates.count <= Limits.references * Limits.regionsPerReference,
              e.overlaps.count == e.candidates.count * e.candidates.count else { return .unknown }
        let n = e.candidates.count
        var keys = Set<String>()
        var referenceLabels: [String: Int] = [:]
        for (i, c) in e.candidates.enumerated() {
            guard validCandidate(c), keys.insert("\(c.referenceID):\(c.regionIndex)").inserted,
                  referenceLabels[c.referenceID] == nil || referenceLabels[c.referenceID] == c.label else { return .unknown }
            referenceLabels[c.referenceID] = c.label
            for j in 0..<n {
                let overlap = e.overlaps[i*n+j]
                guard overlap.isFinite, (0...1).contains(overlap), abs(overlap-e.overlaps[j*n+i]) < 1e-6,
                      i != j || abs(overlap-1) < 1e-6 else { return .unknown }
            }
        }
        guard referenceLabels.count <= Limits.references else { return .unknown }
        let accepted = e.candidates.indices.filter { passes(e.candidates[$0], t, framing: true) }
        for (index, i) in accepted.enumerated() {
            for j in accepted.dropFirst(index+1) where e.overlaps[i*n+j] < t.distinctRegionOverlap { return .multiple }
        }
        // Veto only: a partially occluded candidate may fail spatial spread/grid
        // coverage, but must retain every other numeric, geometry and framing gate.
        // This cannot promote that candidate or replace the existing score margin.
        // Coincident alternate references (including different labels sharing print
        // patterns) are not proof of a second note. Distinct extracted regions from
        // one reference, or noncoincident polygon boundaries, block a value instead.
        let supported = e.candidates.indices.filter {
            passes(e.candidates[$0], t, framing: true, requireSpatialSupport: false)
        }
        for i in accepted {
            let a = e.candidates[i]
            for j in supported where i != j {
                let b = e.candidates[j]
                if a.referenceID == b.referenceID && a.regionIndex != b.regionIndex { return .multiple }
                guard let overlap = polygonIoU(a.quad, b.quad) else { return .unknown }
                if overlap < t.minimumProposalOverlap { return .multiple }
            }
        }
        // Shared motifs can still cause false abstentions. This bounded veto cannot
        // recover matches discarded inside the first extracted quad or detect an
        // invisible/unsupported second note. It is not single-note proof.
        // Keep all failed candidates as competitors too. Never pick a weaker accepted
        // result when the highest score failed geometry. Same-label sides don't compete.
        var byLabel: [Int: Candidate] = [:]
        for c in e.candidates where byLabel[c.label] == nil || c.score > byLabel[c.label]!.score { byLabel[c.label] = c }
        let ranked = byLabel.values.sorted { $0.score == $1.score ? $0.label < $1.label : $0.score > $1.score }
        guard let best = ranked.first, passes(best, t, framing: false) else { return .unknown }
        let runner = ranked.dropFirst().first?.score ?? 0
        guard runner == 0 || (best.score-runner >= t.differentLabelGap && best.score/runner >= t.differentLabelRatio) else { return .unknown }
        guard agreesWithProposal(best, e, t) else { return .unknown }
        if !best.fullyInFrame { return .clipped }
        if best.areaFraction < t.minimumArea { return .tooSmall }
        guard passes(best, t, framing: true) else { return .unknown }
        return .hypothesis(best.label)
    }
    private static func agreesWithProposal(_ c: Candidate, _ e: Evidence, _ t: Thresholds) -> Bool {
        guard c.quad.count == 4, let p = e.frameProposals.first else { return false }
        let quad = c.quad.map { Point(x:$0.x/Double(e.queryWidth),y:$0.y/Double(e.queryHeight)) }
        guard let overlap = polygonIoU(quad, p.corners) else { return false }
        return overlap >= t.minimumProposalOverlap
    }
    private static func cross(_ a: Point, _ b: Point, _ p: Point) -> Double {
        (b.x-a.x)*(p.y-a.y)-(b.y-a.y)*(p.x-a.x)
    }
    private static func clockwiseConvex(_ points: [Point]) -> Bool {
        points.count == 4 && (0..<4).allSatisfy { cross(points[$0],points[($0+1)%4],points[($0+2)%4]) > 1e-12 }
    }
    private static func polygonArea(_ points: [Point]) -> Double {
        guard points.count >= 3 else { return 0 }
        return abs(points.indices.reduce(0) { result,i in
            let next=points[(i+1)%points.count]
            return result+points[i].x*next.y-points[i].y*next.x
        })/2
    }
    /// Standard bounded Sutherland-Hodgman clipping for two convex quadrilaterals.
    /// This compares two measured proposals; it is not a detector/recognizer.
    /// Preserve corners: equal bounding boxes do not imply equal tilted note regions.
    private static func polygonIoU(_ subject: [Point], _ clip: [Point]) -> Double? {
        guard clockwiseConvex(subject), clockwiseConvex(clip) else { return nil }
        var intersection=subject
        for i in 0..<4 {
            guard !intersection.isEmpty else { return 0 }
            let a=clip[i], b=clip[(i+1)%4], input=intersection
            intersection=[]
            var previous=input.last!, previousDistance=cross(a,b,input.last!)
            for current in input {
                let distance=cross(a,b,current)
                if (distance >= 0) != (previousDistance >= 0) {
                    let denominator=previousDistance-distance
                    guard denominator.isFinite, abs(denominator)>1e-15 else { return nil }
                    let t=previousDistance/denominator
                    intersection.append(.init(x:previous.x+t*(current.x-previous.x), y:previous.y+t*(current.y-previous.y)))
                }
                if distance >= 0 { intersection.append(current) }
                previous=current; previousDistance=distance
            }
            guard intersection.count<=16, intersection.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        }
        let area=polygonArea(intersection), union=polygonArea(subject)+polygonArea(clip)-area
        guard union.isFinite, union>1e-12 else { return nil }
        return max(0,min(1,area/union))
    }
    private static func validCandidate(_ c: Candidate) -> Bool {
        let numbers = [c.inlierRatio, c.score, c.areaFraction, c.referenceSpread, c.querySpread,
                       c.edgeRatio, c.oppositeEdgeRatio, c.projectiveRatio, c.medianError, c.minimumEdge] + c.angles
        guard validText(c.referenceID), labels.contains(c.label), (0..<Limits.regionsPerReference).contains(c.regionIndex),
              (0...Limits.features).contains(c.ratioMatches), (0...c.ratioMatches).contains(c.inliers),
              (0...9).contains(c.gridCells), numbers.allSatisfy({ $0.isFinite && $0 >= 0 }),
              c.quad.allSatisfy({ $0.x.isFinite && $0.y.isFinite }), (0...1).contains(c.inlierRatio),
              c.referenceSpread <= 1.00001, (c.quad.count == 0 || c.quad.count == 4),
              (c.angles.count == 0 || c.angles.count == 4) else { return false }
        let ratio = c.ratioMatches == 0 ? 0 : Double(c.inliers)/Double(c.ratioMatches)
        let expected = Double(c.inliers) * ratio * sqrt(max(0, min(c.referenceSpread, c.querySpread, 1)))
        return abs(c.inlierRatio-ratio) < 1e-6 && abs(c.score-expected) <= max(1e-6, expected * 1e-5)
    }
    private static func passes(_ c: Candidate, _ t: Thresholds, framing: Bool,
                               requireSpatialSupport: Bool = true) -> Bool {
        c.finiteHomography && c.convex && c.quad.count == 4 && c.angles.count == 4
            && c.inliers >= t.minimumInliers && c.inlierRatio >= t.minimumInlierRatio && c.score >= t.minimumScore
            && (!requireSpatialSupport || (c.referenceSpread >= t.minimumReferenceSpread
                && c.querySpread >= t.minimumQuerySpread && c.gridCells >= t.minimumGridCells))
            && c.minimumEdge >= 8
            && c.edgeRatio <= t.maximumEdgeRatio && c.oppositeEdgeRatio <= t.maximumOppositeEdgeRatio
            && c.projectiveRatio <= t.maximumProjectiveRatio && c.medianError <= t.maximumMedianError
            && c.angles.allSatisfy { $0 >= t.minimumAngle && $0 <= t.maximumAngle }
            && c.areaFraction <= t.maximumArea && (!framing || (c.fullyInFrame && c.areaFraction >= t.minimumArea))
    }
    public static func validText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= 256
            && !text.unicodeScalars.contains(where: { $0.value < 32 })
    }
    public static func validSHA(_ text: String) -> Bool {
        text.utf8.count == 64 && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

/// Private runtime pack v2. Unlike the experiment's v1 image-only manifest this
/// requires reviewed, source-pixel note boundaries. Backgrounds cannot be templates.
/// Hashes pin bytes, not the truth of a label, a review assertion or image rights.
public struct SaudiBanknoteReferencePack: Sendable {
    public struct Reference: Sendable {
        public let id, path, sha256, side, issue, material, physicalNoteID, captureSessionID, source, rights: String
        public let label, sourceWidth, sourceHeight: Int
        public let boundary: [SaudiBanknoteReferencePolicy.Point]
        public let verificationKind: String
    }
    public enum Invalid: Error { case manifest }
    public let references: [Reference]
    public var allHumanReviewed: Bool { !references.isEmpty && references.allSatisfy { $0.verificationKind == "human_review" } }
    /// Minimum coverage only, not proof of all issue/design coverage or generalization.
    public var minimumCoverage: Bool {
        SaudiBanknoteReferencePolicy.labels.allSatisfy { label in ["front", "back"].allSatisfy { side in
            references.contains { $0.label == label && $0.side == side }
        }} && ["paper", "polymer"].allSatisfy { material in ["front", "back"].allSatisfy { side in
            references.contains { $0.label == 5 && $0.material == material && $0.side == side }
        }}
    }
    /// Limited developer-device test inventory only: exactly one paper front and
    /// back for each of the eight labels. This does NOT satisfy production coverage
    /// (notably polymer 5), certify every issue/design, or turn assistant review
    /// into human review. The ordinary minimumCoverage/allHumanReviewed stay intact.
    public var deviceTestCoverage: Bool {
        references.count == SaudiBanknoteReferencePolicy.labels.count * 2
            && references.allSatisfy { $0.material == "paper" &&
                ["assistant_visual_review", "human_review"].contains($0.verificationKind) }
            && SaudiBanknoteReferencePolicy.labels.allSatisfy { label in ["front", "back"].allSatisfy { side in
                references.filter { $0.label == label && $0.side == side }.count == 1
            }}
    }
    public static func safeRelativePath(_ path: String) -> Bool {
        SaudiBanknoteReferencePolicy.validText(path) && !path.hasPrefix("/") && !path.contains("\\")
            && !path.contains(":") && !path.contains("%") && path.split(separator: "/", omittingEmptySubsequences: false)
                .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
    public static func parse(_ data: Data) throws -> Self {
        typealias P = SaudiBanknoteReferencePolicy
        guard !data.isEmpty, data.count <= P.Limits.manifestBytes else { throw Invalid.manifest }
        let raw = try JSONSerialization.jsonObject(with: data)
        try rejectDuplicateKeys(data)
        func object(_ value: Any?, _ keys: Set<String>) throws -> [String: Any] {
            guard let result = value as? [String: Any], Set(result.keys) == keys else { throw Invalid.manifest }
            return result
        }
        func text(_ value: Any?) throws -> String {
            guard let result = value as? String, P.validText(result) else { throw Invalid.manifest }; return result
        }
        func number(_ value: Any?) throws -> Double {
            guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite else { throw Invalid.manifest }
            return n.doubleValue
        }
        func integer(_ value: Any?) throws -> Int {
            let n = try number(value)
            guard let boxed = value as? NSNumber, !["f", "d"].contains(String(cString: boxed.objCType)),
                  n.rounded() == n, n >= 0, n <= 8_000_000 else { throw Invalid.manifest }
            return Int(n)
        }
        let root = try object(raw, ["schema_version", "reference_kind", "currency", "labels", "references"])
        guard try integer(root["schema_version"]) == 2, root["reference_kind"] as? String == "private_banknote_photos",
              root["currency"] as? String == "SAR", let rawLabels = root["labels"] as? [Any],
              try rawLabels.map({ try integer($0) }) == P.labels, let rows = root["references"] as? [Any],
              rows.count <= P.Limits.references else { throw Invalid.manifest }
        var refs: [Reference] = [], ids = Set<String>(), hashes = Set<String>()
        for row in rows {
            let r = try object(row, ["id", "path", "sha256", "label", "side", "issue", "material", "physical_note_id",
                "capture_session_id", "source", "rights", "verification", "boundary"])
            let id = try text(r["id"]), path = try text(r["path"]), sha = try text(r["sha256"])
            let side = try text(r["side"]), material = try text(r["material"]), label = try integer(r["label"])
            guard ids.insert(id).inserted, hashes.insert(sha).inserted, P.validSHA(sha), safeRelativePath(path),
                  P.labels.contains(label), ["front", "back"].contains(side), ["paper", "polymer"].contains(material) else { throw Invalid.manifest }
            let review = try object(r["verification"], ["verified", "verification_kind", "verified_by", "verified_on", "method"])
            guard let verified = review["verified"] as? NSNumber, CFGetTypeID(verified) == CFBooleanGetTypeID(), verified.boolValue,
                  let kind = review["verification_kind"] as? String, ["human_review", "assistant_visual_review"].contains(kind) else { throw Invalid.manifest }
            _ = try text(review["verified_by"]); _ = try text(review["method"])
            let date = try text(review["verified_on"])
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
            guard let parsedDate = formatter.date(from: date), formatter.string(from: parsedDate) == date else { throw Invalid.manifest }
            let b = try object(r["boundary"], ["source_size", "corners_tl_tr_br_bl"])
            guard let size = b["source_size"] as? [Any], size.count == 2,
                  let corners = b["corners_tl_tr_br_bl"] as? [[Any]], corners.count == 4 else { throw Invalid.manifest }
            let w = try integer(size[0]), h = try integer(size[1])
            guard (32...P.Limits.sourceSide).contains(w), (32...P.Limits.sourceSide).contains(h), w*h <= P.Limits.sourcePixels else { throw Invalid.manifest }
            let boundary = try corners.map { point -> P.Point in
                guard point.count == 2 else { throw Invalid.manifest }
                let x = try number(point[0]), y = try number(point[1])
                guard x >= 0, y >= 0, x <= Double(w-1), y <= Double(h-1) else { throw Invalid.manifest }
                return .init(x: x, y: y)
            }
            // OpenCV repeats convexity, size and foreshortening validation before warp.
            for i in 0..<4 {
                let a = boundary[i], b = boundary[(i+1)%4], c = boundary[(i+2)%4]
                guard (b.x-a.x)*(c.y-b.y)-(b.y-a.y)*(c.x-b.x) > 0 else { throw Invalid.manifest }
            }
            refs.append(Reference(id: id, path: path, sha256: sha, side: side, issue: try text(r["issue"]), material: material,
                physicalNoteID: try text(r["physical_note_id"]), captureSessionID: try text(r["capture_session_id"]),
                source: try text(r["source"]), rights: try text(r["rights"]), label: label, sourceWidth: w,
                sourceHeight: h, boundary: boundary, verificationKind: kind))
        }
        return Self(references: refs)
    }
    // JSONSerialization supplies syntax/number/string decoding. This bounded token
    // pass adds duplicate-key rejection, including equivalent escaped key spellings.
    private static func rejectDuplicateKeys(_ data: Data) throws {
        let bytes = [UInt8](data)
        struct Frame { let object: Bool; var keys = Set<String>(); var wantsKey: Bool }
        var stack: [Frame] = [], i = 0
        while i < bytes.count {
            switch bytes[i] {
            case 123: stack.append(Frame(object: true, wantsKey: true)); i += 1
            case 91: stack.append(Frame(object: false, wantsKey: false)); i += 1
            case 125, 93: guard !stack.isEmpty else { throw Invalid.manifest }; stack.removeLast(); i += 1
            case 44: if !stack.isEmpty && stack[stack.count-1].object { stack[stack.count-1].wantsKey = true }; i += 1
            case 34:
                let start = i; i += 1
                while i < bytes.count && bytes[i] != 34 { if bytes[i] == 92 { i += 1 }; i += 1 }
                guard i < bytes.count else { throw Invalid.manifest }; i += 1
                if !stack.isEmpty && stack[stack.count-1].object && stack[stack.count-1].wantsKey {
                    let key = try JSONSerialization.jsonObject(with: Data(bytes[start..<i]), options: .fragmentsAllowed) as? String
                    guard let key, stack[stack.count-1].keys.insert(key).inserted else { throw Invalid.manifest }
                    stack[stack.count-1].wantsKey = false
                }
            default: i += 1
            }
            guard stack.count <= 16 else { throw Invalid.manifest }
        }
    }
}
