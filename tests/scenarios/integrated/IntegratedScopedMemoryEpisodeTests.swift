import Foundation
import XCTest
@testable import BlindCore

final class IntegratedScopedMemoryEpisodeTests:XCTestCase {
    func testTwentyScopedMemoryEpisodes()throws {
        let modes=["same_scope","other_place","other_map","other_frame","other_revision","other_floor","other_room","other_instance","room_only","unknown_scope","fresh_observation","expired_observation","future_observation","older_observation","spatial_observation","correction","source_delete","source_move","source_redate","restore_both"]
        let t=Date(timeIntervalSince1970:1_700_000_000)
        var episodes:[[String:Any]]=[]
        for mode in modes {
            let a=try XCTUnwrap(CompanionMemoryScope(map:.init(mapID:"home-map",frameID:"home-frame",revision:"r1"),placeID:"home",floorID:"ground",roomID:"kitchen",objectInstanceID:"fridge-A"))
            let b=try XCTUnwrap(CompanionMemoryScope(map:.init(mapID:mode == "other_map" ? "school-map":"home-map",frameID:mode == "other_frame" ? "other-frame":"home-frame",revision:mode == "other_revision" ? "r2":"r1"),placeID:mode == "other_place" ? "school":"home",floorID:mode == "other_floor" ? "upper":"ground",roomID:mode == "other_room" ? "other-kitchen":"kitchen",objectInstanceID:mode == "room_only" ? nil:mode == "other_instance" ? "fridge-B":"fridge-A"))
            var book=CompanionFactBook(),steps:[[String:Any]]=[],failures:[String]=[]
            func check(_ condition:Bool,_ expected:String){if !condition{failures.append(expected)};XCTAssertTrue(condition,"\(mode):\(expected)")}
            func record(_ utterance:String,_ action:String,_ output:Any,_ time:Date)throws {steps.append(["user_utterance":utterance,"actual_action":action,"time":time.timeIntervalSince1970,"state":try JSONSerialization.jsonObject(with:JSONEncoder().encode(book)),"scope_a":a.storageKey,"scope_b":b.storageKey,"actual_output":output,"model_output":"NOT RUN","image_ids":[],"pose_id":NSNull(),"provenance":"AUTHORED ID OWNERSHIP; not measured place/object recognition"])}
            let first=try XCTUnwrap(book.record(object:"milk",place:"in the fridge",tense:.current,hedged:false,at:t,scope:a,sourceID:"source-A"))
            try record("My milk is in this fridge.","record scoped source-A",first.acknowledgement(arabic:false),t)
            switch mode {
            case "same_scope","other_place","other_map","other_frame","other_revision","other_floor","other_room","other_instance","room_only","unknown_scope":
                let selected=CompanionScopedRecall.select(object:"milk",scope:mode == "unknown_scope" ? nil:b,now:t.addingTimeInterval(1),observations:[],book:book)
                check(selected == (mode == "same_scope" ? .reportedHistory(first):.unknown),"Only exact scope can retrieve original report; unknown never falls back by name")
                try record("What do you remember about the milk in this place?","select exact scoped history",String(describing:selected),t.addingTimeInterval(1))
            case "fresh_observation","expired_observation","future_observation","older_observation","spatial_observation":
                let correction=mode == "older_observation" ? book.record(object:"milk",place:"in the bag",tense:.current,hedged:false,at:t.addingTimeInterval(12),scope:a,sourceID:"source-correction"):nil
                let observed=t.addingTimeInterval(mode == "future_observation" ? 14:10)
                let evidence=CompanionEvidence(id:"authored-detection",kind:.currentObservation,text:mode == "spatial_observation" ? "Milk is two metres left.":"Milk carton detected.",source:"authored gated detector output, detection NOT RUN",observedAt:observed,expiresAt:observed.addingTimeInterval(5))
                let observation=CompanionScopedObservation(scope:a,object:"milk",evidence:evidence)
                let time=t.addingTimeInterval(mode == "expired_observation" ? 15:13)
                let selected=CompanionScopedRecall.select(object:"milk",scope:a,now:time,observations:[observation],book:book)
                check(selected == (mode == "fresh_observation" ? .observation(evidence):.reportedHistory(correction ?? first)),"Only fresh nonspatial exact-target observation newer than history wins")
                try record("What information is current now?","source-qualified scoped selection",["selected":String(describing:selected),"observation":try JSONSerialization.jsonObject(with:JSONEncoder().encode(evidence)),"observation_age_seconds":time.timeIntervalSince(observed)],time)
                let expired=CompanionScopedRecall.select(object:"milk",scope:a,now:t.addingTimeInterval(30),observations:[observation],book:book)
                check(expired == .reportedHistory(correction ?? first),"Expiry returns original qualified history without refreshing it")
                try record("And after that observation expires?","expire observation / preserve original history",String(describing:expired),t.addingTimeInterval(30))
            case "correction":
                let other=try XCTUnwrap(CompanionMemoryScope(map:a.map,placeID:"school",floorID:a.floorID,roomID:a.roomID,objectInstanceID:"fridge-B"))
                book.record(object:"milk",place:"on the table",tense:.current,hedged:false,at:t,scope:other,sourceID:"source-B")
                book.record(object:"milk",place:"in the bag",tense:.current,hedged:false,at:t.addingTimeInterval(2),scope:a,sourceID:"correction-A")
                check(book.record(object:"milk",place:"in the fridge",tense:.current,hedged:false,at:t,scope:a,sourceID:"stale-A") == nil,"Older correction cannot overwrite newer report")
                check(book.latest(for:"milk",in:a)?.place == "in the bag" && book.latest(for:"milk",in:other)?.place == "on the table","Correction stays local to exact physical scope")
                try record("No, I moved this milk to my bag, not the milk at school.","scoped correction / reject reordered old report",true,t.addingTimeInterval(3))
            case "source_delete":
                check(book.forgetSource("source-A"),"Deleting original source removes its fact")
                check(CompanionScopedRecall.select(object:"milk",scope:a,now:t,observations:[],book:book) == .unknown,"Deleted source cannot be recalled")
                try record("Forget that private report.","forgetSource / select",true,t.addingTimeInterval(1))
            case "source_move":
                let other=try XCTUnwrap(CompanionMemoryScope(map:a.map,placeID:"school",floorID:a.floorID,roomID:a.roomID,objectInstanceID:"fridge-B"))
                check(book.record(object:"milk",place:"in the fridge",tense:.current,hedged:false,at:t,scope:other,sourceID:"source-A") == nil,"Original source ID cannot be rebound to another physical scope")
                check(book.facts == [first],"Rejected move preserves original source exactly")
                try record("Use the old report for this different fridge.","reject source-ID scope move",false,t.addingTimeInterval(1))
            case "source_redate":
                check(book.record(object:"milk",place:"in the fridge",tense:.current,hedged:false,at:t.addingTimeInterval(1),scope:a,sourceID:"source-A") == nil,"Original source ID cannot acquire a fresh timestamp")
                check(book.facts == [first],"Rejected redate preserves original age")
                try record("Repeat the old report as if it was just observed.","reject source-ID redate",false,t.addingTimeInterval(1))
            case "restore_both":
                let other=try XCTUnwrap(CompanionMemoryScope(map:a.map,placeID:a.placeID,floorID:a.floorID,roomID:a.roomID,objectInstanceID:"fridge-B"))
                book.record(object:"milk",place:"on the table",tense:.current,hedged:false,at:t.addingTimeInterval(1),scope:other,sourceID:"source-B")
                book=try JSONDecoder().decode(CompanionFactBook.self,from:JSONEncoder().encode(book))
                check(book.latest(for:"milk",in:a)?.sourceID == "source-A" && book.latest(for:"milk",in:other)?.sourceID == "source-B","Restore preserves both distinct same-name physical records")
                check(book.latest(for:"milk",in:nil) == nil,"Restoration never invents current identity")
                try record("After restart, remember both fridges separately.","serialize / restore / scoped lookup",true,t.addingTimeInterval(2))
            default:break
            }
            episodes.append(["id":"SCOPED-MEMORY-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual place/floor/room/object-instance source binding and fresh versus historical selection","blocked_dependencies":["native verified place/object binding issuer","physical recognition accuracy","actual local model/audio"],"steps":steps,"failures":failures])
        }
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("scoped-memory-component-episodes.json"))
    }
}
