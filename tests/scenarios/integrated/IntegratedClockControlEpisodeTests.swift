import Foundation
import XCTest
@testable import BlindCore

final class IntegratedClockControlEpisodeTests:XCTestCase {
    func testTwentyClockOwnershipEpisodes()throws {
        let modes=["fresh","deadline","zone_change","wall_rollback","monotonic_rollback","request_change","generation_change","reply_change","replayed_after_expiry","small_skew"]
        var episodes:[[String:Any]]=[]
        for arabic in [false,true] {for mode in modes {
            let request=UUID(), reply=UUID(),wall=Date(timeIntervalSince1970:1_700_000_000),zone=TimeZone(secondsFromGMT:0)!
            let binding=CompanionClockReplyLease.Binding(requestID:request,generation:7,replyID:reply)
            var lease=try XCTUnwrap(CompanionClockReplyLease.read(binding:binding,now:wall,monotonicNow:100,timeZone:zone,arabic:arabic))
            let first=lease.validates(reply:lease.reply,binding:binding,now:wall.addingTimeInterval(2),monotonicNow:102,timeZone:zone)
            XCTAssertTrue(first)
            var steps:[[String:Any]]=[["user_utterance":arabic ? "كم الساعة؟":"What time is it?","actual_action":"CompanionClockReplyLease.read / validates","actual_code_text":lease.reply,"request_id":request.uuidString,"reply_id":reply.uuidString,"generation":7,"wall_date":wall.timeIntervalSince1970,"monotonic_read":100,"age_seconds":2,"actual_valid":first,"expected_valid":true]]
            var age=3.0,wallAge=3.0,currentZone=zone,currentBinding=binding,text=lease.reply
            switch mode {
            case "deadline","replayed_after_expiry":age=5;wallAge=5
            case "zone_change":currentZone=TimeZone(identifier:"Asia/Riyadh")!
            case "wall_rollback":age=2.05;wallAge=1.99
            case "monotonic_rollback":age=1.99;wallAge=2.05
            case "request_change":currentBinding = .init(requestID:UUID(),generation:7,replyID:reply)
            case "generation_change":currentBinding = .init(requestID:request,generation:8,replyID:reply)
            case "reply_change":text += " The door is open."
            case "small_skew":age=3;wallAge=3.1
            default:break
            }
            let actual=lease.validates(reply:text,binding:currentBinding,now:wall.addingTimeInterval(wallAge),monotonicNow:100+age,timeZone:currentZone)
            let expected=mode == "fresh" || mode == "small_skew"
            XCTAssertEqual(actual,expected,"\(mode) arabic=\(arabic)")
            steps.append(["user_utterance":arabic ? "هل ما زال هذا الوقت صحيحاً؟":"Is that clock reading still current?","actual_action":"validate original source lease after \(mode)","age_seconds":age,"wall_age_seconds":wallAge,"timezone":currentZone.identifier,"candidate_text":text,"actual_valid":actual,"expected_valid":expected])
            var revival:Bool?=nil
            if !expected {revival=lease.validates(reply:lease.reply,binding:binding,now:wall.addingTimeInterval(3),monotonicNow:103,timeZone:zone);XCTAssertEqual(revival,false);steps.append(["user_utterance":arabic ? "أعد القراءة القديمة":"Repeat that old answer.","actual_action":"attempt revival after revocation","actual_valid":revival! ,"expected_valid":false])}
            episodes.append(["id":"CLOCK-\(arabic ? "ar":"en")-\(mode)","status":first && actual == expected && revival != true ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual code clock read and original-deadline/session/source delivery lease","blocked_dependencies":["native clock capture scheduling","real audible delivery"],"model_output":"NOT RUN; code owns clock answer","map_id":NSNull(),"pose_id":NSNull(),"image_ids":[],"steps":steps])
        }}
        try write(episodes,"clock-component-episodes.json")
    }
    func testTwentyRoomScanAuthorityEpisodes()throws {
        let modes=["confirmed","prompt_unheard","expired","cancelled","replaced","model_request","observed_confirmation","unrelated_reply","duplicate_yes","background_discussion"]
        var episodes:[[String:Any]]=[]
        for arabic in [false,true] {for mode in modes {
            var gate=VoiceRoomScanConfirmation(),steps:[[String:Any]]=[],failures:[String]=[]
            let request=arabic ? "ابدأ مسح الغرفة غرفة النوم":"Start scan room Bedroom",yes=arabic ? "نعم":"yes"
            func record(_ utterance:String,_ action:VoiceRoomScanConfirmation.Action,_ time:Double,_ source:String) {steps.append(["user_utterance":utterance,"source":source,"time":time,"actual_code_action":String(describing:action),"pending":gate.hasPendingConfirmation])}
            func check(_ condition:Bool,_ expected:String){if !condition{failures.append(expected)};XCTAssertTrue(condition,"\(mode) \(arabic):\(expected)")}
            if mode == "model_request" {
                let action=gate.consume(request,source:.modelTool,now:10);record(request,action,10,"authored modelTool payload, not real model output");check(action == .none,"Model tool cannot request scan")
                let reply=gate.consume(yes,source:.directUser,now:11);record(yes,reply,11,"authored directUser");check(reply == .none,"Yes without eligible request cannot start")
            } else if mode == "background_discussion" {
                let text=arabic ? "قال ابدأ مسح الغرفة":"I said scan room"
                let action=gate.consume(text,source:.directUser,now:10);record(text,action,10,"authored directUser quote");check(action == .none,"Quoted/background discussion cannot request scan")
                check(gate.consume(yes,source:.directUser,now:11) == .none,"Later yes cannot activate absent request")
            } else {
                let action=gate.consume(request,source:.directUser,now:10);record(request,action,10,"authored directUser, NOT microphone verification")
                check(gate.hasPendingConfirmation,"Direct request requires separate pending confirmation")
                if mode != "prompt_unheard" {check(gate.promptDidFinish(now:10),"Exact prompt terminal callback recorded (simulated)")}
                switch mode {
                case "cancelled":gate.cancel()
                case "replaced":let replacement=gate.consume("scan room Kitchen",source:.directUser,now:11);record("scan room Kitchen",replacement,11,"authored directUser");_ = gate.promptDidFinish(now:11)
                case "observed_confirmation":let falseYes=gate.consume(yes,source:.observedContent,now:11);record(yes,falseYes,11,"authored observed sign text");check(falseYes == .none,"Observed text cannot confirm")
                case "unrelated_reply":let unrelated=gate.consume("tell me the time",source:.directUser,now:11);record("tell me the time",unrelated,11,"authored directUser");check(unrelated == .none,"Unrelated response consumes confirmation")
                default:break
                }
                let time=mode == "expired" ? 100.0:12.0
                let final=gate.consume(yes,source:.directUser,now:time);record(yes,final,time,"authored directUser")
                let shouldStart=["confirmed","replaced","observed_confirmation","duplicate_yes"].contains(mode)
                if case .start(let name)=final {check(shouldStart,"Only fully eligible confirmation starts");if mode == "replaced" {check(name == "Kitchen","Replacement exact room owns confirmation")}}
                else {check(!shouldStart,"Eligible explicit confirmation must start")}
                if mode == "duplicate_yes" {let duplicate=gate.consume(yes,source:.directUser,now:13);record(yes,duplicate,13,"authored directUser");check(duplicate == .none,"Confirmation cannot be reused")}
            }
            episodes.append(["id":"SCAN-\(arabic ? "ar":"en")-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual command parser and source-bound two-turn confirmation state; no RoomPlan action executed","blocked_dependencies":["verified speaker/addressee","native scan warning audio","RoomPlan capture and map publication"],"map_id":NSNull(),"pose_id":NSNull(),"image_ids":[],"model_output":"NOT RUN","steps":steps,"failures":failures])
        }}
        try write(episodes,"scan-control-component-episodes.json")
    }
    func write(_ value:Any,_ name:String)throws {let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"]);try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent(name))}
}
