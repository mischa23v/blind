import Foundation
import BlindCore

func encoded<T:Encodable>(_ x:T)throws->Any { try JSONSerialization.jsonObject(with:JSONEncoder().encode(x)) }
let casesURL=URL(fileURLWithPath:CommandLine.arguments[1])
let cases=try JSONSerialization.jsonObject(with:Data(contentsOf:casesURL)) as! [String:[[String:Any]]]
var book=CompanionFactBook(), task=EverydayTaskCoordinator()
var episode="",turn = -1, utterance="", origin="", now=Date(timeIntervalSince1970:1_700_000_000)
var emissions:[String:String]=[:], delivery:[String:Any]=[:]
var clockLease:CompanionClockReplyLease?=nil
var clockBinding:CompanionClockReplyLease.Binding?=nil
func state()throws->[String:Any] { ["episode":episode,"turn":turn,"utterance":utterance,"origin":origin,"wall_time":now.timeIntervalSince1970,"facts":try encoded(book),"goal":task.goal?.description as Any? ?? NSNull(),"task_state":task.state.rawValue,"request":task.request?.query as Any? ?? NSNull(),"completed":task.completedSubtasks,"pose_id":NSNull(),"image_ids":[],"sensor_evidence":"NONE"] }
func owned(_ text:String)->[String:Any] {let id=UUID().uuidString;emissions[id]=text;return ["code_output_id":id,"text":text,"source":"actual BlindCore code, not model output","valid_for_turn":turn]}
func run(_ a:[String:Any])throws->Any {
 let op=a["op"] as? String ?? ""
 let value=a["value"] as? String ?? ""
 switch op {
 case "start":
  guard cases[value] != nil else {return ["error":"unknown episode"]}
  episode=value;turn = -1;book=CompanionFactBook();task=EverydayTaskCoordinator();emissions=[:];clockLease=nil;delivery=[:];return try state()
 case "next_user":
  guard let turns=cases[episode],turn+1<turns.count else{return ["done":true]}
  turn += 1;let t=turns[turn];utterance=t["text"] as! String;origin=t["origin"] as? String ?? "direct_user";now=Date(timeIntervalSince1970:t["wall_time"] as! Double);emissions=[:];delivery=[:];return try state()
 case "context":return try state()
 case "record_report":
  guard origin == "direct_user",case .report(let object?,let place,let tense,let hedged)=CompanionUtterance.parse(utterance),let fact=book.record(object:object,place:place,tense:tense,hedged:hedged,at:now,sourceID:"\(episode)-turn-\(turn)") else{return ["rejected":"No explicit named direct-user location report"]}
  return owned(fact.acknowledgement(arabic:false))
 case "memory_lookup":
  if let fact=book.latest(for:value) {var result=owned(fact.recall(now:now,arabic:false));result["evidence"]=try encoded(fact);result["age_seconds"]=now.timeIntervalSince(fact.at);return result}
  return owned(CompanionFact.unknown(object:value,arabic:false))
 case "forget":
  guard origin == "direct_user",utterance.lowercased().contains("forget"),utterance.lowercased().contains(value.lowercased()),!value.isEmpty else{return ["rejected":"No matching direct privacy instruction"]}
  emissions=[:];return ["removed":book.forget(value)]
 case "set_goal":
  guard origin == "direct_user",value == utterance else{return ["rejected":"Use exact current direct-user goal"]}
  return ["changed":task.setGoal(value)]
 case "begin_task":
  guard origin == "direct_user",let request=EverydayTaskRequest.route(utterance) else{return ["rejected":"Actual task parser did not route current direct utterance"]}
  return ["began":task.begin(request),"capability":request.capability.rawValue,"query":request.query]
 case "task_next":
  let result=task.next(available:[.savedMemory,.deviceClock],now:now.timeIntervalSince1970)
  if case .run(let ticket)=result {
   if ticket.request.capability == .savedMemory {
    let found=book.latest(for:ticket.request.query) != nil
    _=task.receive(ticket,outcome:found ? .historicalClue:.unavailable,now:now.timeIntervalSince1970)
    return ["selected_tool":"savedMemory","ticket":ticket.id.uuidString,"historical_clue":found,"state":task.state.rawValue,"note":"Call memory_lookup for source-owned historical text; no current perception available"]
   }
   _=task.receive(ticket,outcome:.unavailable,now:now.timeIntervalSince1970)
  }
  return ["actual_selection":String(describing:result),"state":task.state.rawValue]
 case "confirm_complete":
  let matched=origin == "direct_user" && task.request.map{CompanionTaskCompletion.matches(utterance,request:$0)} == true
  return ["matched":matched,"completed":matched ? task.confirmSubtaskComplete():false]
 case "pause","resume","cancel":
  guard origin == "direct_user" else{return ["rejected":"Background content has no command authority"]}
  if op == "pause" {task.pause()} else if op == "resume" {task.resume()} else {task.cancelAll()};return try state()
 case "clock_read":
  let binding=CompanionClockReplyLease.Binding(requestID:UUID(),generation:UInt64(max(0,turn)),replyID:UUID());clockBinding=binding
  clockLease=CompanionClockReplyLease.read(binding:binding,now:now,monotonicNow:now.timeIntervalSince1970,timeZone:TimeZone(secondsFromGMT:0)!,arabic:false)
  return clockLease.map{owned($0.reply)} ?? ["unavailable":true]
 case "map_read":
  let path=ProcessInfo.processInfo.environment["BLIND_DATASET_ROOT"]!+"/oas-e54861c/oas-apartment.blindplace.json"
  let p=try PlacePackage.decode(Data(contentsOf:URL(fileURLWithPath:path)))
  return ["package_id":p.id,"revision":p.revision,"provenance":p.provenance,"localization":p.localization,"rooms":p.rooms.map{["id":$0.id,"name":$0.name]},"connections":p.connections.map{["id":$0.id,"from":$0.fromRoomID,"to":$0.toRoomID]},"route_map_present":p.routeMap != nil,"pose":NSNull(),"image_ids":[],"source":"External authored Autodesk OAS plan; not measured home; no ARKitScenes pairing; source age unknown"]
 case "deliver_code":
  guard let text=emissions[value] else{return ["delivered":false,"reason":"Unknown or retired code output"]}
  if text == clockLease?.reply,let binding=clockBinding {
   guard clockLease!.validates(reply:text,binding:binding,now:now,monotonicNow:now.timeIntervalSince1970,timeZone:TimeZone(secondsFromGMT:0)!) else{return ["delivered":false,"reason":"Clock lease rejected"]}
  }
  delivery=["delivered":true,"text":text,"owner":"code","medium":"text harness; NOT native audio"]
  return delivery
 case "deliver_candidate":
  let allowed=CompanionEvidenceGuard.allows(value,reports:[],evidence:[],now:now)
  delivery=["candidate":value,"allowed_by_actual_guard":allowed,"delivered":allowed,"text":allowed ? value:"","owner":"frontier evaluation agent","medium":"text harness; NOT native audio"]
  return delivery
 default:return ["error":"unknown operation"]
 }
}
while let line=readLine() {
 do {let a=try JSONSerialization.jsonObject(with:Data(line.utf8)) as! [String:Any];let result=try run(a);let response:[String:Any]=["result":result,"state":try state()];print(String(data:try JSONSerialization.data(withJSONObject:response,options:[.sortedKeys]),encoding:.utf8)!)}catch {print("{\"error\":\"\(String(describing:error).replacingOccurrences(of:"\"",with:"'"))\"}")}
 fflush(stdout)
}
