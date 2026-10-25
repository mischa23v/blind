import Foundation
import XCTest
@testable import BlindCore

final class IntegratedPhotoEpisodeTests:XCTestCase {
    func testTwentySourceOwnedPhotoEpisodes() throws {
        let modes=["complete","privacy_delete","source_replace","wrong_source","late_load","deadline","clock_rollback","wrong_view","wrong_session","new_question","quiet","hazard","background","audio_loss","interrupted","wrong_finish_id","wrong_finish_text","duplicate_finish","admission_rejected","long_qualifier"]
        var episodes:[[String:Any]]=[]
        for mode in modes {
            var state=SelectedPhotoReference(),steps:[[String:Any]]=[],failures:[String]=[]
            let view=UUID(), question="Read this selected photo, including all warnings."
            let selection=try XCTUnwrap(state.select(viewID:view,generation:7,question:question,now:10))
            let text=mode == "long_qualifier" ? String(repeating:"Read the label carefully before use. ",count:25)+"Never mix bleach. Do not use on silk." : "Do not wash above 30 degrees. Never bleach. Keep all warnings."
            func source(_ identity:UUID) throws -> CompanionReferenceSource {
                let id=CompanionReferenceIdentity(sourceID:identity,revision:UUID(),sha256:try SpatialIntegrationFixture.sha256(Data(text.utf8)),media:.selectedPhoto)
                let evidence=CompanionEvidence(id:"authored-ocr-\(mode)",kind:.historicalMemory,text:text,source:id.evidenceSource)
                return .init(identity:id,toolResult:.init(status:.success,source:id.evidenceSource,evidence:[evidence]),blocks:[.init(evidence:evidence,bodyUTF16Range:NSRange(location:0,length:text.utf16.count),locator:"authored complete OCR block")])
            }
            func context(_ time:Double) -> SelectedPhotoReference.Context {
                .init(selection:state.selection!,source:state.source?.identity,viewID:view,generation:7,question:state.selection!.question,now:time)
            }
            func check(_ okay:Bool,_ expected:String) {if !okay {failures.append(expected)};XCTAssertTrue(okay,"\(mode):\(expected)")}
            func record(_ action:String,_ utterance:String,_ time:Double,_ output:Any=NSNull()) {
                steps.append(["user_utterance":utterance,"actual_action":action,"time":time,"source_age_seconds":time-10,"selected_photo_id":selection.id.uuidString,"view_id":view.uuidString,"session":7,"source_identity":state.source.map{String(describing:$0.identity)} ?? "nil","state":["completed":state.completed,"withdrawn":state.withdrawn,"phrases":state.phrases.count],"actual_output":output,"raw_image_id":"NONE; authored extracted-text fixture, Photos/Vision NOT RUN","model_output":"NOT RUN"])
            }
            record("select",question,10)
            let input=try source(mode == "wrong_source" ? UUID() : selection.id)
            let installed=state.install(input,for:selection,now:mode == "late_load" ? 71:11)
            record("install complete source", "Make sure you keep the warnings.",mode == "late_load" ? 71:11,["accepted":installed,"text":text,"sha256":input.identity.sha256])
            if mode == "wrong_source" || mode == "late_load" {
                check(!installed,"Wrong-source or late source must not install")
            } else {
                check(installed,"Exact timely source installs")
                check(state.phrases.map(\.originalSlice).joined()==text,"Complete qualifiers preserved")
                switch mode {
                case "privacy_delete":
                    state.clear();check(!state.install(input,for:selection,now:12),"Privacy deletion rejects late extraction")
                    record("clear / reject delayed install","Forget this photo and its text.",12)
                case "source_replace":
                    let oldContext=context(11),old=try XCTUnwrap(state.next(oldContext));check(state.begin(old,context:oldContext),"Original playback begins")
                    let newSelection=try XCTUnwrap(state.select(viewID:view,generation:7,question:"Read the other photo.",now:12))
                    check(state.install(try source(newSelection.id),for:newSelection,now:12),"Replacement owns its source")
                    check(!state.finish(id:old.id,text:old.text,outcome:.completed,context:context(12)),"Old completion cannot advance replacement")
                    record("replace / reject old completion","No, read the other photo instead.",12)
                case "deadline","clock_rollback","wrong_view","wrong_session","new_question","quiet","hazard","background","audio_loss":
                    let time=mode == "deadline" ? 70.0 : mode == "clock_rollback" ? 9.0:12.0
                    var changed=context(time)
                    switch mode {
                    case "wrong_view":changed = .init(selection:selection,source:state.source?.identity,viewID:UUID(),generation:7,question:question,now:time)
                    case "wrong_session":changed = .init(selection:selection,source:state.source?.identity,viewID:view,generation:8,question:question,now:time)
                    case "new_question":changed = .init(selection:selection,source:state.source?.identity,viewID:view,generation:7,question:"Where is it now?",now:time)
                    case "quiet":changed.quiet=true
                    case "hazard":changed.hazard=true
                    case "background":changed.foreground=false
                    case "audio_loss":changed.privateAudioHeld=true
                    default:break
                    }
                    let next=state.next(changed);check(next == nil,"Changed source/lifecycle/deadline withdraws output")
                    check(state.next(context(72)) == nil,"Withdrawal cannot revive pending phrases")
                    record("next with \(mode) / prevent revival","Pause this reading while something changes.",time,["actual_next":next?.text ?? "nil"])
                default:
                    let c=context(12),phrase=try XCTUnwrap(state.next(c));check(state.begin(phrase,context:c),"Owned phrase begins")
                    record("next / begin", "Read it now.",12,["phrase_id":phrase.id.uuidString,"actual_code_text":phrase.text])
                    if mode == "interrupted" {
                        check(!state.finish(id:phrase.id,text:phrase.text,outcome:.interrupted,context:c),"Interruption is not completion")
                        check(!state.finish(id:phrase.id,text:phrase.text,outcome:.completed,context:c),"Late completion after interruption rejected")
                        record("interrupted / reject late completed callback","Stop. I need to listen to someone.",12)
                    } else if mode == "admission_rejected" {
                        state.admissionRejected(phrase.id);check(state.completed == 0,"Rejected speech not heard")
                        check(state.next(c)==phrase,"Same owned phrase remains pending without deadline renewal")
                        check(state.next(context(70)) == nil,"Original deadline still expires")
                        record("admission rejected / original deadline","Try reading it when speech is available.",70)
                    } else {
                        if mode == "wrong_finish_id" {check(!state.finish(id:UUID(),text:phrase.text,outcome:.completed,context:c),"Wrong callback ID rejected")}
                        if mode == "wrong_finish_text" {check(!state.finish(id:phrase.id,text:"Warnings removed",outcome:.completed,context:c),"Changed delivered text rejected")}
                        check(state.finish(id:phrase.id,text:phrase.text,outcome:.completed,context:c),"Exact simulated completion advances once")
                        if mode == "duplicate_finish" {check(!state.finish(id:phrase.id,text:phrase.text,outcome:.completed,context:c),"Duplicate completion rejected")}
                        record("finish simulated exact completion","Continue with the next part.",12)
                        while let next=state.next(context(13)) {check(state.begin(next,context:context(13)),"Next phrase begins");check(state.finish(id:next.id,text:next.text,outcome:.completed,context:context(13)),"Next exact completion accepted");record("next / exact simulated completion","Continue.",13,next.text)}
                        check(state.completed==state.phrases.count,"All preserved phrases completed by ledger callbacks")
                    }
                }
            }
            episodes.append(["id":"PHOTO-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","executed_scope":"Actual selected-photo source ownership, chunking and simulated speech lifecycle","blocked_dependencies":["Photos selection","Vision OCR","actual speech completion","device/private storage"],"is_full_user_episode":false,"steps":steps,"failures":failures])
        }
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("photo-component-episodes.json"))
    }
}
