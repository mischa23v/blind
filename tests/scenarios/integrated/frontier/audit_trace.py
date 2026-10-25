#!/usr/bin/env python3
"""Mechanical completeness/provenance audit. Semantic correctness needs independent review."""
import sys,json,pathlib,hashlib,collections
root=pathlib.Path(__file__).resolve().parent
rows=[json.loads(x) for x in pathlib.Path(sys.argv[1]).read_text().splitlines() if x.strip()]
cases=json.loads((root/'public/episodes.json').read_text());prev='0'*64;errors=[];turns=collections.defaultdict(list);restarts=collections.Counter()
for i,row in enumerate(rows,1):
 signed=dict(row);digest=signed.pop('entry_sha256');actual=hashlib.sha256(json.dumps(signed,sort_keys=True,separators=(',',':')).encode()).hexdigest()
 if digest!=actual or row['previous_sha256']!=prev or row['sequence']!=i:errors.append(f'Broken hash chain or sequence at {i}')
 prev=digest
 op=row['request']['op'];state=row['response'].get('state',{});eid=state.get('episode');turn=state.get('turn',-1)
 if op=='start':restarts[eid]+=1
 if eid and turn>=0:turns[(eid,turn)].append(row)
summary=[]
for eid,events in cases.items():
 complete=True;detail=[]
 for t,event in enumerate(events):
  records=turns[(eid,t)];received=any(r['request']['op']=='next_user' and r['response']['state']['utterance']==event['text'] for r in records)
  deliveries=[r for r in records if r['request']['op'] in ('deliver_code','deliver_candidate') and r['response']['result'].get('delivered')]
  rejects=[r for r in records if r['request']['op'] in ('deliver_code','deliver_candidate') and not r['response']['result'].get('delivered')]
  complete &= received and bool(deliveries)
  detail.append({'turn':t,'utterance':event['text'],'received_exact_fixture':received,'delivery_count':len(deliveries),'rejected_candidate_or_code_output_count':len(rejects),'call_count':len(records)})
 summary.append({'episode':eid,'all_turns_received_and_text_delivered':complete,'semantic_outcome':'PENDING_INDEPENDENT_REVIEW','restart_count':restarts[eid],'turns':detail})
print(json.dumps({'hash_chain_errors':errors,'mechanically_complete_text_episodes':sum(x['all_turns_received_and_text_delivered'] for x in summary),'native_device_episodes':0,'episodes':summary},indent=2))
