import Foundation
import XCTest
@testable import BlindCore

final class IntegratedSpatialAuthorityEpisodeTests:XCTestCase {
    typealias F=SpatialIntegrationFixture
    func testTwentyMapCollisionAuthorityEpisodes()throws {
        let modes=["wrong_map","wrong_revision","wrong_session","wrong_floor","wrong_support_capture","wrong_support_time","camera_height_support","camera_heading","appearance_only","gps_only","expired_pose","unknown_ground","missing_surface","new_obstacle","closed_edge","body_changed","new_map_revision","lost_tracking","stale_goal","late_empty_restrictions"]
        var episodes:[[String:Any]]=[]
        for mode in modes {
            var steps:[[String:Any]]=[], failures:[String]=[]
            var episodeCompleted=false
            defer {
                if !episodeCompleted {failures.append("Unexpected setup/execution throw; see exact XCTest log")}
                episodes.append(["id":"SPATIAL-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual registered map/planner/collision/lease authority; authored sensors and map only","blocked_dependencies":["native calibrated localization issuer","observed real-world obstacle acquisition","actual audio"],"steps":steps,"failures":failures])
                if let output=ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"],let bytes=try? JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]) {try? bytes.write(to:URL(fileURLWithPath:output).appendingPathComponent("spatial-authority-component-episodes.json"))}
            }
            func check(_ okay:Bool,_ expected:String){if !okay{failures.append(expected)};XCTAssertTrue(okay,"\(mode):\(expected)")}
            var (owner,support)=try F.prepared(map:mode == "unknown_ground" ? F.map(blockedCell:(4,4)):mode == "missing_surface" ? F.map(surface:false):mode == "body_changed" ? F.map(clearance:2):F.map())
            let goal=try XCTUnwrap(owner.goalRevision),binding=try XCTUnwrap(owner.installation).binding
            func record(_ action:String,_ user:String,_ time:Double,_ output:Any=NSNull()) {
                steps.append(["user_utterance":user,"actual_action":action,"time":time,"map_binding":String(describing:owner.installation?.binding),"artifact_sha256":owner.installation?.artifact.sha256 ?? "nil","goal_revision":owner.goalRevision?.uuidString ?? "nil","session_id":owner.sessionID.uuidString,"route_nodes":owner.route.map(\.id),"waypoint_index":owner.waypointIndex,"current_pose":owner.currentPose(now:time).map{["id":$0.id.uuidString,"captured_at":$0.capturedAt,"age_seconds":time-$0.capturedAt,"position":[$0.position.x,$0.position.y,$0.position.z]] as [String:Any]} ?? [:],"actual_output":output,"provenance":"AUTHORED_MAP_POSE_SUPPORT_OBSTACLE_NOT_REAL_LOCALIZATION","image_ids":[],"lidar_ids":[],"model_output":"NOT RUN"])
            }
            record("install / goal / plan / accept authored pose","Help me reach the end of this mapped corridor.",10)
            if mode == "unknown_ground" || mode == "missing_surface" {
                do{_ = try owner.next(support:support,now:10);check(false,"Unknown/missing collision surface withholds guidance")}
                catch{record("next withheld","Can I continue?",10,String(describing:error))}
                check(owner.goalRevision == goal,"Withholding preserves destination")
            } else {
                let old=try owner.next(support:support,now:10)
                record("next / exact original route ticket","What is the next segment?",10,["target":old.target.id,"route_id":old.routeID.uuidString,"capture_id":old.spatial.captureID.uuidString,"artifact_sha256":old.artifactSHA256])
                switch mode {
                case "wrong_support_capture","wrong_support_time","camera_height_support":
                    let bad=SpatialFloorSupport(binding:binding,floorID:support.floorID,sessionID:support.sessionID,captureID:mode == "wrong_support_capture" ? UUID():support.captureID,height:mode == "camera_height_support" ? 1.3:0,capturedAt:mode == "wrong_support_time" ? 9.9:10)
                    do{_ = try owner.next(support:bad,now:10);check(false,"Unassociated support cannot issue movement ticket")}
                    catch{record("reject mismatched support","Use the current floor measurement, not the camera height.",10,["support_capture_id":bad.captureID.uuidString,"support_time":bad.capturedAt,"support_height":bad.height,"error":String(describing:error)])}
                    check((try? owner.next(support:support,now:10)) != nil,"Exact valid support remains usable")
                case "wrong_map","wrong_revision","wrong_session","wrong_floor","camera_heading","appearance_only","gps_only":
                    let badBinding=mode == "wrong_map" ? SpatialMapBinding(mapID:"other-map",frameID:binding.frameID,revision:binding.revision):mode == "wrong_revision" ? SpatialMapBinding(mapID:binding.mapID,frameID:binding.frameID,revision:"wrong-revision"):binding
                    let capture=SpatialLocalizationCapture(sessionID:mode == "wrong_session" ? UUID():owner.sessionID,binding:badBinding,floorID:mode == "wrong_floor" ? "other-floor":"floor",position:.init(1,1.3,3),bodyYaw:-.pi/2,source:mode == "appearance_only" ? .roomAppearance:mode == "gps_only" ? .coarseLocation:.alignedMapPose,headingSource:mode == "camera_heading" ? .cameraOnly:.bodyAligned,trackingNormal:true,positionUncertainty:0.1,headingUncertainty:0.1,capturedAt:10.1)
                    do{try owner.accept(capture,now:10.1);check(false,"Wrong ownership or insufficient pose source rejected")}
                    catch{record("accept invalid source","Do you still know exactly where I am?",10.1,["rejected_capture":capture.id.uuidString,"binding":String(describing:capture.binding),"session":capture.sessionID.uuidString,"floor":capture.floorID,"source":String(describing:capture.source),"heading":String(describing:capture.headingSource),"error":String(describing:error)])}
                    check(!owner.permits(old,now:10.1),"Invalid fresh capture cannot leave stale movement ticket active")
                case "expired_pose":
                    check(!owner.permits(old,now:11),"Age expiry alone withdraws ticket")
                    do{_ = try owner.next(support:support,now:11);check(false,"Expired pose cannot issue new ticket")}
                    catch{record("next after source expiry","It has been a while. Is that still current?",11,String(describing:error))}
                case "new_obstacle","closed_edge","late_empty_restrictions":
                    let blocked:Set<MapConnection>=mode == "new_obstacle" ? []:[MapConnection("start","middle")]
                    let zones:[KeepOutZone]=mode == "new_obstacle" ? [.init(id:"observed-closure",name:"authored obstacle",level:"ground",minX:2,maxX:2.5,minZ:2.5,maxZ:3.5)]:[]
                    try owner.addRestrictions(binding:binding,blocked:blocked,zones:zones,persist:{_ in})
                    check(!owner.permits(old,now:10.1),"Changed collision restrictions retire prior output")
                    record("addRestrictions","Something now blocks that path.",10.1,["blocked_edges":blocked.map{String(describing:$0)},"zones":zones.map{String(describing:$0)}])
                    if mode == "late_empty_restrictions" {try owner.addRestrictions(binding:binding,blocked:[],zones:[],persist:{_ in});record("late empty restriction update","An older empty update arrived.",10.1)}
                    do{try owner.plan(from:"start",to:"end",goal:goal);check(false,"Current restrictions prevent route and cannot be erased by late empty update")}
                    catch{record("replan with current restrictions","Find a route using what is known now.",10.1,String(describing:error))}
                case "body_changed":
                    try owner.setBody(.init(radius:0.25,height:2.2,margin:0.1));check(!owner.permits(old,now:10.1),"Body envelope change retires prior cue")
                    do{try owner.plan(from:"start",to:"end",goal:goal);check(false,"Oversized body cannot traverse low clearance")}
                    catch{record("setBody / replan","Recheck the clearance for the changed body envelope.",10.1,String(describing:error))}
                case "new_map_revision":
                    let pending=try F.capture(owner:owner,time:10.1)
                    try owner.install(F.installation(map:F.map(revision:"r2"),prior:owner.installation),persist:{_ in})
                    check(!owner.permits(old,now:10.1),"Map replacement retires exact old ticket")
                    do{try owner.accept(pending,now:10.1);check(false,"Old revision capture cannot bind new map")}
                    catch{record("install revision / reject delayed old pose","The map was updated.",10.1,String(describing:error))}
                case "lost_tracking":
                    let pending=try F.capture(owner:owner,time:10.1);owner.loseTracking()
                    check(!owner.permits(old,now:10.1),"Tracking loss retires output")
                    do{try owner.accept(pending,now:10.1);check(false,"Pre-loss session callback rejected")}
                    catch{record("loseTracking / reject delayed capture","The phone lost tracking.",10.1,String(describing:error))}
                    check(owner.installation?.binding == binding,"Durable map survives tracking loss")
                case "stale_goal":
                    do{try owner.plan(from:"start",to:"end",goal:UUID());check(false,"Unowned goal cannot replace current plan")}
                    catch{record("reject stale goal replan","Keep the current destination, not an older request.",10,String(describing:error))}
                    check(owner.permits(old,now:10),"Rejected foreign goal does not disrupt valid current route")
                default:break
                }
                check(owner.goalRevision == goal,"Negative evidence must not invent or replace destination")
            }
            record("inspect final source-owned state","What remains of my original goal?",mode == "expired_pose" ? 11.1:10.2)
            episodeCompleted=true
        }
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("spatial-authority-component-episodes.json"))
    }
}
