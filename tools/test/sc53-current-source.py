#!/usr/bin/env python3
"""Current-source contracts only: no Swift/native/model/audio execution."""
import argparse,hashlib,json,pathlib
SWITCH_SHA='025107b1aa7963b79f92de63a21ca079df34365fe1ac9421cd860d156a45fd9e'
EXPECTED_SCRIPTS={'REQ-SC02-1': [{'event_id': 'REQ-SC02-1:0', 'offset_ms': 0, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Tell me a joke, then help me with my homework.'}, {'event_id': 'REQ-SC02-1:control', 'offset_ms': 500, 'kind': 'test_control', 'operation': 'continue', 'origin': 'test_harness_not_sensor', 'value': {}}, {'event_id': 'REQ-SC02-1:1', 'offset_ms': 1000, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Okay, what comes next?'}], 'REQ-SC02-3': [{'event_id': 'REQ-SC02-3:0', 'offset_ms': 0, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Tell me a joke, then help me with my homework.'}, {'event_id': 'REQ-SC02-3:control', 'offset_ms': 500, 'kind': 'test_control', 'operation': 'interrupt', 'origin': 'test_harness_not_sensor', 'value': {}}, {'event_id': 'REQ-SC02-3:1', 'offset_ms': 1000, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Wait. Now continue what we were doing.'}], 'REQ-SC02-4': [{'event_id': 'REQ-SC02-4:0', 'offset_ms': 0, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Tell me a joke, then help me with my homework.'}, {'event_id': 'REQ-SC02-4:control', 'offset_ms': 500, 'kind': 'test_control', 'operation': 'replace_request', 'origin': 'test_harness_not_sensor', 'value': {'new_request_id': 'REQ-SC02-4:replacement'}}, {'event_id': 'REQ-SC02-4:1', 'offset_ms': 1000, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'No, I mean this other one, not the first one.'}], 'REQ-SC53-1': [{'event_id': 'REQ-SC53-1:0', 'offset_ms': 0, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Please stay quiet while I listen to the story.'}, {'event_id': 'REQ-SC53-1:control', 'offset_ms': 500, 'kind': 'test_control', 'operation': 'continue', 'origin': 'test_harness_not_sensor', 'value': {}}, {'event_id': 'REQ-SC53-1:1', 'offset_ms': 1000, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Okay, what comes next?'}], 'REQ-SC53-3': [{'event_id': 'REQ-SC53-3:0', 'offset_ms': 0, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Please stay quiet while I listen to the story.'}, {'event_id': 'REQ-SC53-3:control', 'offset_ms': 500, 'kind': 'test_control', 'operation': 'interrupt', 'origin': 'test_harness_not_sensor', 'value': {}}, {'event_id': 'REQ-SC53-3:1', 'offset_ms': 1000, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Wait. Now continue what we were doing.'}], 'REQ-SC53-4': [{'event_id': 'REQ-SC53-4:0', 'offset_ms': 0, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Please stay quiet while I listen to the story.'}, {'event_id': 'REQ-SC53-4:control', 'offset_ms': 500, 'kind': 'test_control', 'operation': 'replace_request', 'origin': 'test_harness_not_sensor', 'value': {'new_request_id': 'REQ-SC53-4:replacement'}}, {'event_id': 'REQ-SC53-4:1', 'offset_ms': 1000, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'No, I mean this other one, not the first one.'}]}
def check(root):
    checked=[]
    def require(ok,label):
        if not ok: raise ValueError(label)
        checked.append(label)
    def read(path):return (root/path).read_text()
    core=read('BlindCore/Sources/BlindCore/AssistantControl.swift')
    nav=read('ios/BlindAssist/NavigationModel.swift')
    test=read('ios/BlindAssistTests/HostedNonvisualJourneyTests.swift')
    # Locate the unchanged historical switch after the new polite switch.
    start=core.index('        switch value {\n        case "quiet",')
    end=core.index('    /// Context-dependent continuation',start)
    require(hashlib.sha256(core[start:end].encode()).hexdigest()==SWITCH_SHA,'original bilingual aliases byte exact')
    require('text.utf8.count <= 256' in core and 'guard isHeld' in core,'bounded contextual continuation')
    require('"please stay quiet while i listen to the story"' in core,'original SC53 opening supported')
    require('value == "wait. now continue what we were doing"' in core,'original SC53 continuation contextual')
    require('AssistantControl.resumesHeldNarration(text, isHeld: !ambientDescriptions)' in nav,'actual held-state consumer')
    require('func receiveUnverifiedConversation' in nav and 'No persistent narration/monitoring setting' in nav,'unverified microphone remains separate')
    require('guard debugHostedJourneyEnabled, debugHostedNarrationReceipts.count<16' in nav,'bounded opt-in real control receipts')
    for op in ['hold','resume']:
        require('debugRecordHostedNarration("'+op+'")' in nav,'actual '+op+' callback present')
    for key in ['narration_receipts','session_state','session_should_listen','private_audio_held','ordinary_audio_permitted']:
        require('"'+key+'"' in nav,'current snapshot '+key)
    require('"uptime":ProcessInfo.processInfo.systemUptime' in nav,'actual monotonic receipt time')
    actual=json.loads(read('research/j01-hosted-app-adapter-20261030/SUPPORTED.json'))
    require(actual==EXPECTED_SCRIPTS,'exact six original authored scripts, no substitution')
    embedded=test.split('private let supportedJSON = #"""\n',1)[1].split('\n"""#',1)[0]
    require(json.loads(embedded)==actual,'hosted embedded scripts agree')
    for marker in ['"fullJourneyComplete":false','"urgent_alert_delivery_verified":false','"model_drain_acknowledged":false','model.ambientDescriptions = previousNarration','model.ambientDescriptions=previous','accepted_narration_control_receipts','testActualNarrationHoldResumeKeepsMuteAndEndedAuthority']:
        require(marker in test,'hosted contract '+marker)
    for marker in ['model.muteConversation()','model.endConversation()','"session_generation"','"current_accepted_display"']:
        require(marker in test,'authored lifecycle control '+marker)
    feedback=read('ios/BlindAssist/Feedback.swift')
    start=feedback.index('    func interruptAmbient()');end=feedback.index('    @objc private func voiceOverChanged',start)
    require('active.priority != .mobility, active.priority != .danger' in feedback[start:end],'existing urgent/mobility exclusion retained')
    require('guard let active = delivery.active, case .narration = active.destination' in feedback[start:end],'ambient interruption scoped to narration')
    return {'sourceChecksPassed':len(checked),'checks':checked,'nativeExecuted':False,'audioDeliveryVerified':False,'urgentOutputRuntimeVerified':False,'fullJourneyComplete':False}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=pathlib.Path,required=True);a=p.parse_args()
    print(json.dumps(check(a.root),sort_keys=True))
