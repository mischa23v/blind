import XCTest
@testable import BlindCore

final class SaudiBanknoteReferencePolicyTests: XCTestCase {
    typealias P = SaudiBanknoteReferencePolicy
    private let proposal = P.FrameProposal(x: 0.2, y: 0.2, width: 0.6, height: 0.5)
    private func candidate(_ label: Int = 100, id: String = "ref-100", region: Int = 0,
                           inliers: Int = 30, matches: Int = 40, spread: Double = 0.5,
                           grid: Int = 8, area: Double = 0.3, convex: Bool = true,
                           inFrame: Bool = true, median: Double = 0.5, edgeRatio: Double = 2,
                           angles: [Double] = [90,90,90,90], quad: [P.Point]? = nil,
                           forcedScore: Double? = nil, poleFree: Bool = true) -> P.Candidate {
        let ratio = Double(inliers) / Double(matches)
        return .init(referenceID: id, label: label, regionIndex: region, ratioMatches: matches,
            inliers: inliers, gridCells: grid, inlierRatio: ratio,
            score: forcedScore ?? Double(inliers)*ratio*sqrt(spread), areaFraction: area,
            referenceSpread: spread, querySpread: spread, edgeRatio: edgeRatio, oppositeEdgeRatio: 1,
            projectiveRatio: 1, medianError: median, minimumEdge: 80, angles: angles,
            quad: quad ?? [.init(x: 200,y: 160), .init(x: 800,y: 160), .init(x: 800,y: 560), .init(x: 200,y: 560)],
            finiteHomography: poleFree, convex: convex, fullyInFrame: inFrame)
    }
    private func evidence(_ candidates: [P.Candidate], overlap: Double = 1,
                          proposals: [P.FrameProposal]? = nil, width: Int = 1000) -> P.Evidence {
        var overlaps = Array(repeating: overlap, count: candidates.count*candidates.count)
        for i in candidates.indices { overlaps[i*candidates.count+i] = 1 }
        return .init(candidates: candidates, overlaps: overlaps, queryWidth: width, queryHeight: 800,
                     frameProposals: proposals ?? [proposal])
    }
    private var approval: P.ReleaseApproval {
        .init(evaluationIdentifier: "SYNTHETIC-POLICY-FIXTURE-NOT-REAL-ACCEPTANCE", calibrationIdentifier: "fixture-only",
            referencePackSHA256: String(repeating: "a",count: 64), humanReviewed: true,
            wholeFrameAcceptanceReviewed: true, appleDeviceAcceptanceReviewed: true)
    }
    func testPassingMechanicsDoNotEnableMoneyWithoutApproval() {
        let e = evidence([candidate()])
        XCTAssertEqual(P.experimentalDecision(e), .hypothesis(100))
        XCTAssertEqual(P.decide(e, thresholds: .experimental, approval: nil), .unknown)
    }
    func testSourceApprovalGateIsExplicitAndScoresAreNotProbabilities() {
        XCTAssertGreaterThan(candidate().score, 1)
        XCTAssertEqual(P.decide(evidence([candidate()]), thresholds: .experimental, approval: approval), .denomination(100))
        let incomplete = P.ReleaseApproval(evaluationIdentifier: "fixture", calibrationIdentifier: "fixture",
            referencePackSHA256: String(repeating:"a", count:64), humanReviewed:true,
            wholeFrameAcceptanceReviewed:false, appleDeviceAcceptanceReviewed:true)
        XCTAssertEqual(P.decide(evidence([candidate()]),thresholds:.experimental,approval:incomplete),.unknown)
    }
    func testMissingRectanglesAndExtraUnknownRectangleAbstain() {
        XCTAssertEqual(P.experimentalDecision(evidence([candidate()],proposals:[])),.unknown)
        let extra = P.FrameProposal(x:0.01,y:0.01,width:0.1,height:0.1)
        XCTAssertEqual(P.experimentalDecision(evidence([candidate()],proposals:[proposal,extra])),.multiple)
    }
    func testCompositeSingleOuterRectangleDisagreesWithInnerMatchedNote() {
        let outer = P.FrameProposal(x:0.1,y:0.1,width:0.8,height:0.8)
        XCTAssertEqual(P.experimentalDecision(evidence([candidate()],proposals:[outer])),.unknown)
    }
    func testTiltedQuadMatchesOnlyItsPolygonNotSameBoundingBox() {
        let points:[P.Point]=[.init(x:500,y:160),.init(x:800,y:360),.init(x:500,y:560),.init(x:200,y:360)]
        let tilted=P.FrameProposal(corners:points.map { .init(x:$0.x/1000,y:$0.y/800) })
        let c=candidate(area:0.15,quad:points)
        XCTAssertEqual(P.experimentalDecision(evidence([c],proposals:[tilted])),.hypothesis(100))
        XCTAssertEqual(P.experimentalDecision(evidence([c],proposals:[proposal])),.unknown)
        let clockwiseRectangle=P.FrameProposal(corners:[.init(x:0.2,y:0.2),.init(x:0.2,y:0.7),.init(x:0.8,y:0.7),.init(x:0.8,y:0.2)])
        XCTAssertEqual(P.experimentalDecision(evidence([c],proposals:[clockwiseRectangle])),.unknown)
    }
    func testMultipleDisjointSameAndDifferentDenominationsReject() {
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(),candidate(100,id:"same-note",region:1)],overlap:0)),.multiple)
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(),candidate(5,id:"ref-5")],overlap:0.1)),.multiple)
    }
    func testSameLabelSidesDoNotCompeteAsDifferentDenominations() {
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(),candidate(100,id:"back",inliers:29)])),.hypothesis(100))
    }
    func testNoNearestWinsWithWeakEvidence() {
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(inliers:4)])),.unknown)
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(spread:0.01)])),.unknown)
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(grid:2)])),.unknown)
    }
    func testDifferentLabelRatioAndAbsoluteGapRequired() {
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(),candidate(1,id:"ref-1",inliers:28)])),.unknown)
        // A failed geometric competitor's raw evidence still competes.
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(),candidate(1,id:"ref-1",inliers:28,convex:false)])),.unknown)
    }
    func testStrongerFailedGeometryCannotFallBackToWeakerAcceptedLabel() {
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(inliers:24),candidate(1,id:"ref-1",inliers:36,convex:false)])),.unknown)
    }
    func testInvalidHomographyDistortionAndLocalFeatureClumpingReject() {
        for c in [candidate(poleFree:false),candidate(convex:false),candidate(median:3),candidate(edgeRatio:7),
                  candidate(angles:[10,90,90,170]),candidate(spread:0.19)] {
            XCTAssertEqual(P.experimentalDecision(evidence([c])),.unknown)
        }
    }
    func testMeasuredFramingResultsNeverSpeakDenomination() {
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(inFrame:false)])),.clipped)
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(area:0.03)])),.tooSmall)
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(area:0.95)])),.unknown)
        XCTAssertEqual(P.decide(evidence([candidate(inFrame:false)]),thresholds:.experimental,approval:nil),.unknown)
    }
    func testMalformedScoresLabelsCoordinatesAndBoundsReject() {
        for c in [candidate(forcedScore:.nan),candidate(forcedScore:100),candidate(999),candidate(region:2),
                  candidate(quad:[.init(x:.infinity,y:1)]),candidate(angles:[90])] {
            XCTAssertEqual(P.experimentalDecision(evidence([c])),.unknown)
        }
        XCTAssertEqual(P.experimentalDecision(evidence([candidate()],width:1201)),.unknown)
        XCTAssertEqual(P.experimentalDecision(evidence([candidate()],proposals:[.init(x:.nan,y:0,width:1,height:1)])),.unknown)
    }
    func testOverlapMatrixAndDuplicateHypothesisContractReject() {
        let c = candidate()
        XCTAssertEqual(P.experimentalDecision(.init(candidates:[c],overlaps:[],queryWidth:1000,queryHeight:800,frameProposals:[proposal])),.unknown)
        XCTAssertEqual(P.experimentalDecision(evidence([c,c])),.unknown)
        XCTAssertEqual(P.experimentalDecision(evidence([c,candidate(1,id:c.referenceID,region:1)])),.unknown)
        XCTAssertEqual(P.experimentalDecision(evidence([c,candidate(1,id:"different")],overlap:.nan)),.unknown)
        XCTAssertEqual(P.experimentalDecision(evidence(Array(repeating:c,count:97))),.unknown)
    }
    func testStrictPackRequiresBoundaryMetadataAndRejectsLegacyOrSynthetic() throws {
        let pack = try SaudiBanknoteReferencePack.parse(manifest())
        XCTAssertEqual(pack.references.count,1)
        XCTAssertTrue(pack.allHumanReviewed)
        XCTAssertFalse(pack.minimumCoverage)
        for update in ["schema_version":1,"reference_kind":"synthetic_mechanics"] {
            XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(rootChange:update)))
        }
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(recordChange:("boundary",NSNull()))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(recordChange:("label",true))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(recordChange:("label",1000))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(recordChange:("material","metal"))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(recordChange:("side","unknown"))))
    }
    func testStrictPackRejectsUnknownFieldsDuplicateKeysAndEscapedDuplicateKeys() throws {
        var object = try JSONSerialization.jsonObject(with:manifest()) as! [String:Any]
        object["unexpected"] = "ignored?"
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(JSONSerialization.data(withJSONObject:object)))
        let source = String(data:try manifest(),encoding:.utf8)!
        for duplicate in ["\"currency\":\"SAR\",", "\"curr\\u0065ncy\":\"SAR\","] {
            let changed = "{"+duplicate+source.dropFirst()
            XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(Data(changed.utf8)))
        }
    }
    func testPathsHashesSizesBoundariesAndReviewCannotBeMissingOrInvented() throws {
        for path in ["../note.png","/tmp/note.png","notes/../note.png","https://example.com/n.png","notes\\note.png","%2e%2e/note.png","a//b.png","./n.png"] {
            XCTAssertFalse(SaudiBanknoteReferencePack.safeRelativePath(path))
            XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(recordChange:("path",path))))
        }
        XCTAssertTrue(SaudiBanknoteReferencePack.safeRelativePath("notes/one.png"))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(recordChange:("sha256",String(repeating:"A",count:64)))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(recordChange:("boundary",["source_size":[100,100],"corners_tl_tr_br_bl":[[0,0],[101,0],[99,99],[0,99]]]))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(recordChange:("boundary",["source_size":[100,100],"corners_tl_tr_br_bl":[[0,0],[0,99],[99,99],[99,0]]]))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(reviewChange:("verified",false))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(reviewChange:("verified",1))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(reviewChange:("verified_on","2026-02-30"))))
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(manifest(reviewChange:("verification_kind","synthetic_fixture"))))
        let assistant = try SaudiBanknoteReferencePack.parse(manifest(reviewChange:("verification_kind","assistant_visual_review")))
        XCTAssertFalse(assistant.allHumanReviewed)
    }
    func testDuplicateIDsHashesOversizedAndEmptyPacks() throws {
        let object = try JSONSerialization.jsonObject(with:manifest()) as! [String:Any]
        let refs = object["references"] as! [[String:Any]]
        var duplicate = object; duplicate["references"] = refs+refs
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(JSONSerialization.data(withJSONObject:duplicate)))
        var empty = object; empty["references"] = []
        let pack = try SaudiBanknoteReferencePack.parse(JSONSerialization.data(withJSONObject:empty))
        XCTAssertFalse(pack.allHumanReviewed);XCTAssertFalse(pack.minimumCoverage)
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(Data(repeating:32,count:P.Limits.manifestBytes+1)))
        var huge = object; huge["references"] = Array(repeating:refs[0],count:49)
        XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(JSONSerialization.data(withJSONObject:huge)))
    }
    func testAllEightValuesAreExactAndNoPrefixLabelsAreAccepted() {
        for label in P.labels { XCTAssertEqual(P.experimentalDecision(evidence([candidate(label)])),.hypothesis(label)) }
        XCTAssertEqual(P.experimentalDecision(evidence([candidate(100),candidate(1,id:"one",inliers:10)])),.hypothesis(100))
    }
    func testIntegerManifestFieldsRejectFloatingPointOrBooleanValues() throws {
        let source=String(data:try manifest(),encoding:.utf8)!
        for (from,to) in [("\"schema_version\":2","\"schema_version\":2.0"),("\"label\":100","\"label\":100.0"),
                          ("\"label\":100","\"label\":1e2")] {
            XCTAssertThrowsError(try SaudiBanknoteReferencePack.parse(Data(source.replacingOccurrences(of:from,with:to).utf8)))
        }
    }
    func testMinimumCoverageRequiresBothSidesAndBothFiveMaterials() throws {
        var object=try JSONSerialization.jsonObject(with:manifest()) as! [String:Any]
        let template=(object["references"] as! [[String:Any]])[0]
        var records:[[String:Any]]=[]
        for label in P.labels {
            for material in label == 5 ? ["paper","polymer"] : ["paper"] {
                for side in ["front","back"] {
                    var row=template;row["label"]=label;row["side"]=side;row["material"]=material
                    row["id"]="fixture-\(records.count)";row["path"]="fixture-\(records.count).png"
                    row["sha256"]=String(format:"%064x",records.count+1);records.append(row)
                }
            }
        }
        object["references"]=records
        XCTAssertTrue(try SaudiBanknoteReferencePack.parse(JSONSerialization.data(withJSONObject:object)).minimumCoverage)
        records.removeAll { $0["label"] as? Int == 5 && $0["material"] as? String == "polymer" }
        object["references"]=records
        XCTAssertFalse(try SaudiBanknoteReferencePack.parse(JSONSerialization.data(withJSONObject:object)).minimumCoverage)
    }
    func testRequestedMoneyPoseRejectsPitchOnlyReaimAndTranslation() {
        let zero = Point3(0, 0, 0), forward = Point3(0, 0, -1)
        let pitch = Double.pi / 6
        XCTAssertTrue(RequestedVisualCapturePose.poseStable(origin: zero, current: zero, originForward: forward, currentForward: forward))
        XCTAssertFalse(RequestedVisualCapturePose.poseStable(origin: zero, current: zero, originForward: forward, currentForward: Point3(0, sin(pitch), -cos(pitch))))
        XCTAssertFalse(RequestedVisualCapturePose.poseStable(origin: zero, current: Point3(0.10, 0, 0), originForward: forward, currentForward: forward))
        XCTAssertFalse(RequestedVisualCapturePose.poseStable(origin: zero, current: zero, originForward: forward, currentForward: Point3(0, 0, 0)))
    }
    private func manifest(rootChange: (key:String,value:Any)? = nil,
                          recordChange: (String,Any)? = nil, reviewChange: (String,Any)? = nil) throws -> Data {
        var review: [String:Any] = ["verified":true,"verification_kind":"human_review","verified_by":"Fixture only",
            "verified_on":"2026-10-22","method":"Synthetic parser fixture, not actual currency review"]
        if let (key,value)=reviewChange {review[key]=value}
        var record: [String:Any] = ["id":"fixture-only", "path":"notes/fixture.png", "sha256":String(repeating:"a",count:64),
            "label":100,"side":"front","issue":"fixture","material":"paper","physical_note_id":"fixture",
            "capture_session_id":"fixture","source":"fixture","rights":"fixture","verification":review,
            "boundary":["source_size":[100,100],"corners_tl_tr_br_bl":[[0,0],[99,0],[99,99],[0,99]]]]
        if let (key,value)=recordChange {record[key]=value}
        var root: [String:Any] = ["schema_version":2,"reference_kind":"private_banknote_photos","currency":"SAR",
            "labels":P.labels,"references":[record]]
        if let (key,value)=rootChange {root[key]=value}
        return try JSONSerialization.data(withJSONObject:root,options:.sortedKeys)
    }
}
