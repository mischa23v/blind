import Foundation
import XCTest
@testable import BlindCore

final class IntegratedShoppingSessionEpisodeTests:XCTestCase {
    func testTenShoppingSourceEpisodes()throws {
        let modes=["normal","arabic","duplicate","observation","quoted_command","mismatched_quote","unknown_barcode","private_label_delete","restore","forged_restore"]
        var episodes:[[String:Any]]=[]
        for mode in modes {
            var list=EverydayShoppingList(),products=ProductMemory(),steps:[[String:Any]]=[],failures:[String]=[]
            let arabic=mode == "arabic",item=mode == "arabic" ? "الحليب":"milk"
            let quote=arabic ? "أضف الحليب إلى قائمة التسوق":"add milk to my shopping list"
            func check(_ condition:Bool,_ expected:String){if !condition{failures.append(expected)};XCTAssertTrue(condition,"\(mode):\(expected)")}
            func record(_ utterance:String,_ action:String,_ output:Any,_ time:Double)throws {steps.append(["user_utterance":utterance,"actual_action":action,"time":time,"actual_output":output,"list":try JSONSerialization.jsonObject(with:JSONEncoder().encode(list)),"product_labels":products.names,"image_ids":[],"pose_id":NSNull(),"map_id":NSNull(),"model_output":"NOT RUN"])}
            let parsed=try XCTUnwrap(EverydayShoppingCommand.parse(quote));check(list.apply(parsed,userQuote:quote,now:10),"Explicit source-matched list addition succeeds")
            try record(quote,"parse / apply",String(describing:parsed),10)
            switch mode {
            case "duplicate":
                check(!list.apply(.add(item),userQuote:quote,now:11),"Duplicate add does not create second entry")
                check(list.entries.first?.recordedAt == 10,"Duplicate does not refresh original source age")
                try record(quote,"duplicate source command",false,11)
            case "observation","quoted_command":
                let falseCommand=mode == "observation" ? "I see eggs":"The label says add eggs to my shopping list"
                check(EverydayShoppingCommand.parse(falseCommand) == nil,"Observation or quote cannot mutate list")
                check(!list.apply(.add("eggs"),userQuote:falseCommand,now:11),"Direct forged apply also rejects")
                try record(falseCommand,"parse / reject forged apply",false,11)
            case "mismatched_quote":
                check(!list.apply(.add("eggs"),userQuote:"add bread to my shopping list",now:11),"Action target must match source quote")
                try record("add bread to my shopping list","reject action eggs with quote bread",false,11)
            case "forged_restore":
                let bytes=Data("{\"entries\":[{\"item\":\"eggs\",\"sourceQuote\":\"I see eggs\",\"recordedAt\":11}]}".utf8)
                do{_ = try JSONDecoder().decode(EverydayShoppingList.self,from:bytes);check(false,"Forged restored attribution must reject")}
                catch{try record("What was on the old saved list?","reject forged restoration",String(describing:error),11)}
            default:
                if mode == "restore" {list=try JSONDecoder().decode(EverydayShoppingList.self,from:JSONEncoder().encode(list));check(list.entries.first?.sourceQuote == quote,"Restoration preserves exact original quote");try record("Read my saved list.","serialize / restore",true,11)}
                if mode != "unknown_barcode" {check(products.save(item,for:"AUTHORED-PRODUCT-42"),"Explicit authored label saved")}
                let result=CodeReading.speech(payload:"AUTHORED-PRODUCT-42",isQR:false,savedName:products.name(for:"AUTHORED-PRODUCT-42"),arabic:arabic)
                check(mode == "unknown_barcode" ? result.contains("don't know"):result.contains(item),"Actual barcode code uses only saved label or explicit unknown")
                try record("What is this product code?","CodeReading.speech; barcode acquisition NOT RUN",result,12)
                check(list.entries.count == 1,"Recognizing a product never means it was purchased")
                if mode == "private_label_delete" {products.forget("AUTHORED-PRODUCT-42");check(products.name(for:"AUTHORED-PRODUCT-42") == nil,"Private product label deleted");try record("Forget that product label.","ProductMemory.forget",true,13)}
            }
            let remove=arabic ? "احذف الحليب من قائمة التسوق":"remove milk from my shopping list"
            check(list.apply(.remove(item),userQuote:remove,now:14),"Explicit matching removal succeeds")
            check(list.entries.isEmpty,"Final list is empty, not silently purchased")
            try record(remove,"apply explicit remove",true,14)
            episodes.append(["id":"SHOPPING-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual shopping parser/source ledger, private product naming and barcode speech renderer","blocked_dependencies":["real camera barcode input","live shopping scene","model context","speech"],"steps":steps,"failures":failures])
        }
        try write(episodes,"shopping-component-episodes.json")
    }
    func testTenSessionLifecycleEpisodes()throws {
        let modes=["end_foreground","mute_foreground","background_default","background_opt_in","withdraw_opt_in","mute_background","ended_unmute","repeat_start","explicit_invalidate","idle_permissions"]
        var episodes:[[String:Any]]=[]
        for mode in modes {
            var session=AssistantSession(),steps:[[String:Any]]=[],failures:[String]=[]
            func check(_ c:Bool,_ e:String){if !c{failures.append(e)};XCTAssertTrue(c,"\(mode):\(e)")}
            func record(_ utterance:String,_ action:String){steps.append(["user_utterance":utterance,"actual_action":action,"state":String(describing:session.state),"generation":session.generation,"listen":session.shouldListen,"respond":session.mayRespond,"camera":session.shouldRunCamera,"background_allowed":session.backgroundAllowed])}
            if mode != "idle_permissions" {session.start()};let original=session.generation;record("Start helping me.","explicit start (except idle negative)")
            switch mode {
            case "end_foreground":session.end();record("End the session.","end");session.enterBackground();session.enterForeground();check(!session.shouldListen && !session.shouldRunCamera && !session.mayRespond,"Foreground must not revive ended session")
            case "mute_foreground":session.mute();record("Mute the microphone.","mute");session.enterBackground();session.enterForeground();check(!session.shouldListen && session.mayRespond && session.shouldRunCamera,"Mute survives foreground; typed response remains")
            case "background_default":session.enterBackground();check(!session.shouldListen && !session.mayRespond && !session.shouldRunCamera,"Default background stops camera/listening/responses")
            case "background_opt_in":session.setBackgroundAllowed(true);session.enterBackground();check(session.shouldListen && session.mayRespond && !session.shouldRunCamera,"Explicit background conversation never authorizes background camera")
            case "withdraw_opt_in":session.setBackgroundAllowed(true);session.enterBackground();let previous=session.generation;record("Allow background conversation.","opt in / background");session.setBackgroundAllowed(false);check(!session.shouldListen && !session.accepts(generation:previous),"Withdrawing permission retires background work")
            case "mute_background":session.setBackgroundAllowed(true);session.enterBackground();session.mute();check(!session.shouldListen,"Background opt-in never overrides mute")
            case "ended_unmute":session.end();session.unmute();check(session.state == .ended && !session.shouldListen,"Unmute cannot reopen an ended session")
            case "repeat_start":session.start();session.unmute();session.enterForeground();check(session.generation == original,"No-op transitions do not retire current work")
            case "explicit_invalidate":session.invalidate();check(session.generation != original && !session.accepts(generation:original),"Explicit invalidation fences old callbacks")
            case "idle_permissions":session.setBackgroundAllowed(true);session.enterBackground();session.unmute();check(session.state == .idle && !session.shouldListen && !session.accepts(generation:session.generation),"Permission/settings do not start idle session")
            default:break
            }
            record("What is active now?","inspect state after \(mode)")
            if mode != "repeat_start" && mode != "idle_permissions" {check(!session.accepts(generation:original),"Effective lifecycle transition rejects original generation")}
            episodes.append(["id":"SESSION-\(mode)","status":failures.isEmpty ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"executed_scope":"Actual lifecycle/generation policy","blocked_dependencies":["microphone capture","camera lifecycle","Apple background state","audio/device interruption"],"model_output":"NOT RUN","image_ids":[],"map_id":NSNull(),"pose_id":NSNull(),"steps":steps,"failures":failures])
        }
        try write(episodes,"session-component-episodes.json")
    }
    func write(_ object:Any,_ name:String)throws {let out=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"]);try JSONSerialization.data(withJSONObject:object,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:out).appendingPathComponent(name))}
}
