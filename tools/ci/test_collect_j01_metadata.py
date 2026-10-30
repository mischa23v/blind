import copy
import json
import unittest
import collect_j01_metadata as m

S='a'*40; H='b'*64

def fixture(scenario='REQ-SC02-3'):
    current={'request_id':'final-private-id','session_generation':1,'lease_id':'private-lease','revision':'private-revision','text':'PRIVATE REPLY','text_truncated':False}
    display={**current,'settled':True}
    returned={'request_id':current['request_id'],'text':'PRIVATE REPLY','text_present':True,'text_truncated':False,'runtime_failure':'none','cancelled':False,'current_request':True}
    final={'request_id':current['request_id'],'session_generation':1,'current_accepted_display':current,'accepted_displays':[display],'model_returns':[returned],'physical_authority':False,'audio_delivered':False,'busy':False,'accepted_display_cap_reached':False,'queued_count':1,'started_count':0,'pending_count':0}
    rows=[]
    for i,event in enumerate(m.SUPPORTED[scenario]):
        row={'event_id':event['event_id'],'actual_input':copy.deepcopy(event),'status':'observed' if i else 'unavailable','model_identity':{'provider_availability_before_dispatch':'available'},'elapsed_ms':event['offset_ms']+1,'delivery_receipts':[{'kind':'controller_snapshot','audio_delivered':False,'snapshot':{'request_id':'old-private-id' if i<2 else current['request_id']}}],'actual_reply':None}
        if i==2: row.update(model_return=returned,actual_reply='PRIVATE REPLY',actual_reply_kind='accepted_settled_display_not_audio',accepted_display_receipts=[display])
        rows.append(row)
    return {'schema':'instrumented-app-jsonl-v1','scenario_id':scenario,'source_commit':S,'claimedSourceCommit':S,'physical_actions_applied':False,'fullJourneyComplete':False,'actual_audio_delivery':False,'model_drain_acknowledged':False,'semantic_scoring':'not performed','observation_timed_out':False,'elapsed_ms':1100,'sourceAttestation':{'verified':True,'runtimeLoadedBinaryVerified':False,'sourceCommit':S,'receiptSHA256':H,'scope':'selected prebuilt artifact bytes match independently trusted build receipt; runtime load not attested','trustBasis':'external reviewed CI receipt digest, not caller source echo'},'events':rows,'final_snapshot':final}

def run(x): return m.collect(x,x['scenario_id'],S,H)

class Tests(unittest.TestCase):
    def test_three_scripts_final_receipt(self):
        for key in m.SUPPORTED:
            result=run(fixture(key)); self.assertTrue(result['lane_observation_ok']); self.assertFalse(result['fullJourneyComplete'])
    def test_no_private_content(self):
        x=fixture();x['unknown']='SECRET EXTRA'; encoded=json.dumps(run(x))
        for private in ('PRIVATE','private-','SECRET','Tell me','homework','Wait.'):
            self.assertNotIn(private,encoded)
    def test_retired_first_reply_absence_permitted(self): self.assertTrue(run(fixture())['lane_observation_ok'])
    def test_timeout_incomplete(self):
        x=fixture();x['observation_timed_out']=True;x['final_snapshot']['busy']=True
        self.assertFalse(run(x)['lane_observation_ok'])
    def test_missing_final_receipt_incomplete(self):
        x=fixture();x['events'][2]['actual_reply']=None
        self.assertFalse(run(x)['lane_observation_ok'])
    def test_generation_failure_not_success(self):
        x=fixture();x['events'][2]['model_return']['runtime_failure']='generationFailed';x['events'][2]['status']='unavailable';x['events'][2]['actual_reply']=None
        self.assertFalse(run(x)['lane_observation_ok'])
    def test_provider_unavailable_not_success(self):
        x=fixture();x['events'][2]['model_identity']['provider_availability_before_dispatch']='modelNotReady'
        self.assertFalse(run(x)['lane_observation_ok'])
    def test_no_final_return_not_success(self):
        x=fixture();x['events'][2].pop('model_return');x['events'][2]['status']='unavailable';x['events'][2]['actual_reply']=None
        self.assertFalse(run(x)['lane_observation_ok'])
    def test_mutation_refusals(self):
        edits=[
         lambda x:x.update(source_commit='c'*40),lambda x:x.update(claimedSourceCommit='c'*40),
         lambda x:x.update(fullJourneyComplete=True),lambda x:x.update(actual_audio_delivery=True),
         lambda x:x.update(model_drain_acknowledged=True),lambda x:x.update(physical_actions_applied=True),
         lambda x:x['sourceAttestation'].update(verified=False),lambda x:x['sourceAttestation'].update(runtimeLoadedBinaryVerified=True),
         lambda x:x['sourceAttestation'].update(receiptSHA256='c'*64),lambda x:x['sourceAttestation'].update(scope='trusted'),
         lambda x:x['events'].pop(),lambda x:x['events'].reverse(),
         lambda x:x['events'][0]['actual_input'].update(text='changed'),lambda x:x['events'][0].update(event_id='other'),
         lambda x:x['events'][2]['model_identity'].update(provider_availability_before_dispatch='PRIVATE'),
         lambda x:x['events'][2]['model_return'].update(runtime_failure='PRIVATE'),
         lambda x:x['events'][2]['model_return'].update(cancelled=True),lambda x:x['events'][2]['model_return'].update(current_request=False),
         lambda x:x['final_snapshot']['current_accepted_display'].update(revision='wrong'),
         lambda x:x['final_snapshot'].update(session_generation=2),
         lambda x:x['final_snapshot'].update(session_generation=True),
         lambda x:x['final_snapshot']['accepted_displays'][0].update(settled=False),
         lambda x:x['final_snapshot']['current_accepted_display'].update(text_truncated=True),
         lambda x:x['events'][2].update(actual_reply='unbound'),lambda x:x['events'][2].update(accepted_display_receipts=[]),
         lambda x:x['final_snapshot'].update(queued_count=True),lambda x:x.update(elapsed_ms=float('nan')),
         lambda x:x['events'][2].update(elapsed_ms=-1),lambda x:x.update(extra='x'*1048576),
         lambda x:x['final_snapshot'].update(busy=True),lambda x:x['events'][1].update(actual_reply='invented'),
         lambda x:x['events'][2]['delivery_receipts'][0].update(audio_delivered=True),
         lambda x:x['events'][2]['model_return'].update(request_id='wrong'),
         lambda x:x['events'][2]['model_return'].update(text_present=False),
         lambda x:x['events'][2]['model_return'].update(text_truncated=True),
         lambda x:x['events'][2]['model_return'].update(text='   '),
        ]
        for mutate in edits:
            with self.subTest(mutation=edits.index(mutate)):
                x=fixture();mutate(x)
                with self.assertRaises((ValueError,KeyError,TypeError)):run(x)
    def test_bool_generation_refused(self):
        x=fixture();x['final_snapshot']['session_generation']=True;x['final_snapshot']['current_accepted_display']['session_generation']=True
        with self.assertRaises(m.InvalidEvidence):run(x)

if __name__=='__main__': unittest.main()
