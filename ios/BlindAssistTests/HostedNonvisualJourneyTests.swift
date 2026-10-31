#if DEBUG
import XCTest
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
@testable import BlindAssist

/// Actual app controller/model invocation. Not a full UI/audio/physical journey.
@MainActor final class HostedNonvisualJourneyTests: XCTestCase {
    private let supportedJSON = #"""
{
  "REQ-SC02-1": [
    {
      "event_id": "REQ-SC02-1:0",
      "offset_ms": 0,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Tell me a joke, then help me with my homework."
    },
    {
      "event_id": "REQ-SC02-1:control",
      "offset_ms": 500,
      "kind": "test_control",
      "operation": "continue",
      "origin": "test_harness_not_sensor",
      "value": {}
    },
    {
      "event_id": "REQ-SC02-1:1",
      "offset_ms": 1000,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Okay, what comes next?"
    }
  ],
  "REQ-SC02-3": [
    {
      "event_id": "REQ-SC02-3:0",
      "offset_ms": 0,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Tell me a joke, then help me with my homework."
    },
    {
      "event_id": "REQ-SC02-3:control",
      "offset_ms": 500,
      "kind": "test_control",
      "operation": "interrupt",
      "origin": "test_harness_not_sensor",
      "value": {}
    },
    {
      "event_id": "REQ-SC02-3:1",
      "offset_ms": 1000,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Wait. Now continue what we were doing."
    }
  ],
  "REQ-SC02-4": [
    {
      "event_id": "REQ-SC02-4:0",
      "offset_ms": 0,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Tell me a joke, then help me with my homework."
    },
    {
      "event_id": "REQ-SC02-4:control",
      "offset_ms": 500,
      "kind": "test_control",
      "operation": "replace_request",
      "origin": "test_harness_not_sensor",
      "value": {
        "new_request_id": "REQ-SC02-4:replacement"
      }
    },
    {
      "event_id": "REQ-SC02-4:1",
      "offset_ms": 1000,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "No, I mean this other one, not the first one."
    }
  ],
  "REQ-SC53-1": [
    {
      "event_id": "REQ-SC53-1:0",
      "offset_ms": 0,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Please stay quiet while I listen to the story."
    },
    {
      "event_id": "REQ-SC53-1:control",
      "offset_ms": 500,
      "kind": "test_control",
      "operation": "continue",
      "origin": "test_harness_not_sensor",
      "value": {}
    },
    {
      "event_id": "REQ-SC53-1:1",
      "offset_ms": 1000,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Okay, what comes next?"
    }
  ],
  "REQ-SC53-3": [
    {
      "event_id": "REQ-SC53-3:0",
      "offset_ms": 0,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Please stay quiet while I listen to the story."
    },
    {
      "event_id": "REQ-SC53-3:control",
      "offset_ms": 500,
      "kind": "test_control",
      "operation": "interrupt",
      "origin": "test_harness_not_sensor",
      "value": {}
    },
    {
      "event_id": "REQ-SC53-3:1",
      "offset_ms": 1000,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Wait. Now continue what we were doing."
    }
  ],
  "REQ-SC53-4": [
    {
      "event_id": "REQ-SC53-4:0",
      "offset_ms": 0,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "Please stay quiet while I listen to the story."
    },
    {
      "event_id": "REQ-SC53-4:control",
      "offset_ms": 500,
      "kind": "test_control",
      "operation": "replace_request",
      "origin": "test_harness_not_sensor",
      "value": {
        "new_request_id": "REQ-SC53-4:replacement"
      }
    },
    {
      "event_id": "REQ-SC53-4:1",
      "offset_ms": 1000,
      "kind": "user_utterance",
      "origin": "authored_direct_user",
      "text": "No, I mean this other one, not the first one."
    }
  ]
}

"""#
    private func availability() -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:return "available"
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:return "deviceNotEligible"
                case .appleIntelligenceNotEnabled:return "appleIntelligenceNotEnabled"
                case .modelNotReady:return "modelNotReady"
                @unknown default:return "unknownUnavailable"
                }
            @unknown default:return "unknownAvailability"
            }
        }
        return "apiUnavailable"
        #else
        return "frameworkUnavailable"
        #endif
    }
    private func boundedRead(_ path:String, limit:Int) throws -> Data {
        let url=URL(fileURLWithPath:path)
        let a=try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        guard a.isRegularFile==true,a.isSymbolicLink != true,let size=a.fileSize,size<=limit else {throw Failure.input}
        let f=try FileHandle(forReadingFrom:url);defer{try? f.close()}
        let d=try f.read(upToCount:limit+1) ?? Data();guard d.count<=limit else{throw Failure.input};return d
    }
    private func canonical(_ value:Any) throws -> Data {try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])}
    private enum Failure:Error {case input, output, disabled}
    private func acceptedDisplayReply(requestID:String?,final:[String:Any]) -> String? {
        guard let requestID,let current=final["current_accepted_display"] as? [String:Any],
              current["request_id"] as? String == requestID,
              current["request_id"] as? String == final["request_id"] as? String,
              let generation=current["session_generation"] as? UInt64,
              generation == final["session_generation"] as? UInt64,
              current["text_truncated"] as? Bool == false,
              let leaseID=current["lease_id"] as? String,!leaseID.isEmpty,
              let revision=current["revision"] as? String,!revision.isEmpty,
              let text=current["text"] as? String else{return nil}
        let displays=final["accepted_displays"] as? [[String:Any]] ?? []
        guard displays.contains(where: { display in
            display["request_id"] as? String == requestID &&
            display["settled"] as? Bool == true && display["text_truncated"] as? Bool == false &&
            display["lease_id"] as? String == leaseID &&
            display["revision"] as? String == revision &&
            display["text"] as? String == text &&
            display["session_generation"] as? UInt64 == generation
        }) else{return nil}
        return text
    }
    func testAcceptedDisplayRequiresExactCurrentSettledReceipt() {
        let current:[String:Any]=["request_id":"r","session_generation":UInt64(1),"lease_id":"l","revision":"v","text":"actual display","text_truncated":false]
        var display=current;display["settled"]=true
        let final:[String:Any]=["request_id":"r","session_generation":UInt64(1),"current_accepted_display":current,"accepted_displays":[display]]
        XCTAssertEqual(acceptedDisplayReply(requestID:"r",final:final),"actual display")
        XCTAssertNil(acceptedDisplayReply(requestID:"old",final:final))
        for (key,value) in [("settled",false as Any),("revision","other" as Any),("lease_id","other" as Any),("text","other" as Any),("text_truncated",true as Any),("session_generation",UInt64(2) as Any)] {
            var bad=display;bad[key]=value;var changed=final;changed["accepted_displays"]=[bad]
            XCTAssertNil(acceptedDisplayReply(requestID:"r",final:changed),key)
        }
        var retired=final;retired["current_accepted_display"]=NSNull()
        XCTAssertNil(acceptedDisplayReply(requestID:"r",final:retired))
        var changed=final;changed["session_generation"]=UInt64(2)
        XCTAssertNil(acceptedDisplayReply(requestID:"r",final:changed))
    }
    func testExplicitHostedJSONLJourney() async throws {
        let env=ProcessInfo.processInfo.environment
        guard env["BLIND_J01_HOSTED"]=="1",env["BLIND_J01_EPHEMERAL_SIMULATOR"]=="1" else {throw XCTSkip("Explicit isolated simulator adapter only")}
        guard let input=env["BLIND_J01_REQUEST"],let output=env["BLIND_J01_RESPONSE"],let commit=env["BLIND_J01_SOURCE_COMMIT"],
              commit.range(of:"^[0-9a-f]{40}$",options:.regularExpression) != nil,
              !FileManager.default.fileExists(atPath:output) else{throw Failure.input}
        let request=try XCTUnwrap(JSONSerialization.jsonObject(with:boundedRead(input,limit:65536)) as? [String:Any])
        let scripts=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(supportedJSON.utf8)) as? [String:Any])
        let id=try XCTUnwrap(request["scenario_id"] as? String)
        let events=try XCTUnwrap(request["events"] as? [[String:Any]])
        guard request["schema"] as? String == "instrumented-app-jsonl-v1",request["source_commit"] as? String == commit,
              let expected=scripts[id],try canonical(events)==canonical(expected),
              try canonical(request["constraints"] ?? [:])==canonical(["physical_actions":false,"network":false,"paid_services":false]) else{throw Failure.input}
        let model=NavigationModel()
        guard model.debugBeginHostedJourney() else{throw Failure.disabled}
        let previousNarration = model.ambientDescriptions
        // Explicit isolated fixture initial state, not a sensor observation.
        if id.hasPrefix("REQ-SC53-") { model.ambientDescriptions = true }
        defer{model.debugEndHostedJourney();model.ambientDescriptions = previousNarration}
        let start=ProcessInfo.processInfo.systemUptime
        var rows:[[String:Any]]=[]
        for event in events {
            let offset=try XCTUnwrap(event["offset_ms"] as? Int)
            let remaining=Double(offset)/1000-(ProcessInfo.processInfo.systemUptime-start)
            if remaining>0 {try await Task.sleep(nanoseconds:UInt64(remaining*1_000_000_000))}
            let before=model.debugHostedJourneySnapshot
            let providerBefore=availability()
            if event["kind"] as? String == "user_utterance" {
                model.receiveCompanionUtterance(try XCTUnwrap(event["text"] as? String))
            } else {
                guard model.debugHostedJourneyControl(try XCTUnwrap(event["operation"] as? String)) else{throw Failure.input}
            }
            let snapshot=model.debugHostedJourneySnapshot
            rows.append(["event_id":event["event_id"]!,"actual_input":event,"status":"observed",
                "tool_receipts":[],"tool_receipt_coverage":"not instrumented; empty is not proof of no tool calls",
                "delivery_receipts":[["kind":"controller_snapshot","audio_delivered":false,"snapshot":snapshot]],
                "model_identity":["adapter":"LocalImageAssistant via NavigationModel","provider_availability_before_dispatch":providerBefore],
                "actual_reply":NSNull(),"reply_at_dispatch":snapshot["reply"]!,"before":before,
                "narration_state_after_dispatch":snapshot["narration_enabled"]!,
                "session_state_after_dispatch":snapshot["session_state"]!,
                "elapsed_ms":(ProcessInfo.processInfo.systemUptime-start)*1000])
        }
        // Bounded observation, not a changed production model deadline. Do not
        // count missing/late return as an answer or cancelled work as drained.
        while model.busy && ProcessInfo.processInfo.systemUptime-start<20 {
            try await Task.sleep(nanoseconds:50_000_000)
        }
        let final=model.debugHostedJourneySnapshot
        // Correlate returned model data by actual controller request identity.
        // Rejected/cancelled returns remain evidence, never delivered answers.
        let returns=final["model_returns"] as? [[String:Any]] ?? []
        for index in rows.indices where (rows[index]["actual_input"] as? [String:Any])?["kind"] as? String == "user_utterance" {
            let receipts=rows[index]["delivery_receipts"] as? [[String:Any]] ?? []
            let snapshot=receipts.first?["snapshot"] as? [String:Any] ?? [:]
            let requestID=snapshot["request_id"] as? String
            let prior=(rows[index]["before"] as? [String:Any])?["narration_receipts"] as? [[String:Any]] ?? []
            let after=snapshot["narration_receipts"] as? [[String:Any]] ?? []
            let newControlReceipts=Array(after.dropFirst(prior.count))
            rows[index]["accepted_narration_control_receipts"]=newControlReceipts
            if let returned=returns.first(where:{$0["request_id"] as? String == requestID}) {
                rows[index]["model_return"]=returned
                // A raw return is not admission, display or delivery. The
                // accepted-display boundary is checked independently below.
                rows[index]["missing_accepted_reply_receipt"]="no current settled request-correlated accepted display receipt"
                rows[index]["status"]=(returned["runtime_failure"] as? String == "none") ? "observed":"unavailable"
            } else {rows[index]["status"]="unavailable";rows[index]["missing"]="no correlated model return in observation window"}
            // Only a settled callback still owned by the actual controller at
            // final observation is an accepted display. A streaming, expired,
            // interrupted, replaced or merely returned model string is not one.
            if !newControlReceipts.isEmpty {
                rows[index]["status"]="observed"
                rows[index]["model_not_required_for_control"]=true
            }
            let displays=final["accepted_displays"] as? [[String:Any]] ?? []
            let eventDisplays=displays.filter{$0["request_id"] as? String == requestID}
            rows[index]["accepted_display_receipts"]=eventDisplays
            if let text=acceptedDisplayReply(requestID:requestID,final:final) {
                rows[index]["actual_reply"]=text
                rows[index]["actual_reply_kind"]="accepted_settled_display_not_audio"
                rows[index].removeValue(forKey:"missing_accepted_reply_receipt")
            }
        }
        let response:[String:Any]=["schema":"instrumented-app-jsonl-v1","scenario_id":id,"source_commit":commit,
            "physical_actions_applied":false,"events":rows,"final_snapshot":final,
            "claimedSourceCommit":commit,"sourceAttestation":["verified":false,"basis":"caller claim and prebuilt descriptor pin only; no binary/source attestation"],
            "observation_timed_out":model.busy,"fullJourneyComplete":false,
            "semantic_scoring":"not performed","actual_audio_delivery":false,
            "initial_narration_enabled_for_sc53":id.hasPrefix("REQ-SC53-"),
            "quiet_resume_state_only":id.hasPrefix("REQ-SC53-"),
            "urgent_alert_delivery_verified":false,
            "model_drain_acknowledged":false,"elapsed_ms":(ProcessInfo.processInfo.systemUptime-start)*1000]
        let bytes=try canonical(response)
        guard bytes.count<=1_048_576 else{throw Failure.output}
        // .withoutOverwriting prevents replacing an earlier attempt's evidence.
        try bytes.write(to:URL(fileURLWithPath:output),options:.withoutOverwriting)
    }
    func testActualNarrationHoldResumeKeepsMuteAndEndedAuthority() throws {
        guard ProcessInfo.processInfo.environment["BLIND_J01_HOSTED"] == "1",
              ProcessInfo.processInfo.environment["BLIND_J01_EPHEMERAL_SIMULATOR"] == "1" else {
            throw XCTSkip("Explicit ephemeral simulator only; no physical/audio trial")
        }
        let model=NavigationModel()
        guard model.debugBeginHostedJourney() else { throw Failure.input }
        let previous=model.ambientDescriptions
        defer {model.debugEndHostedJourney();model.ambientDescriptions=previous}
        model.ambientDescriptions=true
        let initial=model.debugHostedJourneySnapshot
        model.receiveCompanionUtterance("Please stay quiet while I listen to the story.")
        XCTAssertFalse(model.ambientDescriptions)
        XCTAssertEqual((model.debugHostedJourneySnapshot["narration_receipts"] as? [[String:Any]])?.last?["operation"] as? String,"hold")
        XCTAssertNotEqual(initial["request_id"] as? String, model.debugHostedJourneySnapshot["request_id"] as? String)
        XCTAssertNil(model.debugHostedJourneySnapshot["current_accepted_display"] as? [String:Any])
        model.muteConversation()
        let muted=model.debugHostedJourneySnapshot
        model.receiveCompanionUtterance("Wait. Now continue what we were doing.")
        XCTAssertTrue(model.ambientDescriptions)
        XCTAssertEqual((model.debugHostedJourneySnapshot["narration_receipts"] as? [[String:Any]])?.last?["operation"] as? String,"resume")
        XCTAssertEqual(model.debugHostedJourneySnapshot["session_state"] as? String,"muted")
        XCTAssertEqual(model.debugHostedJourneySnapshot["session_generation"] as? UInt64,muted["session_generation"] as? UInt64)
        XCTAssertEqual(model.debugHostedJourneySnapshot["session_should_listen"] as? Bool,false)
        model.stopDescriptions(); model.endConversation()
        let ended=model.debugHostedJourneySnapshot
        // Existing UI method may change preference but must not grant authority.
        model.resumeDescriptions()
        XCTAssertEqual(model.debugHostedJourneySnapshot["session_state"] as? String,"ended")
        XCTAssertEqual(model.debugHostedJourneySnapshot["session_generation"] as? UInt64,ended["session_generation"] as? UInt64)
        XCTAssertEqual(model.debugHostedJourneySnapshot["session_may_respond"] as? Bool,false)
        XCTAssertEqual(model.debugHostedJourneySnapshot["session_should_listen"] as? Bool,false)
        XCTAssertNil(model.debugHostedJourneySnapshot["current_accepted_display"] as? [String:Any])
    }

}
#endif
