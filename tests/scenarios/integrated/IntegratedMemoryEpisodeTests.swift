import Foundation
import XCTest
@testable import BlindCore

final class IntegratedMemoryEpisodeTests:XCTestCase {
    let now=Date(timeIntervalSince1970:1_700_000_000)
    func json<T:Encodable>(_ value:T)throws->Any {try JSONSerialization.jsonObject(with:JSONEncoder().encode(value))}
    func testTwentyMemoryAndCompletionEpisodes()throws {
        let modes=["dated_correction","reordered_reports","restart","privacy_forget","unknown_object","unknown_age","future_record","pronoun_bound","pronoun_unbound","negated_report","cross_place","source_history","irrelevant_preferences","room_inventory","long_record","current_in_memory","generic_done","wrong_target_done","negated_done","named_completion"]
        var episodes:[[String:Any]]=[]
        for mode in modes {
            var steps:[[String:Any]]=[], failures:[String]=[]
            func check(_ value:Bool,_ expected:String) {if !value{failures.append(expected)};XCTAssertTrue(value,"\(mode):\(expected)")}
            func record(_ action:String,_ text:String,_ evidence:Any,_ result:Any,_ age:Any=NSNull()) {
                steps.append(["user_utterance":text,"actual_action":action,"evidence":evidence,"age_seconds":age,"actual_output":result,"image_ids":[],"map_id":NSNull(),"pose_id":NSNull(),"model_output":"NOT RUN"])
            }
            var book=CompanionFactBook()
            let old=try XCTUnwrap(book.record(object:"cup",place:"on the shelf",tense:.earlier,hedged:false,at:now.addingTimeInterval(-100)))
            record("record original user history","I left my cup on the shelf.",try json(old),old.acknowledgement(arabic:false),100)
            switch mode {
            case "dated_correction","reordered_reports","restart":
                let fresh=try XCTUnwrap(book.record(object:"cup",place:"on the desk",tense:.earlier,hedged:false,at:now.addingTimeInterval(-20)))
                record("record correction","No, I moved my cup to the desk.",try json(fresh),fresh.acknowledgement(arabic:false),20)
                check(book.record(object:"cup",place:"on the shelf",tense:.earlier,hedged:false,at:now.addingTimeInterval(-100)) == nil,"Old report cannot overwrite correction")
                if mode == "restart" {book=try JSONDecoder().decode(CompanionFactBook.self,from:JSONEncoder().encode(book))}
                if mode == "reordered_reports" {
                    let reports=[try XCTUnwrap(CompanionLocationReport(id:"new",object:"cup",originalReport:"I left my cup on the desk.",recordedAt:now.addingTimeInterval(-20))),try XCTUnwrap(CompanionLocationReport(id:"old",object:"cup",originalReport:"I left my cup on the shelf.",recordedAt:now.addingTimeInterval(-100)))]
                    let result=CompanionMemoryRetrieval.read(query:"cup",now:now,locationReports:reports)
                    check(result.evidence.first?.id == "new","Newest report wins despite arrival order")
                    record("retrieve reordered typed reports","Where was my cup last?",try json(reports),try json(result))
                }
                check(book.latest(for:"cup")?.place == "on the desk","Correction remains authoritative history")
                record("recall current history","Where did I leave it?",try json(book),book.latest(for:"cup")!.recall(now:now,arabic:false),20)
            case "privacy_forget":
                check(book.forget("cup"),"Forget removes stored cup report")
                check(book.latest(for:"cup") == nil,"Forgotten record cannot be recalled")
                record("forget / latest","Forget where I put my cup.",try json(book),CompanionFact.unknown(object:"cup",arabic:false))
            case "unknown_object":
                check(book.latest(for:"backpack") == nil,"Cup history does not answer backpack")
                record("query different item","Where is my backpack?",try json(book),CompanionFact.unknown(object:"backpack",arabic:false))
            case "unknown_age","future_record","negated_report","long_record","current_in_memory":
                let text=mode == "negated_report" ? "I did not leave my cup in the hall." : mode == "long_record" ? "cup "+String(repeating:"z",count:600)+" NOT HERE":"I left my cup on the desk."
                let report=CompanionEvidence(id:"report",kind:mode == "current_in_memory" ? .currentObservation:.userReport,text:text,source:"authored original user report",observedAt:mode == "unknown_age" ? nil:now.addingTimeInterval(mode == "future_record" ? 100:-20),expiresAt:mode == "current_in_memory" ? now.addingTimeInterval(5):nil)
                let result=CompanionMemoryRetrieval.read(query:"cup",now:now,reports:[report])
                let expectedPresent=mode == "unknown_age" || mode == "negated_report"
                check(!result.evidence.isEmpty == expectedPresent,"Only eligible bounded historical report enters memory retrieval")
                if mode == "unknown_age" {check(result.evidence.first?.observedAt == nil,"Missing age is not refreshed to now")}
                if mode == "negated_report" {check(result.evidence.first?.text == text,"Original negation remains intact")}
                record("read source-qualified report","What did I say about my cup?",try json(report),try json(result))
            case "pronoun_bound","pronoun_unbound":
                let raw=CompanionEvidence(id:"raw",kind:.userReport,text:"I left it on the desk.",source:"authored conversation",observedAt:now.addingTimeInterval(-20))
                let bound=try XCTUnwrap(CompanionLocationReport(id:"bound",object:"cup",originalReport:raw.text,recordedAt:raw.observedAt))
                let result=CompanionMemoryRetrieval.read(query:"cup",now:now,reports:mode == "pronoun_unbound" ? [raw]:[],locationReports:mode == "pronoun_bound" ? [bound]:[])
                check(result.evidence.isEmpty == (mode == "pronoun_unbound"),"Unbound pronoun is never guessed into current target")
                record("read typed or unbound pronoun","Where is my cup?",try json(raw),try json(result),20)
            case "cross_place","source_history":
                var observations=ObservedObjectMemory()
                observations.observe(category:"cup",source:.onDeviceDetector,frameID:"authored-frame-home",roomName:"kitchen",placeName:"home",at:now.addingTimeInterval(-20),now:now)
                if mode == "cross_place" {observations.observe(category:"cup",source:.onDeviceDetector,frameID:"authored-frame-school",roomName:"classroom",placeName:"school",at:now,now:now)}
                let result=CompanionMemoryRetrieval.read(query:"cup",now:now,observed:observations)
                check(result.evidence.allSatisfy{$0.kind == .historicalMemory},"Recorded detector sightings stay historical")
                if mode == "cross_place" {check(result.evidence.first?.text.contains("do not assume one item") == true,"Cross-place category matches never imply same object")}
                record("observe authored detections / retrieve","What do you remember seeing?","Authored detector category records, not real frames",try json(result))
                observations.clear();let cleared=CompanionMemoryRetrieval.read(query:"cup",now:now,observed:observations)
                check(cleared.evidence.isEmpty,"Clear deletes observation history")
                record("clear observations / retrieve","Forget those sightings.","Cleared in-memory observation store",try json(cleared))
            case "irrelevant_preferences":
                let preferences=(0..<12).map{CompanionMemoryNote(id:"p\($0)",subject:"food",text:"I like apples",source:"authored preference")}
                let result=CompanionMemoryRetrieval.read(query:"backpack",now:now,savedItems:[.init(name:"backpack",roomName:"bedroom",savedAt:now)],preferences:preferences)
                check(result.evidence.count == 1 && result.evidence[0].text.contains("backpack"),"Irrelevant preferences do not crowd out target")
                record("memory relevance selection","Help me find my backpack, not my snack preferences.","12 authored apple preferences and one backpack item",try json(result))
            case "room_inventory":
                let place=CompanionPlaceMemory(id:"home",name:"Home",roomNames:["Bedroom","Kitchen"],recordedAt:now.addingTimeInterval(-100))
                let result=CompanionMemoryRetrieval.read(query:"What do you remember about my room?",now:now,places:[place])
                check(result.evidence.first?.text.contains("does not establish current room") == true,"Inventory never becomes live room identity")
                record("read saved place inventory","Which rooms do you remember?","Authored Home rooms Bedroom/Kitchen recorded100seconds earlier",try json(result),100)
            default:
                let request=try XCTUnwrap(EverydayTaskRequest(capability:.findItem,query:"cup"))
                var task=EverydayTaskCoordinator();task.setGoal("Prepare breakfast");task.begin(request)
                let report=mode == "generic_done" ? "I'm done":mode == "wrong_target_done" ? "I found my keys":mode == "negated_done" ? "I have not found my cup":"I found my cup"
                let matched=CompanionTaskCompletion.matches(report,request:request)
                check(matched == (mode == "named_completion"),"Only positive exact-target report authorizes completion")
                if matched {task.confirmSubtaskComplete()}
                check(task.completedSubtasks.isEmpty == !matched,"Completion state follows target-bound parser")
                record("parse completion / conditional coordinator completion",report,["target":"cup","goal":"Prepare breakfast"],["matched":matched,"completed":task.completedSubtasks])
            }
            episodes.append(["id":"MEMORY-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","executed_scope":"Actual source-qualified memory, temporal ordering, deletion, retrieval and completion code","blocked_dependencies":["native persistence for this replay","real model/context roundtrip","real perception","audio"],"is_full_user_episode":false,"steps":steps,"failures":failures])
        }
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        try JSONSerialization.data(withJSONObject:episodes,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output).appendingPathComponent("memory-component-episodes.json"))
    }
}
