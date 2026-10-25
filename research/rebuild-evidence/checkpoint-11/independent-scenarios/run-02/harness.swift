import Foundation
import XCTest
@testable import BlindCore

/// Replay ONLY. Uses actual production planner/coordinator/collision/lease code.
/// All spatial fixtures are authored plumbing. NO real localization/model/audio.
final class IntegratedEpisodeReplayTests: XCTestCase {
    typealias F = ConnectedFixture
    var steps: [[String: Any]] = []
    var checks: [[String: Any]] = []
    func object<T: Encodable>(_ value: T) throws -> Any { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) }
    func check(_ condition: Bool, _ expected: String) {
        checks.append(["expected": expected, "actual": condition, "result": condition ? "PASS" : "FAIL"])
        XCTAssertTrue(condition, expected)
    }
    func record(_ owner: ConnectedJourneyCoordinator, _ action: String, _ utterance: String? = nil,
                time: Double, output: Any = NSNull(), expected: String = "State transition follows code-owned evidence") throws {
        var evidence: [String: Any] = ["fixture": "ConnectedFixture authored three-map topology",
          "provenance": "AUTHORED_PLUMBING_NOT_REAL_LOCALIZATION", "image_ids": [], "lidar_ids": [],
          "model_input": "NOT RUN", "model_output": "NOT RUN", "spoken_audio": "NOT RUN"]
        if let p = owner.currentPose(now: time) {
            evidence["pose"] = ["id":p.id.uuidString, "session":p.sessionID.uuidString,
                "binding":try object(p.binding), "floor":p.floorID, "room":p.roomID.map { $0 as Any } ?? NSNull(),
                "position":[p.position.x,p.position.y,p.position.z], "yaw":p.bodyYaw,
                "capture_time":p.capturedAt, "age_seconds":time-p.capturedAt,
                "position_uncertainty":p.positionUncertainty,"heading_uncertainty":p.headingUncertainty,
                "source":"authored alignedMapPose", "support":"authored same-capture floor height 0"]
        } else { evidence["pose"] = NSNull() }
        steps.append(["index": steps.count, "user_utterance":utterance.map { $0 as Any } ?? NSNull(), "utterance_execution":"Trusted-interface action selected explicitly by harness; no speech/LLM parsing",
          "time":time,"actual_tool_selection":action,"state":try object(owner.snapshot),
          "progress":["leg_index":owner.legIndex,"leg_count":owner.itinerary.count,"quiet":owner.ordinarySpeechMuted],
          "evidence":evidence,"actual_output":output,"expected":expected])
    }
    func observe(_ owner: inout ConnectedJourneyCoordinator, _ endpoint: JourneyEndpoint, time: Double, reverse: Bool = false) throws {
        let capture = try F.capture(owner, at:endpoint,time:time,yaw:reverse ? .pi/2 : -.pi/2)
        try owner.accept(capture,support:SpatialIntegrationFixture.support(capture),now:time)
        try record(owner,"accept(capture, exact same-capture support)",time:time)
    }
    func drive(_ owner: inout ConnectedJourneyCoordinator, time: inout Double, reverse: Bool = false) throws {
        let goal = owner.snapshot.goal?.revision
        var bounded = 0
        while let leg = owner.currentLeg {
            bounded += 1; if bounded > 20 { throw NSError(domain:"bounded replay",code:1) }
            switch leg {
            case .local(_, let to):
                for _ in 0..<12 {
                    let ticket = try owner.next(now:time)
                    let cue = try XCTUnwrap(ticket.route.directionalCue())
                    check(owner.permits(ticket,now:time),"Fresh exact route ticket is permitted")
                    let output: [String:Any] = ["target":try object(ticket.route.target), "sector":cue.sector,"distance_m":cue.distance,
                        "artifact_sha256":ticket.route.artifactSHA256,"route_id":ticket.route.routeID.uuidString,
                        "capture_id":ticket.route.spatial.captureID.uuidString,"acceptance_id":ticket.route.spatial.acceptanceID.uuidString,
                        "body_revision":ticket.route.bodyRevision.uuidString,"obstacle_revision":ticket.route.obstacleRevision.uuidString,
                        "goal_revision":ticket.route.goalRevision.uuidString,"physical_delivery":"NOT RUN; stored-geometry cue only"]
                    try record(owner,"next / planner + collision + directionalCue / permits",time:time,output:output)
                    time += 0.1
                    try observe(&owner,F.endpoint(to.binding,ticket.route.target.id),time:time,reverse:reverse)
                    let retired = !owner.permits(ticket,now:time)
                    check(retired,"Previous capture ticket must retire after fresh observation")
                    try record(owner,"permits(oldTicket)",time:time,output:["old_ticket_retired":retired])
                    try owner.advanceWaypoint(now:time)
                    if ticket.route.target.id == to.nodeID { break }
                }
                try owner.completeLocalLeg(now:time,recordedAt:F.date,persist:{_ in})
                try record(owner,"completeLocalLeg",time:time)
            case .portal(let id,_,let to):
                do { _ = try owner.next(now:time); check(false,"Portal cannot emit movement ticket") }
                catch { try record(owner,"next at portal",time:time,output:["withheld":String(describing:error),"portal":id]) }
                try owner.armPortal(now:time,recordedAt:F.date)
                try owner.beginLocalization(in:to.binding)
                check(owner.currentPose(now:time) == nil,"Portal changes map/session and requires new pose")
                time += 0.1
                try observe(&owner,to,time:time,reverse:reverse)
                try owner.completePortal(now:time,recordedAt:F.date,persist:{_ in})
                try record(owner,"completePortal (authored endpoint association only)",time:time)
            }
            check(owner.snapshot.goal?.revision == goal,"Room/floor transitions preserve original goal revision")
        }
        check(owner.snapshot.goal?.status == .arrived,"Journey ends arrived only from fresh endpoint evidence")
    }
    func testFortyDistinctNavigationReplayEpisodes() throws {
        let destinations = [F.endpoint(F.b,"m"),F.endpoint(F.b,"p"),F.endpoint(F.c,"m"),F.endpoint(F.c,"p")]
        let modes = ["baseline","quiet","hold_resume","camera_restart","app_restart","background_command","stale_pose","wrong_support","wrong_heading","blocked_return"]
        var reports: [[String:Any]] = []
        for (di,destination) in destinations.enumerated() {
            for (mi,mode) in modes.enumerated() {
                steps = []; checks = []
                let id = String(format:"NAV-%03d",di*10+mi+1)
                var owner = try F.prepared(), time = 1.0
                let goalText = "Take me to \(destination.binding.mapID), node \(destination.nodeID)."
                do {
                    try record(owner,"beginLocalization / accept / markStart", "Remember where we started.",time:time)
                    try owner.setDestination(destination,origin:.trustedInterface,recordedAt:F.date,persist:{_ in})
                    try owner.plan(from:F.endpoint(F.a,"s"),now:time)
                    try record(owner,"setDestination / plan",goalText,time:time)
                    let old = try owner.next(now:time), originalGoal = owner.snapshot.goal
                    switch mode {
                    case "quiet":
                        try owner.setOrdinarySpeechMuted(true,origin:.trustedInterface)
                        check(owner.permits(old,now:time),"Ordinary quiet does not revoke necessary navigation")
                        try record(owner,"setOrdinarySpeechMuted","Please stop describing things, but keep guiding me.",time:time)
                    case "hold_resume":
                        try owner.hold(origin:.trustedInterface,persist:{_ in})
                        check(!owner.permits(old,now:time),"Hold retires queued guidance")
                        try record(owner,"hold","Wait, I need a break.",time:time)
                        try owner.resume(origin:.trustedInterface,persist:{_ in})
                        check(owner.currentPose(now:time) == nil,"Resume does not restore old pose")
                        time += 0.1; try observe(&owner,F.endpoint(F.a,"s"),time:time)
                        try owner.plan(from:F.endpoint(F.a,"s"),now:time)
                        try record(owner,"resume / fresh evidence / plan","Okay, continue.",time:time)
                    case "camera_restart", "app_restart":
                        if mode == "app_restart" { owner = try F.coordinator(snapshot:.init(data:owner.snapshot.encoded())) }
                        else { owner.loseTracking() }
                        check(!owner.permits(old,now:time),"Restart retires old route ticket")
                        check(owner.snapshot.goal == originalGoal,"Restart retains goal but not spatial authority")
                        try record(owner,"restart","I am still going to the same place.",time:time)
                        try owner.beginLocalization(in:F.a); time += 0.1
                        try observe(&owner,F.endpoint(F.a,"s"),time:time)
                        try owner.plan(from:F.endpoint(F.a,"s"),now:time)
                    case "background_command":
                        for origin in CompanionCommandOrigin.allCases where origin != .trustedInterface {
                            let before = owner.snapshot
                            do { try owner.cancel(origin:origin,recordedAt:F.date,persist:{_ in});check(false,"Unverified source must not cancel") }
                            catch { try record(owner,"reject cancel from \(origin)","TV / background speaker: cancel the journey.",time:time,output:String(describing:error)) }
                            check(owner.snapshot == before,"Untrusted command preserves exact journey state")
                        }
                    case "stale_pose":
                        time += 20
                        check(!owner.permits(old,now:time),"Elapsed age alone retires route ticket")
                        do { _ = try owner.next(now:time);check(false,"Expired pose cannot issue guidance") }
                        catch { try record(owner,"next with stale capture","Are we still going?",time:time,output:String(describing:error)) }
                        try observe(&owner,F.endpoint(F.a,"s"),time:time)
                    case "wrong_support", "wrong_heading":
                        time += 0.1
                        let capture = try F.capture(owner,at:F.endpoint(F.a,"s"),time:time,heading:mode == "wrong_heading" ? .cameraOnly : .bodyAligned)
                        let support = mode == "wrong_support" ? SpatialFloorSupport(binding:capture.binding,floorID:capture.floorID,sessionID:capture.sessionID,captureID:UUID(),height:0,capturedAt:time) : SpatialIntegrationFixture.support(capture)
                        do { try owner.accept(capture,support:support,now:time);check(false,"Invalid support/heading must be rejected") }
                        catch { try record(owner,"accept invalid \(mode)","I moved the phone. Can we continue?",time:time,output:["error":String(describing:error),"rejected_capture_id":capture.id.uuidString,"support_capture_id":support.captureID.uuidString]) }
                        check(!owner.permits(old,now:time),"Rejected evidence retires old output")
                        time += 0.1; try observe(&owner,F.endpoint(F.a,"s"),time:time)
                    default: break
                    }
                    try drive(&owner,time:&time)
                    try owner.saveReference(at:destination,origin:.trustedInterface,now:time,recordedAt:F.date,persist:{_ in})
                    try record(owner,"saveReference","Save this place too.",time:time)
                    guard case .clarify(let question) = try owner.requestReturn(origin:.trustedInterface,recordedAt:F.date,persist:{_ in}) else { throw NSError(domain:"Expected ambiguity",code:1) }
                    try record(owner,"requestReturn","Take me back.",time:time,output:question.text)
                    let receipt = try F.deliver(&owner,question,now:time)
                    try owner.resolveReturn(.journeyStart,receipt:receipt,origin:.trustedInterface,now:time,recordedAt:F.date,persist:{_ in})
                    try record(owner,"SpeechDeliveryLedger simulated completion / resolveReturn","To where we started, not this saved point.",time:time)
                    time += 0.1; try observe(&owner,destination,time:time,reverse:true)
                    try owner.plan(from:destination,now:time)
                    if mode == "blocked_return" {
                        let ticket = try owner.next(now:time)
                        try owner.addRestrictions(blocked:[MapConnection("s","m")],zones:[],persistMap:{_ in})
                        check(!owner.permits(ticket,now:time),"New restriction retires previous return ticket")
                        do { try owner.plan(from:destination,now:time);check(false,"Blocked return must not reuse outbound clearance") }
                        catch { try record(owner,"addRestrictions / plan blocked return","There is something blocking the way now.",time:time,output:String(describing:error)) }
                        check(owner.snapshot.goal?.purpose == .returnToStart,"Blocked return retains requested destination")
                    } else { try drive(&owner,time:&time,reverse:true) }
                } catch {
                    checks.append(["expected":"Episode executes all planned actions", "actual":String(describing:error),"result":"FAIL"])
                    XCTFail("\(id) \(mode): \(error)")
                }
                reports.append(["id":id,"mode":mode,"destination":try object(destination),
                    "deterministic_seed":20261025+di*101+mi,"split":(di*10+mi)%5 == 4 ? "held_out" : "development",
                    "evidence_level":"ACTUAL_CODE_AUTHORED_PLUMBING", "full_user_episode_status":"BLOCKED: no real model, native tool routing, calibrated localization, or audio",
                    "actual_code_result":checks.allSatisfy{($0["result"] as? String) == "PASS"} ? "PASS" : "FAIL",
                    "steps":steps,"checks":checks])
            }
        }
        let directory = try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        try JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys,.fragmentsAllowed]).write(to:URL(fileURLWithPath:directory).appendingPathComponent("navigation-episodes.json"))
    }
}
