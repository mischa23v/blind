import unittest,json,copy,plistlib,importlib.util,pathlib
P=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('adapter',P/'app_adapter.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Tests(unittest.TestCase):
 def setUp(self):
  self.config={'source_commit':'a'*40,'simulator_udid':'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE','ephemeral_simulator_no_accounts':True}
  self.request={'schema':'instrumented-app-jsonl-v1','source_commit':'a'*40,'scenario_id':'REQ-SC02-1','events':json.loads((P/'SUPPORTED.json').read_text())['REQ-SC02-1'],'constraints':dict(physical_actions=False,network=False,paid_services=False)}
 def test_exact_three(self):
  for id,events in json.loads((P/'SUPPORTED.json').read_text()).items():
   self.request.update(scenario_id=id,events=events);m.validate(self.request,self.config)
 def test_mutations(self):
  for key,value in [('schema','other'),('source_commit','b'*40),('scenario_id','REQ-SC45-1'),('events',[]),('constraints',{'network':True})]:
   with self.subTest(key=key),self.assertRaises(ValueError):m.validate(dict(self.request,**{key:value}),self.config)
 def test_authority_and_commit(self):
  for key,value in [('ephemeral_simulator_no_accounts',False),('ephemeral_simulator_no_accounts',1),('source_commit','x'),('simulator_udid','real-phone')]:
   with self.subTest(key=key),self.assertRaises(ValueError):m.validate(self.request,dict(self.config,**{key:value}))
 def test_future_text_not_substituted(self):
  self.request['events'][0]['text']='New invented request'
  with self.assertRaises(ValueError):m.validate(self.request,self.config)
 def test_bool_not_number(self):
  self.request['events'][0]['offset_ms']=False
  with self.assertRaises(ValueError):m.validate(self.request,self.config)
 def test_v2_target_bound(self):
  doc={'TestConfigurations':[{'Name':'Test','TestTargets':[{'BlueprintName':'BlindAssistTests','TestHostPath':'__TESTROOT__/App.app','EnvironmentVariables':{}},{'BlueprintName':'Other'}]}]}
  result=plistlib.loads(m.prepare_xctestrun(plistlib.dumps(doc),'/build','/request','/response','a'*40))
  target=result['TestConfigurations'][0]['TestTargets'];self.assertEqual(len(target),1)
  self.assertEqual(target[0]['OnlyTestIdentifiers'],['HostedNonvisualJourneyTests/testExplicitHostedJSONLJourney'])
  self.assertEqual(target[0]['TestHostPath'],'/build/App.app');self.assertEqual(target[0]['EnvironmentVariables']['BLIND_J01_HOSTED'],'1')
 def test_wrong_or_duplicate_target_rejected(self):
  for targets in [[],[{'BlueprintName':'Other'}],[{'BlueprintName':'BlindAssistTests'}]*2]:
   with self.assertRaises(ValueError):m.prepare_xctestrun(plistlib.dumps({'TestConfigurations':[{'TestTargets':targets}]}),'/b','/i','/o','a'*40)
 def test_no_fake_model_answer(self):
  # Source contract only: does not substitute for compiling/running the test.
  s=(P.parents[1]/'ios/BlindAssistTests/HostedNonvisualJourneyTests.swift').read_text()
  self.assertIn('model.receiveCompanionUtterance',s);self.assertNotIn('debugInjectModelResponse',s)
  self.assertIn('"model_drain_acknowledged":false',s);self.assertIn('"fullJourneyComplete":false',s)
  self.assertIn('provider_availability_before_dispatch',s)
 def test_raw_cancelled_or_current_return_never_becomes_accepted_reply(self):
  s=(P.parents[1]/'ios/BlindAssistTests/HostedNonvisualJourneyTests.swift').read_text()
  self.assertIn('"actual_reply":NSNull()',s)
  self.assertNotIn('rows[index]["actual_reply"]=returned',s)
  self.assertIn('if let text=acceptedDisplayReply(requestID:requestID,final:final)',s)
  self.assertIn('rows[index]["actual_reply"]=text',s)
  self.assertIn('rows[index]["model_return"]=returned',s)
  self.assertIn('missing_accepted_reply_receipt',s)
 def test_source_claim_not_attestation(self):
  s=(P.parents[1]/'ios/BlindAssistTests/HostedNonvisualJourneyTests.swift').read_text()
  self.assertIn('"claimedSourceCommit":commit',s)
  self.assertIn('"sourceAttestation":["verified":false',s)
  self.assertIn("get('sourceAttestation',{}).get('verified') is False",(P/'app_adapter.py').read_text())
 def test_actual_display_boundary_and_current_lease_checked(self):
  app=(P.parents[1]/'ios/BlindAssist/NavigationModel.swift').read_text()
  self.assertIn('if debugHostedJourneyEnabled, let lease=modelReply, debugHostedJourneyDisplays.count<64',app)
  self.assertIn('display.revision==currentReplyRevision, display.text==currentReply',app)
  self.assertIn('modelReplyAllowed(display.lease,text:display.text)',app)
  test=(P.parents[1]/'ios/BlindAssistTests/HostedNonvisualJourneyTests.swift').read_text()
  self.assertIn('testAcceptedDisplayRequiresExactCurrentSettledReceipt',test)
  self.assertIn('display["settled"] as? Bool == true',test)
  self.assertIn('accepted_settled_display_not_audio',test)
if __name__=='__main__':unittest.main()
