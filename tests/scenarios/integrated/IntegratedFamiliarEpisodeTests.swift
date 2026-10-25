import Foundation
import XCTest
@testable import BlindCore

final class IntegratedFamiliarEpisodeTests:XCTestCase {
    func testTwentyConsentCandidateEncounterEpisodes()throws {
        let modes=["candidate_notice","missing_consent","cancelled_consent","expired_consent","wrong_token","token_replay","lookalike","tie","unknown_score","duplicate_identity","missing_vision","vision_disagreement","vision_cannot_promote","empty_gallery","invalid_score","face_not_visible","duplicate_face_assignment","search_timeout","search_spacing","search_exhaustion"]
        var episodes:[[String:Any]]=[]
        for mode in modes {
            var confirmation=FamiliarActionConfirmation(),encounter=FamiliarEncounterPolicy(),steps:[[String:Any]]=[],failures:[String]=[]
            let person=UUID(),other=UUID()
            func check(_ c:Bool,_ e:String){if !c{failures.append(e)};XCTAssertTrue(c,"\(mode):\(e)")}
            func record(_ user:String,_ action:String,_ time:Double,_ output:Any){steps.append(["user_utterance":user,"actual_action":action,"time":time,"actual_output":output,"identity_a":person.uuidString,"identity_b":other.uuidString,"image_ids":[],"pose_id":NSNull(),"model_output":"NOT RUN","provenance":"Authored candidate scores/consent callbacks; no person recognized or enrolled"])}
            let token=try XCTUnwrap(confirmation.request(now:10))
            record("I want you to remember my teacher, with their consent.","request one-shot confirmation token (not gallery enrollment)",10,["token":token.uuidString])
            var consent=false
            switch mode {
            case "missing_consent":break
            case "cancelled_consent":confirmation.cancel();consent=confirmation.consume(token,now:11)
            case "expired_consent":consent=confirmation.consume(token,now:41)
            case "wrong_token":consent=confirmation.consume(UUID(),now:11)
            default:consent=confirmation.consume(token,now:11)
            }
            let expectedConsent = !["missing_consent","cancelled_consent","expired_consent","wrong_token"].contains(mode)
            check(consent == expectedConsent,"Consent-token behavior matches exact pending request")
            record(expectedConsent ? "Yes, proceed with the confirmed action.":"Do not use an absent, expired or cancelled permission.","consume or withhold confirmation",mode == "expired_consent" ? 41:11,["accepted":consent,"expected":expectedConsent])
            if mode == "token_replay" {check(!confirmation.consume(token,now:12),"One-shot consent cannot be replayed");record("Use that old approval again.","reject replay",12,false)}
            if expectedConsent {
                if mode.hasPrefix("search_") {
                    var budget=FamiliarSearchBudget(startedAt:10)
                    let first=budget.consumeAttempt(now:10);check(first,"Initial actual search attempt available")
                    var results=[first]
                    if mode == "search_timeout" {results.append(budget.consumeAttempt(now:31));check(results.last == false,"Search past20seconds ends")}
                    if mode == "search_spacing" {results.append(budget.consumeAttempt(now:11));results.append(budget.consumeAttempt(now:12));check(results == [true,false,true],"Spacing rejection does not spend next valid attempt")}
                    if mode == "search_exhaustion" {for time in [12.0,14,16,18,20,22]{results.append(budget.consumeAttempt(now:time))};check(results == [true,true,true,true,true,true,false],"Six attempts bound search; seventh rejected")}
                    record("Help me find my teacher without repeating forever.","FamiliarSearchBudget.consumeAttempt",32,["actual_attempt_admissions":results])
                } else {
                    var scores:[(id:UUID,cosine:Double)]=[(person,0.8),(other,0.3)]
                    switch mode {
                    case "lookalike":scores=[(person,0.8),(other,0.75)]
                    case "tie":scores=[(person,0.8),(other,0.8)]
                    case "unknown_score","vision_cannot_promote":scores=[(person,0.2),(other,0.1)]
                    case "duplicate_identity":scores=[(person,0.8),(person,0.3)]
                    case "empty_gallery","face_not_visible":scores=[]
                    case "invalid_score":scores=[(person,.nan)]
                    default:break
                    }
                    let candidate=FamiliarFacePolicy.candidate(scores:scores)
                    let expectedCandidate = !["lookalike","tie","unknown_score","duplicate_identity","empty_gallery","face_not_visible","invalid_score","vision_cannot_promote"].contains(mode)
                    check((candidate != nil) == expectedCandidate,"Candidate threshold/margin/shape gate abstains as expected; not accuracy evidence")
                    record("Is that the same person?","FamiliarFacePolicy.candidate from AUTHORED scores",12,["scores":scores.map{["id":$0.id.uuidString,"cosine":$0.cosine.isFinite ? String($0.cosine):"NaN"]},"candidate_id":candidate?.uuidString ?? "nil","expected_candidate_present":expectedCandidate])
                    var admissible=candidate
                    if ["missing_vision","vision_disagreement","vision_cannot_promote"].contains(mode) {
                        let distances:[(id:UUID,distance:Double)] = mode == "missing_vision" ? [(person,0.1)]:mode == "vision_disagreement" ? [(person,0.3),(other,0.1)]:[(person,0.1),(other,0.4)]
                        admissible=FamiliarFacePolicy.corroboratedCandidate(sface:candidate,visionDistances:distances,expectedIDs:[person,other])
                        check(admissible == nil,"Incomplete/disagreeing corroboration cannot invent or promote identity")
                        record("Can the other checker make an unknown face known?","corroboratedCandidate veto-only gate",13,["actual_candidate":admissible?.uuidString ?? "nil"])
                    }
                    if mode == "duplicate_face_assignment" {
                        let batch=FamiliarFaceBatchPolicy.uniqueCandidates([person,person]);check(batch.allSatisfy{$0 == nil},"One identity cannot be assigned to two faces")
                        admissible=nil;record("There are two faces. Are they both the same person?","uniqueCandidates duplicate abstention",13,batch.map{$0?.uuidString ?? "nil"})
                    }
                    let identities=admissible.map{[$0]} ?? []
                    let first=encounter.observe(identities,detectedFaces:1,now:14),second=encounter.observe(identities,detectedFaces:1,now:15)
                    check(first.isEmpty,"One authored candidate is not yet an encounter notice")
                    check(second == identities,"Only two stable admissible IDs become notice candidates")
                    second.forEach{encounter.markAnnounced($0)}
                    let third=encounter.observe(identities,detectedFaces:1,now:16);check(third.isEmpty,"Admitted encounter is not repeatedly announced")
                    record("Tell me once if a verified familiar person arrives.","observe twice / mark admitted / deduplicate",16,["first":first.map(\.uuidString),"second":second.map(\.uuidString),"third":third.map(\.uuidString)])
                }
            }
            encounter.reset();check(encounter.encounterID(for:person) == nil,"Reset removes transient encounter identity")
            record("Forget this encounter.","reset encounter policy (not gallery deletion)",50,true)
            episodes.append(["id":"FAMILIAR-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual one-shot confirmation, uncalibrated candidate veto, encounter dedupe and search budget","blocked_dependencies":["self/guardian real consent workflow","real enrolled protected gallery","face feature extraction and accuracy","native audio","physical identity"],"steps":steps,"failures":failures])
        }
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("familiar-component-episodes.json"))
    }
}
