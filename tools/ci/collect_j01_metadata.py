"""Closed metadata only; observed response is not semantic/audio/journey success.
Call collect(response, scenario, source_commit, trusted_receipt_sha256) from the
reviewed same-job runner. Never print exception strings or raw input. No CLI
trust configuration. Input acquisition remains the runner's bounded job.
"""
import hashlib
import json
import math
import re

SUPPORTED = {'REQ-SC02-1': [{'event_id': 'REQ-SC02-1:0', 'offset_ms': 0, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Tell me a joke, then help me with my homework.'}, {'event_id': 'REQ-SC02-1:control', 'offset_ms': 500, 'kind': 'test_control', 'operation': 'continue', 'origin': 'test_harness_not_sensor', 'value': {}}, {'event_id': 'REQ-SC02-1:1', 'offset_ms': 1000, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Okay, what comes next?'}], 'REQ-SC02-3': [{'event_id': 'REQ-SC02-3:0', 'offset_ms': 0, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Tell me a joke, then help me with my homework.'}, {'event_id': 'REQ-SC02-3:control', 'offset_ms': 500, 'kind': 'test_control', 'operation': 'interrupt', 'origin': 'test_harness_not_sensor', 'value': {}}, {'event_id': 'REQ-SC02-3:1', 'offset_ms': 1000, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Wait. Now continue what we were doing.'}], 'REQ-SC02-4': [{'event_id': 'REQ-SC02-4:0', 'offset_ms': 0, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'Tell me a joke, then help me with my homework.'}, {'event_id': 'REQ-SC02-4:control', 'offset_ms': 500, 'kind': 'test_control', 'operation': 'replace_request', 'origin': 'test_harness_not_sensor', 'value': {'new_request_id': 'REQ-SC02-4:replacement'}}, {'event_id': 'REQ-SC02-4:1', 'offset_ms': 1000, 'kind': 'user_utterance', 'origin': 'authored_direct_user', 'text': 'No, I mean this other one, not the first one.'}]}
AVAILABILITY = frozenset(('available','deviceNotEligible','appleIntelligenceNotEnabled','modelNotReady','unknownUnavailable','unknownAvailability','apiUnavailable','frameworkUnavailable'))
FAILURES = frozenset(('none','generationFailed','modelUnavailable'))
class InvalidEvidence(ValueError): pass

def require(ok):
    if not ok: raise InvalidEvidence('invalid J01 evidence')
def boolean(value):
    require(type(value) is bool); return value
def count(value, limit=100000):
    require(type(value) is int and 0 <= value <= limit); return value
def finite(value):
    require(type(value) in (int,float) and math.isfinite(value) and 0 <= value <= 60000); return value
def ident(value):
    require(type(value) is str and 0 < len(value) <= 128); return value
def text(value):
    require(type(value) is str and len(value) <= 4096); return value

def collect(response, scenario, source_commit, trusted_receipt_sha256):
    require(scenario in SUPPORTED and re.fullmatch('[0-9a-f]{40}',source_commit or '') and re.fullmatch('[0-9a-f]{64}',trusted_receipt_sha256 or ''))
    require(type(response) is dict)
    require(len(json.dumps(response,allow_nan=False).encode()) <= 1048576)
    require(response.get('schema') == 'instrumented-app-jsonl-v1' and response.get('scenario_id') == scenario)
    require(response.get('source_commit') == source_commit == response.get('claimedSourceCommit'))
    for key in ('physical_actions_applied','fullJourneyComplete','actual_audio_delivery','model_drain_acknowledged'):
        require(response.get(key) is False)
    require(response.get('semantic_scoring') == 'not performed')
    proof=response.get('sourceAttestation',{})
    require(proof.get('verified') is True and proof.get('runtimeLoadedBinaryVerified') is False)
    require(proof.get('sourceCommit') == source_commit and proof.get('receiptSHA256') == trusted_receipt_sha256)
    require(proof.get('scope') == 'selected prebuilt artifact bytes match independently trusted build receipt; runtime load not attested')
    require(proof.get('trustBasis') == 'external reviewed CI receipt digest, not caller source echo')
    final=response['final_snapshot']; require(type(final) is dict)
    require(final.get('physical_authority') is False and final.get('audio_delivered') is False)
    timed=boolean(response['observation_timed_out']); require(boolean(final['busy']) == timed)
    returns=final['model_returns']; displays=final['accepted_displays']
    require(type(returns) is list and len(returns)<=8 and type(displays) is list and len(displays)<=64)
    capped=boolean(final['accepted_display_cap_reached']); require(capped == (len(displays)>=64))
    rows=response['events']; require(type(rows) is list and len(rows)==3)
    summaries=[]; request_ids=[]; last_ms=-1; failed=False
    for i,(row,expected) in enumerate(zip(rows,SUPPORTED[scenario])):
        require(type(row) is dict and json.dumps(row.get('actual_input'),sort_keys=True,allow_nan=False)==json.dumps(expected,sort_keys=True,allow_nan=False) and row.get('event_id')==expected['event_id'])
        status=row['status']; require(status in ('observed','unavailable'))
        ms=finite(row['elapsed_ms']); require(ms >= last_ms and ms >= expected['offset_ms']); last_ms=ms
        availability=row['model_identity']['provider_availability_before_dispatch']; require(availability in AVAILABILITY)
        receipts=row['delivery_receipts']; require(type(receipts) is list and len(receipts)==1 and receipts[0].get('kind')=='controller_snapshot' and receipts[0].get('audio_delivered') is False)
        snapshot=receipts[0]['snapshot']; rid=ident(snapshot['request_id']); request_ids.append(rid)
        returned=row.get('model_return'); actual=row.get('actual_reply'); require(actual is None or type(actual) is str)
        failure='not_returned'; cancelled=False; current=False; model_present=False; accepted=False
        if returned is not None:
            require(type(returned) is dict and returned in returns and returned.get('request_id')==rid)
            failure=returned['runtime_failure']; require(failure in FAILURES)
            cancelled=boolean(returned['cancelled']); current=boolean(returned['current_request'])
            model_present=boolean(returned['text_present']); boolean(returned['text_truncated']); text(returned['text'])
            require(status == ('observed' if failure=='none' else 'unavailable'))
            if failure!='none': failed=True
        if expected['kind']=='user_utterance':
            if returned is None: require(status=='unavailable')
            if actual is not None:
                text(actual); require(bool(actual.strip()))
                require(row.get('actual_reply_kind')=='accepted_settled_display_not_audio')
                cur=final.get('current_accepted_display'); require(type(cur) is dict)
                require(cur.get('request_id')==rid==final.get('request_id') and cur.get('session_generation')==final.get('session_generation'))
                count(cur['session_generation'],2**64-1); count(final['session_generation'],2**64-1); ident(cur['lease_id']); ident(cur['revision'])
                require(cur.get('text_truncated') is False and cur.get('text')==actual)
                matches=[d for d in displays if all(type(d.get(k)) is type(cur.get(k)) and d.get(k)==cur.get(k) for k in ('request_id','session_generation','lease_id','revision','text','text_truncated')) and d.get('settled') is True]
                require(matches and any(d in row.get('accepted_display_receipts',[]) for d in matches))
                require(returned is not None and failure=='none' and not cancelled and current)
                require(model_present and returned['text_truncated'] is False and bool(returned['text'].strip()))
                accepted=True
        else:
            require(returned is None and actual is None and status=='observed')
        if availability!='available': failed=True
        summaries.append({'event_id':expected['event_id'],'kind':expected['kind'],'status':status,'provider_availability':availability,'runtime_failure':failure,'model_return_present':returned is not None,'model_text_present':model_present,'accepted_reply_present':accepted,'cancelled_return':cancelled,'return_current_request':current})
    require(request_ids[0] != request_ids[2])
    finite(response['elapsed_ms']); require(response['elapsed_ms'] >= last_ms)
    complete_observation=not failed and not timed and not capped and summaries[-1]['accepted_reply_present'] and summaries[-1]['status']=='observed'
    # Earlier interrupted/replaced/retired reply may legitimately be absent.
    # The final request must still have its own accepted settled receipt.
    return {'schema':'j01-closed-metadata-v1','scenario_id':scenario,'source_commit':source_commit,'receipt_sha256':trusted_receipt_sha256,
      'status':'observed' if complete_observation else 'incomplete',
      'observation_status':'accepted_final_reply_observed' if complete_observation else 'incomplete',
      'lane_observation_ok':complete_observation,'events':summaries,'model_return_count':len(returns),'accepted_display_count':len(displays),
      'queued_count':count(final['queued_count']),'started_count':count(final['started_count']),'pending_count':count(final['pending_count']),
      'observation_timed_out':timed,'display_cap_reached':capped,'model_drain_acknowledged':False,'fullJourneyComplete':False,
      'semantic_quality_verified':False,'audio_delivery_verified':False,'runtimeLoadedBinaryVerified':False,'selected_artifact_bytes_verified':True}
