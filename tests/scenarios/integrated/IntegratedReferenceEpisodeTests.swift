import Foundation
import XCTest
@testable import BlindCore

final class IntegratedReferenceEpisodeTests:XCTestCase {
    func testTwentyExactManualReferenceEpisodes()throws {
        let modes=["complete","quiet","hazard","background","new_request","source_change","deadline","clock_rollback","interrupted","foreign_callback","duplicate_callback","busy_ledger","wrong_model","current_evidence","heading_only","bad_body_range","wrong_digest","wrong_media","empty_query","long_qualifier"]
        var episodes:[[String:Any]]=[]
        for mode in modes {
            var steps:[[String:Any]]=[],failures:[String]=[]
            func check(_ c:Bool,_ e:String){if !c{failures.append(e)};XCTAssertTrue(c,"\(mode):\(e)")}
            let body=mode == "heading_only" ? "Only warranty contact details appear in this body.":(mode == "long_qualifier" ? String(repeating:"For this authored model, delay start is an example setting. ",count:20):"For this authored model, delay start is unavailable on rinse.")+" Never treat this reference as current device status."
            let heading="Delay start\n",text=heading+body,sourceID=UUID(),revision=UUID()
            let identity=CompanionReferenceIdentity(sourceID:sourceID,revision:revision,sha256:try SpatialIntegrationFixture.sha256(Data(text.utf8)),media:.manual,exactModel:"AUTHORED-WASHER-A")
            let wrong=CompanionReferenceIdentity(sourceID:sourceID,revision:revision,sha256:mode == "wrong_digest" ? String(repeating:"0",count:64):identity.sha256,media:mode == "wrong_media" ? .selectedPhoto:.manual,exactModel:mode == "wrong_model" ? "AUTHORED-WASHER-B":"AUTHORED-WASHER-A")
            let evidence=CompanionEvidence(id:"authored-manual-block",kind:mode == "current_evidence" ? .currentObservation:.historicalMemory,text:text,source:identity.evidenceSource)
            let block=CompanionReferenceBlock(evidence:evidence,bodyUTF16Range:mode == "bad_body_range" ? NSRange(location:text.utf16.count+10,length:5):(text as NSString).range(of:body),locator:"authored page1 paragraph1")
            let source=CompanionReferenceSource(identity:identity,toolResult:.init(status:.success,source:identity.evidenceSource,evidence:[evidence]),blocks:[block])
            let binding=CompanionReferenceReading.Binding(requestID:UUID(),generation:7)
            steps.append(["user_utterance":"Read the delay-start instructions for this exact manual.","actual_action":"prepare reference input","source_id":sourceID.uuidString,"source_revision":revision.uuidString,"source_sha256":identity.sha256,"exact_model":"AUTHORED-WASHER-A","source_text":text,"body_range":[block.bodyUTF16Range.location,block.bodyUTF16Range.length],"time":100])
            let shouldReject=["wrong_model","current_evidence","heading_only","bad_body_range","wrong_digest","wrong_media","empty_query"].contains(mode)
            do {
                var reading=try CompanionReferenceReading.prepare(request:.init(kind:.readText,query:mode == "empty_query" ? "":"delay start"),binding:binding,selectedSource:["wrong_model","wrong_digest","wrong_media"].contains(mode) ? wrong:identity,source:source,issuedAt:100,monotonicNow:100)
                check(!shouldReject,"Invalid exact source/query/body must reject at prepare")
                check(reading.chunks.map(\.originalSlice).joined()==text,"Complete original bytes and qualifiers survive chunking")
                check(reading.chunks.allSatisfy{CompanionReferenceReading.wordCount($0.spokenText)<=35},"Every attributed chunk remains within word bound")
                func context(_ time:Double)->CompanionReferenceReading.Context{.init(binding:binding,selectedSource:identity,monotonicNow:time)}
                var ledger=SpeechDeliveryLedger()
                if mode == "busy_ledger" {
                    let existing=try XCTUnwrap(ledger.begin(text:"An existing requested answer",priority:.information,destination:.requested(UUID()),transport:.synthesized))
                    check(reading.beginNext(ledger:&ledger,context:context(101)) == nil,"Busy ledger cannot skip or preempt existing requested speech")
                    _ = ledger.finish(token:existing.token,outcome:.completed,now:102)
                    steps.append(["user_utterance":"Wait for the other answer before reading.","actual_action":"busy-ledger admission blocked then released","time":102,"completed_chunks":reading.completedChunkCount])
                }
                let first=try XCTUnwrap(reading.beginNext(ledger:&ledger,context:context(103)))
                steps.append(["user_utterance":"Read it now.","actual_action":"beginNext actual code chunk","time":103,"age_seconds":3,"chunk_id":first.chunk.id.uuidString,"speech_token":first.attempt.token.uuidString,"actual_code_text":first.chunk.spokenText,"completed_chunks":reading.completedChunkCount])
                if ["quiet","hazard","background","new_request","source_change","deadline","clock_rollback"].contains(mode) {
                    let time=mode == "deadline" ? 160.0:mode == "clock_rollback" ? 102.0:104.0
                    let changed=CompanionReferenceReading.Context(binding:mode == "new_request" ? .init(requestID:UUID(),generation:7):binding,selectedSource:mode == "source_change" ? .init(sourceID:UUID(),revision:revision,sha256:identity.sha256,media:.manual,exactModel:"AUTHORED-WASHER-A"):identity,monotonicNow:time,foreground:mode != "background",quiet:mode == "quiet",hazard:mode == "hazard")
                    check(!reading.revalidate(changed),"Lifecycle/source/deadline change withdraws source-bound reading")
                    check(reading.withdrawnSpeechID == first.chunk.id,"Only exact requested chunk is retired")
                    check(reading.beginNext(ledger:&ledger,context:context(161)) == nil,"Withdrawn reference cannot resume")
                    steps.append(["user_utterance":"Stop this reading while the context changes.","actual_action":"revalidate \(mode) / withhold revival","time":time,"state":String(describing:reading.state),"withdrawn_chunk_id":reading.withdrawnSpeechID?.uuidString ?? "nil","completed_chunks":reading.completedChunkCount])
                } else if mode == "interrupted" {
                    let completion=try XCTUnwrap(ledger.finish(token:first.attempt.token,outcome:.interrupted,now:104))
                    check(!reading.complete(completion,context:context(104)),"Interrupted delivery is not completed content")
                    check(reading.completedChunkCount==0,"Interrupted reference does not advance")
                    steps.append(["user_utterance":"Stop. I need to listen.","actual_action":"complete interrupted callback","time":104,"state":String(describing:reading.state)])
                } else {
                    if mode == "foreign_callback" {
                        var foreign=SpeechDeliveryLedger();let attempt=try XCTUnwrap(foreign.begin(text:first.chunk.spokenText,priority:.information,destination:.requested(first.chunk.id),transport:.synthesized))
                        let completion=try XCTUnwrap(foreign.finish(token:attempt.token,outcome:.completed,now:104))
                        check(!reading.complete(completion,context:context(104)),"Foreign exact-text callback cannot advance source")
                        steps.append(["user_utterance":"That was another speech attempt.","actual_action":"reject foreign ledger callback","time":104,"foreign_token":attempt.token.uuidString,"actual_completed_chunks":reading.completedChunkCount])
                    }
                    let completion=try XCTUnwrap(ledger.finish(token:first.attempt.token,outcome:.completed,now:105))
                    check(reading.complete(completion,context:context(105)),"Own exact terminal callback advances")
                    if mode == "duplicate_callback" {check(!reading.complete(completion,context:context(105)),"Duplicate terminal callback cannot advance twice")}
                    var time=106.0
                    while reading.state != .completed {
                        guard let next=reading.beginNext(ledger:&ledger,context:context(time)) else {check(false,"Valid remaining source chunk should dispatch");break}
                        let completed=try XCTUnwrap(ledger.finish(token:next.attempt.token,outcome:.completed,now:time+0.1))
                        check(reading.complete(completed,context:context(time+0.1)),"Exact simulated completion advances remaining source")
                        steps.append(["user_utterance":"Continue without dropping warnings.","actual_action":"next / simulated exact completion","time":time,"chunk_id":next.chunk.id.uuidString,"actual_code_text":next.chunk.spokenText,"completed_chunks":reading.completedChunkCount]);time+=0.2
                    }
                    check(reading.completedChunkCount == reading.chunks.count,"Entire qualified source completes")
                }
            } catch {
                check(shouldReject,"Unexpected actual code exception \(error)")
                steps.append(["user_utterance":"Use only the matching complete source.","actual_action":"prepare rejected","time":100,"actual_error":String(describing:error),"expected_prepare_rejection":shouldReject])
            }
            episodes.append(["id":"REFERENCE-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual complete-source/manual identity/chunking/SpeechDeliveryLedger methods","blocked_dependencies":["native exact-model manual/PDF acquisition","real extraction","audio completion"],"provenance":"AUTHORED MANUAL TEXT; not manufacturer instructions or model output","model_output":"NOT RUN","image_ids":[],"map_id":NSNull(),"pose_id":NSNull(),"steps":steps,"failures":failures])
        }
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("reference-component-episodes.json"))
    }
}
