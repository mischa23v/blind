import Foundation
import XCTest
@testable import BlindCore

/// Systematic matrix, NOT 100 independent real-world/model trials. Each row executes
/// actual domain code + source/goal-aware coordinator transitions with authored inputs.
final class IntegratedEverydayEpisodeTests: XCTestCase {
    let all = Set(EverydayCapability.allCases)
    let date = Date(timeIntervalSince1970:1_700_000_000)
    func encoded<T: Encodable>(_ value:T) throws -> Any { try JSONSerialization.jsonObject(with:JSONEncoder().encode(value)) }
    func state(_ task:EverydayTaskCoordinator) -> [String:Any] {
        ["goal_id":task.goal?.id.uuidString ?? "nil","goal":task.goal?.description ?? "nil","request":task.request?.query ?? "nil","state":task.state.rawValue,"completed":task.completedSubtasks,"attempts":task.attempts,"historical_clue":task.historicalClueAvailable,"last_failure":task.lastFailure?.rawValue ?? "nil","prompts":task.emittedPromptCount]
    }
    func ticket(_ task:inout EverydayTaskCoordinator,_ now:Double) throws -> EverydayTaskCoordinator.Ticket {
        guard case .run(let result) = task.next(available:all,now:now) else { throw NSError(domain:"expected actual adapter ticket",code:1) }; return result
    }
    func content(_ capability:EverydayCapability, id:String) throws -> [String:Any] {
        switch capability {
        case .deviceClock:
            let result=CompanionClock.read(now:date,timeZone:TimeZone(identifier:"Asia/Riyadh")!,arabic:false)
            return ["oracle_pass":result.status == .success && result.evidence.count == 1 && CompanionClock.isClockEvidence(result.evidence[0]),"expected":"one canonical code-owned clock record","actual_code":"CompanionClock.read","input_date":date.timeIntervalSince1970,"timezone":"Asia/Riyadh","output":try encoded(result)]
        case .savedMemory,.findItem:
            let item=RememberedItem(name:"backpack",roomName:"bedroom",savedAt:date.addingTimeInterval(-30))
            let result=CompanionMemoryRetrieval.read(query:"Where is my backpack?",now:date,savedItems:[item])
            return ["oracle_pass":result.evidence.count == 1 && result.evidence[0].kind == .historicalMemory,"expected":"one historical item record, no current presence","actual_code":"CompanionMemoryRetrieval.read","input_record":"authored remembered backpack, bedroom, 30 seconds old","output":try encoded(result),"current_presence":"NOT ESTABLISHED"]
        case .readText:
            var reader=LiveTextReader()
            let lines=[TextLine(text:"Homework: read chapter two",confidence:0.98,x:0.2,y:0.2)]
            let first=reader.newLines(lines,now:10), duplicate=reader.newLines(lines,now:10.2)
            return ["oracle_pass":first == ["Homework: read chapter two"] && duplicate.isEmpty,"expected":"one first line and no duplicate","actual_code":"LiveTextReader.newLines","input":"authored OCR text, confidence0.98,x0.2,y0.2","output":first,"duplicate_output":duplicate,"image_ocr":"NOT RUN"]
        case .readDocument:
            let guidance=DocumentGuidance.evaluate([(x:0.15,y:0.15),(x:0.85,y:0.15),(x:0.85,y:0.85),(x:0.15,y:0.85)])
            return ["oracle_pass":guidance == .holdStill,"expected":"holdStill for centered authored page corners; no physical delivery","actual_code":"DocumentGuidance.evaluate","input_corners":[[0.15,0.15],[0.85,0.15],[0.85,0.85],[0.15,0.85]],"output":guidance.speech(arabic:false),"document_ocr":"NOT RUN"]
        case .barcode:
            var memory=ProductMemory(); let saved=memory.save("Breakfast cereal",for:"AUTHORED-CODE-42")
            let output=CodeReading.speech(payload:"AUTHORED-CODE-42",isQR:false,savedName:memory.name(for:"AUTHORED-CODE-42"),arabic:false)
            memory.forget("AUTHORED-CODE-42")
            return ["oracle_pass":saved && output == "This is Breakfast cereal." && memory.name(for:"AUTHORED-CODE-42") == nil,"expected":"saved label then deleted lookup; no product contents claim","actual_code":"ProductMemory.save / CodeReading.speech / forget","input":"authored code AUTHORED-CODE-42; user-provided label Breakfast cereal","saved":saved,"output":output,"deleted":memory.name(for:"AUTHORED-CODE-42") == nil,"barcode_detection":"NOT RUN"]
        case .clothingColor:
            let result=ClothingColor.evaluate(Array(repeating:.init(0.95,0.95,0.95),count:100))
            return ["oracle_pass":result == .nearNeutral,"expected":"nearNeutral, never certified white","actual_code":"ClothingColor.evaluate","input":"100 authored RGB(0.95,0.95,0.95) values; not an image","output":result.speech(arabic:false),"actual_result":String(describing:result)]
        case .currency:
            var consensus=ContextualCurrencyConsensus()
            let first=consensus.observe(verifiedDenomination:5,capturedAt:10,now:10,sessionGeneration:7)
            let second=consensus.observe(verifiedDenomination:5,capturedAt:11,now:11,sessionGeneration:7)
            let reset=consensus.observe(verifiedDenomination:5,capturedAt:12,now:12,sessionGeneration:8)
            return ["oracle_pass":first == nil && second == 5 && reset == nil,"expected":"first withheld, second5, new session withheld","actual_code":"ContextualCurrencyConsensus.observe","input":"authored verifiedDenomination5 at10/11; session7 then8; recognizer NOT RUN","first":first.map{$0 as Any} ?? NSNull(),"second":second.map{$0 as Any} ?? NSNull(),"after_session_change":reset.map{$0 as Any} ?? NSNull()]
        case .familiarPerson:
            var policy=FamiliarEncounterPolicy(); let person=UUID()
            let first=policy.observe([person],detectedFaces:1,now:10), second=policy.observe([person],detectedFaces:1,now:11)
            policy.markAnnounced(person)
            let repeatNotice=policy.observe([person],detectedFaces:1,now:12)
            return ["oracle_pass":first.isEmpty && second == [person] && repeatNotice.isEmpty,"expected":"two matches before one notice; no duplicate","actual_code":"FamiliarEncounterPolicy.observe / markAnnounced","input":"authored consented identity UUID, not image comparison","identity":person.uuidString,"first":first.map(\.uuidString),"second":second.map(\.uuidString),"repeated":repeatNotice.map(\.uuidString),"recognition":"NOT RUN"]
        case .light:
            let low=LightLevel.from(lumens:30), high=LightLevel.from(lumens:1000)
            return ["oracle_pass":low == .dark && high == .medium,"expected":"30 dark and1000 medium; not switch state","actual_code":"LightLevel.from","input":"authored ambient values30 and1000; no sensor","output":[low?.speech(arabic:false) ?? "nil",high?.speech(arabic:false) ?? "nil"],"switch_state":"NOT ESTABLISHED"]
        }
    }
    func testHundredStatefulCapabilityEpisodes() throws {
        let cases:[(EverydayCapability,String,String)]=[
          (.savedMemory,"What do you remember about my backpack?","Prepare for school"),(.findItem,"Where is my backpack?","Leave for school"),
          (.readText,"Read this homework line.","Finish homework"),(.readDocument,"Read this whole page.","Review a document"),
          (.barcode,"Remember this cereal label, then identify its code.","Prepare breakfast"),(.clothingColor,"Is this shirt white or gray?","Get dressed for school"),
          (.currency,"How much money am I holding?","Pay for a snack"),(.familiarPerson,"Has my teacher arrived?","Meet my teacher"),
          (.light,"How bright is it here?","Get ready for bed"),(.deviceClock,"What time is it?","Leave on time")]
        let modes=["successful_information","pause_resume","goal_replacement","cancel","timeout","uncertain_retry","backend_unavailable","duplicate_callback","repeat_goal","clock_regression"]
        var episodes:[[String:Any]]=[]
        for (capability,utterance,goal) in cases {
            for mode in modes {
                let id="EVERYDAY-\(capability.rawValue)-\(mode)"
                var task=EverydayTaskCoordinator(), steps:[[String:Any]]=[], failures:[String]=[]
                func verify(_ condition:Bool,_ expectation:String) { if !condition {failures.append(expectation)}; XCTAssertTrue(condition,"\(id): \(expectation)") }
                func record(_ action:String,_ text:String,_ time:Double,_ output:Any=NSNull()) {
                    steps.append(["index":steps.count,"user_utterance":text,"actual_action":action,"time":time,"state":state(task),"actual_output":output,"source_input":"AUTHORED COMPONENT INPUT","image_ids":[],"map_id":NSNull(),"pose_id":NSNull(),"model_input":"NOT RUN","model_output":"NOT RUN","audio":"NOT RUN"])
                }
                do {
                    task.setGoal(goal); let originalGoal=task.goal
                    task.begin(try XCTUnwrap(EverydayTaskRequest(capability:capability,query:utterance)))
                    record("setGoal / begin typed source-bound request",utterance,0)
                    if capability == .findItem {
                        let memory=try ticket(&task,0)
                        verify(memory.request.capability == .savedMemory,"Find task first selects saved memory")
                        let memoryResult=try content(.savedMemory,id:id)
                        task.receive(memory,outcome:.historicalClue,now:0.1)
                        record("actual memory adapter / receive historical clue","What did I tell you before?",0.1,memoryResult)
                    }
                    if mode == "backend_unavailable" {
                        let output=task.next(available:[],now:1)
                        verify(output == .unavailable(capability),"Unavailable exact backend never executes")
                        record("next with unavailable backend","Can you still do it offline?",1,String(describing:output))
                        verify(task.completedSubtasks.isEmpty,"Unavailable content does not complete physical task")
                        record("inspect retained goal and incomplete task","Keep my goal, even if that tool is unavailable.",2)
                    } else {
                        let first=try ticket(&task,1)
                        record("next / actual selected tool",utterance,1,["ticket_id":first.id.uuidString,"issued_at":first.issuedAt,"tool":first.request.capability.rawValue])
                        let output=try content(capability,id:id)
                        verify(output["oracle_pass"] as? Bool == true,"Domain adapter matches predeclared content oracle")
                        record("execute actual domain adapter with authored input","What information do you have?",1.2,output)
                        switch mode {
                        case "successful_information":
                            verify(task.receive(first,outcome:.informationReady,now:2),"Current owned result accepted")
                            verify(task.completedSubtasks.isEmpty,"Information alone never completes physical action")
                            record("receive informationReady","Thanks, I heard the information.",2)
                            task.confirmSubtaskComplete()
                            record("explicit typed completion action (not generic speech parser)","Mark this named subtask finished.",3)
                            verify(task.completedSubtasks == [utterance],"Only explicit named subtask completion recorded")
                        case "pause_resume":
                            task.pause(); verify(!task.receive(first,outcome:.informationReady,now:2),"Paused old result rejected")
                            record("pause / reject old callback","Wait, I need to answer someone.",2)
                            task.resume(); let resumed=try ticket(&task,3)
                            verify(resumed.id != first.id,"Resume requires new adapter ticket")
                            task.receive(resumed,outcome:.informationReady,now:4)
                            record("resume / new owned result","Continue the same task.",4,["new_ticket_id":resumed.id.uuidString])
                            verify(task.goal == originalGoal,"Pause preserves original goal")
                        case "goal_replacement":
                            task.setGoal("Tell a bedtime story instead")
                            verify(!task.receive(first,outcome:.informationReady,now:2),"New goal rejects pending old result")
                            record("setGoal / reject previous callback","Forget that plan; tell a bedtime story instead.",2)
                            verify(task.goal != originalGoal,"Explicit new goal replaces old goal")
                        case "cancel":
                            task.cancelSubtask(); verify(!task.receive(first,outcome:.informationReady,now:2),"Cancelled result rejected")
                            record("cancelSubtask / reject callback","Stop just this task.",2)
                            verify(task.goal == originalGoal,"Subtask cancellation preserves parent goal")
                            task.cancelAll(); record("cancelAll","Cancel the whole plan.",3)
                            verify(task.goal == nil,"Whole-plan cancellation removes goal")
                        case "timeout":
                            verify(!task.receive(first,outcome:.informationReady,now:21),"Exact20-second deadline rejects result")
                            record("receive expired result","Why is it taking so long?",21,["ticket_age_seconds":20,"accepted":false])
                            let retry=try ticket(&task,21)
                            let final=task.next(available:all,now:41)
                            verify(final == .finished && task.lastFailure == .timedOut,"Second timeout ends bounded attempts")
                            record("retry / second timeout","Please try once more.",41,["retry_ticket":retry.id.uuidString,"actual_next":String(describing:final)])
                        case "uncertain_retry":
                            task.receive(first,outcome:.retryable(.uncertain),now:2); _=task.admitPrompt(for:.uncertain)
                            record("retryable uncertainty / prompt admission","It did not catch that. Try again.",2)
                            if capability != .savedMemory {
                                let retry=try ticket(&task,3); task.receive(retry,outcome:.retryable(.uncertain),now:4)
                            }
                            _=task.admitPrompt(for:.uncertain)
                            record("second uncertainty / deduplicated prompt","Still not clear?",4)
                            verify(task.state == .needsHelp && task.emittedPromptCount == 1,"Bounded retries and one uncertainty prompt")
                        case "duplicate_callback":
                            task.receive(first,outcome:.informationReady,now:2)
                            record("receive owned result","Okay.",2)
                            verify(!task.receive(first,outcome:.informationReady,now:3),"Duplicate result cannot advance again")
                            record("reject duplicate callback","Do not repeat that answer.",3)
                            verify(task.completedSubtasks.isEmpty,"Duplicate information is not physical completion")
                        case "repeat_goal":
                            verify(!task.setGoal(goal),"Repeated identical goal is idempotent")
                            record("repeat same goal",goal,2)
                            verify(task.receive(first,outcome:.informationReady,now:3),"Repeated goal preserves in-flight ticket")
                            record("receive still-owned result","Yes, that is still the plan.",3)
                            verify(task.goal == originalGoal,"Repeated goal retains exact ID")
                        case "clock_regression":
                            let final=task.next(available:all,now:0.5)
                            verify(final == .finished && task.lastFailure == .stale,"Regressed monotonic time fails boundedly")
                            verify(!task.receive(first,outcome:.informationReady,now:2),"Retired result cannot revive after time regression")
                            record("next with regressed clock / reject result","What happened to the task?",0.5,String(describing:final))
                        default: break
                        }
                    }
                } catch {failures.append(String(describing:error));XCTFail("\(id):\(error)")}
                episodes.append(["id":id,"goal":goal,"capability":capability.rawValue,"transition_mode":mode,"status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","executed_scope":"Actual domain adapter plus task coordinator; native acquisition/model/dialogue/audio not executed","blocked_dependencies":["native source acquisition","actual local model context/tool dispatch","real audio delivery"],"is_full_user_episode":false,"steps":steps,"failures":failures])
            }
        }
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("everyday-component-episodes.json"))
    }
}
