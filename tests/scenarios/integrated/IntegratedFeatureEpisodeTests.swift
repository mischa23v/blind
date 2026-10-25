import Foundation
import XCTest
@testable import BlindCore

final class IntegratedFeatureEpisodeTests: XCTestCase {
    typealias P = ContextualCapabilityScheduler
    func testEightFeatureLeaseEpisodes() throws {
        var episodes: [[String:Any]] = []
        let cases: [(P.Capability,String,P.Goal)] = [(.color,"Get dressed for school",.dressing),(.text,"Read my homework",.reading),(.barcode,"I want to buy groceries",.shopping),(.currency,"Pay for my food",.payment)]
        for (capability,utterance,expectedGoal) in cases {
            for stale in [false,true] {
                var policy = P(), steps: [[String:Any]] = []
                let request = UUID(), perception = UUID(), id = "FEATURE-\(capability.rawValue)-\(stale ? "stale" : "fresh")"
                let goal = P.Goal.infer(from:utterance)
                XCTAssertTrue(goal.contains(expectedGoal))
                func moment(_ time:Double) -> P.Moment { .init(now:time,requestID:request,perceptionGeneration:perception,sessionGeneration:7,goalGeneration:id) }
                let available: [P.Capability:P.Availability] = [capability:.available]
                let input = P.Evidence(capturedAt:10,banknoteCandidate:capability == .currency)
                let lease = try XCTUnwrap(policy.reserve(goal:goal,evidence:input,moment:moment(10),availability:available))
                XCTAssertEqual(lease.capability,capability)
                steps.append(["user_utterance":utterance,"action":"infer goal / reserve actual adapter","time":10,"capture_id":"authored-frame-\(id)","capture_time":10,"age_seconds":0,"request_id":request.uuidString,"perception_id":perception.uuidString,"session":7,"goal":id,"actual_tool_selection":lease.capability.rawValue,"expected_tool":capability.rawValue])
                let evidence = P.Evidence(capturedAt:10,banknoteCandidate:capability == .currency,textCandidate:capability == .text,barcodeCandidate:capability == .barcode,centralIsolatedItem:capability == .color)
                let time = stale ? 40.0 : 10.2
                let permitted = policy.beforeSpeech(lease,moment:moment(time),evidence:evidence,goal:goal,availability:available)
                XCTAssertEqual(permitted,!stale)
                steps.append(["user_utterance":"What did you find?","action":"beforeSpeech exact source/goal/age revalidation","time":time,"age_seconds":time-10,"capture_id":"authored-frame-\(id)","actual_output_permitted":permitted,"expected_output_permitted":!stale,"actual_words":"NOT RUN: perception/backend and LLM not executed"])
                policy.cancel()
                let late = policy.beforeSpeech(lease,moment:moment(time+0.1),evidence:evidence,goal:goal,availability:available)
                XCTAssertFalse(late)
                steps.append(["user_utterance":"Stop that answer.","action":"cancel / beforeSpeech old lease","time":time+0.1,"actual_old_output_retired":!late,"expected_old_output_retired":true])
                episodes.append(["id":id,"provenance":"AUTHORED_ADAPTER_INPUT_NOT_PERCEPTION","map_id":NSNull(),"pose_id":NSNull(),"image_ids":[],"model_input":"NOT RUN","model_output":"NOT RUN","full_user_episode_status":"BLOCKED: native perception/model/audio not run","steps":steps,"actual_code_result":permitted == !stale && !late ? "PASS":"FAIL"])
            }
        }
        let output = try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("feature-episodes.json"))
    }
    func testFamiliarEncounterAndColorOCRAdapters() throws {
        var traces: [[String:Any]] = []
        var familiar = FamiliarEncounterPolicy()
        let person = UUID(uuidString:"00000000-0000-0000-0000-000000000042")!
        var steps: [[String:Any]] = []
        for (time,identities,faces,expected) in [(1.0,[person],1,0),(2.0,[person],1,1),(3.0,[person],1,0),(4.0,[],1,0)] {
            let result = familiar.observe(identities,detectedFaces:faces,now:time)
            XCTAssertEqual(result.count,expected)
            steps.append(["user_utterance":time == 1 ? "Has anyone I know arrived?":"Is that still the same person?","time":time,"image_id":"NOT RUN","source":"authored consented-match IDs, not face recognition","identity_ids":identities.map(\.uuidString),"detected_faces":faces,"actual_notice_ids":result.map(\.uuidString),"expected_notice_count":expected])
            result.forEach { familiar.markAnnounced($0) }
        }
        familiar.reset()
        let deleted = familiar.encounterID(for:person)
        XCTAssertNil(deleted)
        steps.append(["user_utterance":"Forget that encounter.","action":"reset","actual_encounter_deleted":deleted == nil,"expected":true])
        traces.append(["id":"FEATURE-familiar-encounter","steps":steps])
        let nearWhite = ClothingColor.evaluate(Array(repeating:ClothingColor.RGB(0.95,0.95,0.95),count:100))
        let blue = ClothingColor.evaluate(Array(repeating:ClothingColor.RGB(0.10,0.46,0.82),count:100))
        XCTAssertEqual(nearWhite,.nearNeutral); XCTAssertEqual(blue,.appearance(.blue))
        traces.append(["id":"FEATURE-color-change","steps":[["user_utterance":"Is this shirt white enough for school?","evidence":"authored 100 identical RGB(0.95,0.95,0.95) samples, not image pixels","actual_code_output":nearWhite.speech(arabic:false),"expected":"nearNeutral; cannot certify white"],["user_utterance":"What about this other shirt?","evidence":"authored 100 identical RGB(0.10,0.46,0.82) samples","actual_code_output":blue.speech(arabic:false),"expected":"estimated blue appearance, not certification"]]])
        let lines = [TextLine(text:"Milk",confidence:0.95,x:0.3,y:0.2),TextLine(text:"Milkshake",confidence:0.98,x:0.2,y:0.1)]
        let selected = ContextualTextPolicy.select(lines,goalText:"Find milk",unrestrictedReading:false)
        XCTAssertEqual(selected?.text,"Milk")
        let unrelated = ContextualTextPolicy.select(lines,goalText:"Find bread",unrestrictedReading:false)
        XCTAssertNil(unrelated)
        traces.append(["id":"FEATURE-ocr-target-change","steps":[["user_utterance":"Find milk","evidence":"authored OCR lines Milk 0.95 and Milkshake 0.98; NOT RUN image OCR","actual_code_output":selected?.text ?? "nil","expected":"Milk"],["user_utterance":"Actually, I need bread.","actual_code_output":unrelated?.text ?? "nil","expected":"nil; old text irrelevant"]]])
        let envelope: [String:Any] = ["provenance":"AUTHORED_ADAPTER_INPUT_NOT_PERCEPTION","model_output":"NOT RUN","image_ids":[],"map_id":NSNull(),"pose_id":NSNull(),"full_user_episode_status":"BLOCKED: no actual perception/model/audio","episodes":traces]
        let output = try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:envelope,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("feature-content-episodes.json"))
    }
}
