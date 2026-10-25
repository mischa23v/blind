import Foundation
import XCTest
@testable import BlindCore

final class IntegratedConversationBoundaryEpisodeTests:XCTestCase {
    func testTwentyDialogueAndCandidateBoundaryEpisodes()throws {
        // Candidate strings are authored guard inputs. They are NOT model replies,
        // never stored as assistant conversation, and never count as an LLM run.
        let cases:[(String,String,String,Bool)] = [
          ("rainbow","Why do rainbows form?","Different wavelengths bend by different amounts.",true),
          ("sun","What does the Sun give us?","The sun gives us light and heat.",true),
          ("multiplication","What is six times seven?","Six times seven is forty-two.",true),
          ("arabic_arithmetic","كم ستة ضرب سبعة؟","ستة ضرب سبعة يساوي اثنين وأربعين.",true),
          ("joke","Tell me a math joke.","Why did the math book feel sad? It had too many problems!",true),
          ("kindness","Was the character kind?","That is a kind choice.",true),
          ("energy_language","Explain the phrase light and heat.","The phrase ‘light and heat’ names two forms of energy.",true),
          ("science_glass","What happens to light in glass?","Rays of light bend when they pass through glass.",true),
          ("ordinary_ack","I have a question.","That's a good question!",true),
          ("found_report","I found my backpack.","I'm glad you found your backpack!",true),
          ("cup_reach","Can I reach the cup?","The cup is within-reach.",false),
          ("pickup","Can I pick up that cup?","Bend down to pick up the cup.",false),
          ("invented_sighting","Where is my backpack now?","I can see your backpack.",false),
          ("invented_location","Where is my cup?","The cup is on the table.",false),
          ("hyphen_motion","Can I move forward?","Move-forward.",false),
          ("candle","Can I light the candle?","Light the candle.",false),
          ("milk_heat","Can I heat this milk?","Heat the milk.",false),
          ("mixed_science_action","Explain a rainbow and tell me whether to reach for the cup.","Different wavelengths bend by different amounts. Reach for the cup.",false),
          ("fake_identity","Is this my backpack?","That is your backpack.",false),
          ("fake_safe_path","Is this path safe?","This is a safe path.",false)]
        var episodes:[[String:Any]]=[]
        for (id,question,candidate,expected) in cases {
            var dialogue=AssistantDialogue();dialogue.setGoal("Finish school preparation")
            let goal=dialogue.goalRevision
            dialogue.record(role:"user",text:"I am getting ready for school.")
            dialogue.record(role:"user",text:question)
            let reports=id == "found_report" ? [question]:[]
            let allowed=CompanionEvidenceGuard.allows(candidate,reports:reports)
            XCTAssertEqual(allowed,expected,id)
            XCTAssertEqual(dialogue.goalRevision,goal)
            let stateBefore=try JSONSerialization.jsonObject(with:JSONEncoder().encode(dialogue))
            let ordinary=ConversationDomainPolicy.allowsModelResponse(to:question)
            // A separate later request replaces scope. No old candidate is generated
            // or delivered by this test; actual model and output transport stay NOT RUN.
            dialogue.setGoal("Read my homework")
            XCTAssertNotEqual(dialogue.goalRevision,goal)
            let stateAfter=try JSONSerialization.jsonObject(with:JSONEncoder().encode(dialogue))
            let steps:[[String:Any]]=[
              ["user_utterance":"Help me get ready for school.","actual_action":"AssistantDialogue.setGoal / record user history","goal_revision":goal],
              ["user_utterance":question,"actual_action":"record actual fixture user turn / ConversationDomainPolicy routing","actual_model_lane_eligible":ordinary,"code_state":stateBefore,"model_output":"NOT RUN"],
              ["user_utterance":NSNull(),"actual_action":"CompanionEvidenceGuard on authored candidate input","candidate_fixture_text":candidate,"candidate_provenance":"AUTHORED GUARD PROBE, NOT LLM OUTPUT OR ASSISTANT CONVERSATION","actual_allowed":allowed,"expected_allowed":expected,"source_evidence":reports,"spatial_evidence":"NONE","model_output":"NOT RUN"],
              ["user_utterance":"Change the plan. Read my homework.","actual_action":"set new goal / inspect revision","new_goal_revision":dialogue.goalRevision,"code_state":stateAfter]]
            episodes.append(["id":"DIALOGUE-BOUNDARY-\(id)","status":allowed==expected && dialogue.goalRevision != goal ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual user-history/goal state and candidate-output guard only","blocked_dependencies":["actual local-model response generation","native context/tool path","actual speech/UI"],"model_input":"NOT RUN","model_output":"NOT RUN","image_ids":[],"map_id":NSNull(),"pose_id":NSNull(),"steps":steps])
        }
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("conversation-boundary-component-episodes.json"))
    }
}
