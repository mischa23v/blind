import Foundation
import XCTest
@testable import BlindCore

final class IntegratedAttentionEpisodeTests:XCTestCase {
    func testTwelveAttentionContinuityEpisodes()throws {
        let modes=["quiet","hazard_bypasses_quiet","focused_mobility","focused_requested","focused_unrelated","expired_suppressed","duplicate_revision","changed_revision","word_budget","frequency","unknown_room","offer_decline"]
        var episodes:[[String:Any]]=[]
        for mode in modes {
            var engine=CompanionAttention(),settings=CompanionSettings(),steps:[[String:Any]]=[],failures:[String]=[]
            func check(_ c:Bool,_ e:String){if !c{failures.append(e)};XCTAssertTrue(c,"\(mode):\(e)")}
            func item(_ key:String,_ kind:InformationCandidate.Kind,_ time:Double,words:Int=6,ttl:Double=30,revision:String="1",requested:Bool=false,room:String?=nil,offer:CompanionOffer.Kind?=nil)->InformationCandidate{.init(key:key,kind:kind,text:"AUTHORED candidate \(key), not perception or spoken guidance",words:words,revision:revision,createdAt:time,expiresAt:time+ttl,requested:requested,room:room,offerKind:offer)}
            func decide(_ user:String,_ candidates:[InformationCandidate],_ moment:CompanionMoment,_ expected:[CompanionReason]) {
                let result=engine.decide(candidates,moment:moment,settings:settings)
                check(result.map(\.reason)==expected,"Actual attention reasons match required ordering/suppression")
                steps.append(["user_utterance":user,"time":moment.now,"actual_action":"CompanionAttention.decide","input_candidates":candidates.map{["key":$0.key,"kind":$0.kind.rawValue,"created_at":$0.createdAt,"expires_at":$0.expiresAt,"words":$0.words,"revision":$0.revision,"requested":$0.requested] as [String:Any]},"actual_decisions":result.map{String(describing:$0)},"expected_reasons":expected.map(\.rawValue),"pending_offer":engine.pendingOffer.map{String(describing:$0)} ?? "nil","current_room":engine.currentRoom ?? "nil"])
            }
            switch mode {
            case "quiet":
                settings.quiet=true;decide("Please be quiet while I listen.",[item("art",.discovery,0)],.init(now:0),[.quiet])
                decide("Answer only my actual question.",[item("asked",.answer,1,requested:true)],.init(now:1),[.requested])
            case "hazard_bypasses_quiet":
                settings.quiet=true;settings.wordsPerMinute=1
                decide("Stay quiet, but do not suppress independent warnings.",[item("danger",.hazard,0,ttl:1),item("art",.discovery,0)],.init(now:0,speaking:.information),[.hazard,.quiet])
                decide("Do not repeat an expired warning.",[item("old-danger",.hazard,0,ttl:0.5)],.init(now:2),[.expired])
            case "focused_mobility":
                decide("Keep helping with my current task.",[item("route",.mobility,0)],.init(now:0,focusedTaskActive:true),[.mobility])
                decide("Do not repeat the same cue.",[item("route",.mobility,1)],.init(now:1,focusedTaskActive:true),[.alreadySaid])
            case "focused_requested":
                decide("Answer my question, not clothing commentary.",[item("clothes",.social,0),item("answer",.answer,0,requested:true)],.init(now:0,focusedTaskActive:true),[.requested,.speechBusy])
                decide("We are still focusing on that question.",[item("art",.discovery,3)],.init(now:3,focusedTaskActive:true),[.goalInProgress])
            case "focused_unrelated":
                decide("I am concentrating on homework.",[item("art",.discovery,0),item("clothes",.social,0)],.init(now:0,focusedTaskActive:true),[.goalInProgress,.goalInProgress])
                decide("Now tell me something relevant after the task.",[item("fresh-art",.discovery,2)],.init(now:2),[.information])
            case "expired_suppressed":
                let old=item("art",.discovery,0,ttl:1)
                decide("Keep quiet while I finish.",[old],.init(now:0,focusedTaskActive:true),[.goalInProgress])
                decide("I finished. Do not replay stale observations.",[old],.init(now:2),[.expired])
                decide("A genuinely fresh observation may be considered.",[item("art",.discovery,3,revision:"fresh")],.init(now:3),[.information])
            case "duplicate_revision","changed_revision":
                decide("Tell me about the current scene once.",[item("art",.discovery,0)],.init(now:0),[.information])
                decide("Did the information actually change?",[item("art",.discovery,70,revision:mode == "changed_revision" ? "2":"1")],.init(now:70),[mode == "changed_revision" ? .information:.alreadySaid])
            case "word_budget":
                settings=CompanionSettings(wordsPerMinute:20)
                decide("Keep ordinary descriptions brief.",[item("one",.social,0,words:15)],.init(now:0),[.information])
                decide("Do not exceed my chosen ordinary word budget.",[item("two",.social,12,words:10)],.init(now:12),[.budget])
                decide("Necessary mobility is separate.",[item("route",.mobility,13,words:30)],.init(now:13),[.mobility])
            case "frequency":
                settings=CompanionSettings(minimumGap:10,wordsPerMinute:100)
                decide("Space out ordinary information.",[item("one",.social,0)],.init(now:0),[.information])
                decide("Not another ordinary notice immediately.",[item("two",.social,5)],.init(now:5),[.tooSoon])
                decide("Now the chosen gap has elapsed.",[item("three",.social,12)],.init(now:12),[.information])
            case "unknown_room":
                check(engine.enterRoom("bedroom",established:false) == .unconfirmed,"Appearance candidate does not establish room")
                check(engine.currentRoom==nil,"Unknown room remains unlocalized")
                decide("Do you know which room this is?",[item("identity",.offer,0,room:"bedroom",offer:.confirmRoom)],.init(now:0,goalActive:true,activity:.moving),[.offered])
                _=engine.answerOffer(.yes);engine.userConfirmedRoom("bedroom")
                check(engine.memory.rooms["bedroom"]?.visits==0,"User room name is not verified pose or established visit")
                steps.append(["user_utterance":"Yes, I call this my bedroom.","actual_action":"answerOffer / userConfirmedRoom","actual_visits":engine.memory.rooms["bedroom"]?.visits ?? -1,"expected_visits":0])
            case "offer_decline":
                engine.enterRoom("cafe",established:true)
                decide("I have arrived at a new place (authored identity fixture).",[item("room-offer",.offer,0,room:"cafe",offer:.describeRoom)],.init(now:0),[.offered])
                _=engine.answerOffer(.no)
                decide("No description, thanks.",[item("room-offer",.offer,15,room:"cafe",offer:.describeRoom)],.init(now:15),[.declined])
                check(engine.memory.hints.isEmpty,"One decline does not create a lasting preference")
            default:break
            }
            episodes.append(["id":"ATTENTION-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual goal/quiet/budget/offer/dedupe attention policy","blocked_dependencies":["real gated producers","sensor hazard detection","actual speech interruption/latency","native user preference controls"],"model_output":"NOT RUN","map_id":NSNull(),"pose_id":NSNull(),"image_ids":[],"steps":steps,"failures":failures])
        }
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("attention-component-episodes.json"))
    }
}
