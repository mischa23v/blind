import pathlib,json,hashlib
p=pathlib.Path(__file__).parent
r=json.loads((p/'goal_journeys_v1.json').read_text());m=json.loads((p/'FREEZE_MANIFEST.json').read_text())
assert hashlib.sha256((p/m['file']).read_bytes()).hexdigest()==m['sha256']
for name,digest in m['packet_hashes'].items():
 assert hashlib.sha256((p/name).read_bytes()).hexdigest()==digest
assert len(r['cards'])==5
ids=set()
for c in r['cards']:
 assert c['id'] not in ids;ids.add(c['id'])
 assert len(c['request_phrasings'])==3 and len(c['events'])==4
 assert c['execution']=={'status':'not_run','receipts':[]}
 assert c['independent_goal_oracle']['safe_abstention_completes_goal'] is False
 for e in c['events']:
  assert e['event_id'] not in ids;ids.add(e['event_id'])
  assert all(k in e for k in ['trigger','app_observation','hidden_truth','observable_reply_requirements','allowed_actor_actions'])
 assert c['pass_fail']['utility_pass'] and c['pass_fail']['safety_pass']
actor=json.loads((p/'actor_public_packet.json').read_text())
assert all(set(c)=={'id','objective','initial_nonvisual_information','request_phrasings','permitted_user_actions','correction_utterances'} for c in actor['cards'])
for forbidden in ['hidden_truth','app_observation','observable_reply_requirements','independent_goal_oracle','pass_fail']:
 assert forbidden not in json.dumps(actor)
assert actor['observation_source']=='actual admitted/completed speech or VoiceOver receipt only; not authored expected output'
print('PASS: JSON schema invariants, frozen hash, 5 cards / 20 event specifications, actor/evaluator separation. SOURCE VALIDATION ONLY; no app/model/device execution.')
