import Foundation
import XCTest
@testable import BlindCore

final class IntegratedSourcedMapEpisodeTests:XCTestCase {
    func testSourcedOASPreviewCannotBecomeRegisteredGuidance()throws {
        let output=try XCTUnwrap(ProcessInfo.processInfo.environment["BLIND_EPISODE_OUTPUT"])
        let url=URL(fileURLWithPath:output).appendingPathComponent("sourced-map-component-episode.json")
        guard let root=ProcessInfo.processInfo.environment["BLIND_DATASET_ROOT"] else {
            let value:[String:Any]=["id":"SOURCE-OAS-preview","status":"BLOCKED_NOT_RUN","reason":"BLIND_DATASET_ROOT missing; external source data not silently replaced with synthetic map","is_full_user_episode":false]
            try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:url);return
        }
        let bytes=try Data(contentsOf:URL(fileURLWithPath:root).appendingPathComponent("oas-e54861c/oas-apartment.blindplace.json"))
        let sha=try SpatialIntegrationFixture.sha256(bytes),package=try PlacePackage.decode(bytes)
        var steps:[[String:Any]]=[]
        steps.append(["user_utterance":"What can you tell me from this downloaded floor plan?","actual_action":"PlacePackage.decode source bytes","input_sha256":sha,"actual_package_id":package.id,"revision":package.revision,"provenance":package.provenance,"localization":package.localization,"room_ids":package.rooms.map(\.id),"coverage_gaps":package.coverageGaps])
        let noInventedDoor = !package.connections.contains{Set([$0.fromRoomID,$0.toRoomID]) == Set(["bedroom","bathroom"])}
        XCTAssertTrue(noInventedDoor)
        steps.append(["user_utterance":"Can I go directly from the bedroom to the bathroom?","actual_action":"inspect exact source-authored connectivity","direct_connection_present":!noInventedDoor,"expected_direct_connection":false,"connection_ids":package.connections.map(\.id)])
        XCTAssertNil(package.routeMap);XCTAssertEqual(package.localization,"preview-only")
        steps.append(["user_utterance":"Guide me along it now.","actual_action":"inspect routing/localization eligibility","actual_route_map":"nil","actual_localization":package.localization,"expected":"Withhold registered guidance: no route/collision/pose evidence","pose_id":NSNull(),"image_ids":[],"lidar_ids":[]])
        var privateEnvelope=try XCTUnwrap(JSONSerialization.jsonObject(with:bytes) as? [String:Any]);privateEnvelope["people"]=[["name":"AUTHORED PRIVATE TEST LABEL"]]
        var rejected=false,errorText=""
        do{_ = try PlacePackage.decode(JSONSerialization.data(withJSONObject:privateEnvelope))}catch{rejected=true;errorText=String(describing:error)}
        XCTAssertTrue(rejected)
        steps.append(["user_utterance":"Keep private family labels out of the community map.","actual_action":"decode authored private-field mutation","rejected":rejected,"actual_error":errorText,"expected":"Reject private memory envelope"])
        let result:[String:Any]=["id":"SOURCE-OAS-preview","status":noInventedDoor && package.routeMap == nil && package.localization == "preview-only" && rejected ? "PARTIAL_CODE_PASS":"PARTIAL_CODE_FAIL","is_full_user_episode":false,"source":"Autodesk authored OAS e54861c example; NOT measured home","input_sha256":sha,"raw_data_copied_to_repo":false,"arkitscenes_pairing":"NONE; unrelated scene must never be attached","model_output":"NOT RUN","blocked_dependencies":["registered route/collision surface","calibrated native pose/body/floor support","real output delivery"],"steps":steps]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:url)
    }
}
