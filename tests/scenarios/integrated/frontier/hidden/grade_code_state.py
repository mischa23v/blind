#!/usr/bin/env python3
"""Independent post-run state obligations. Never imported by model runner/prompt."""
import json,sys,collections
rows=[json.loads(line) for line in open(sys.argv[1]) if line.strip()];groups=collections.defaultdict(list)
for row in rows:
 s=row['response'].get('state',{});groups[(s.get('episode'),s.get('turn'))].append(row)
checks=[]
def check(name,eid,turn,predicate):
 rs=groups[(eid,turn)]
 checks.append({'obligation':name,'episode':eid,'turn':turn,'status':'NOT_RUN' if not rs else ('PASS' if predicate(rs) else 'FAIL'),'evidence_sequences':[r['sequence'] for r in rs]})
def end(rs):return rs[-1]['response']['state']
def facts(rs):return end(rs).get('facts',{}).get('facts',[])
e='memory_correction_privacy'
check('Original shelf report recorded from exact first utterance',e,0,lambda rs:any(f['place']=='on the shelf' and f['sourceID']==e+'-turn-0' for f in facts(rs)))
check('New explicit correction replaces prior cup report',e,1,lambda rs:len(facts(rs))==1 and facts(rs)[0]['place']=='on the desk')
check('Recall calls real memory lookup and delivers code-owned history',e,2,lambda rs:any(r['request']['op']=='memory_lookup' for r in rs) and any(r['request']['op']=='deliver_code' and r['response']['result'].get('delivered') for r in rs))
check('Privacy removes original records',e,3,lambda rs:not facts(rs) and any(r['request']['op']=='forget' and r['response']['result'].get('removed') for r in rs))
check('Post-deletion lookup contains no remembered fact',e,4,lambda rs:not facts(rs) and any(r['request']['op']=='memory_lookup' for r in rs))
e='persistent_goal_interruption'
check('Persistent school goal established',e,0,lambda rs:end(rs)['goal']=='Help me get ready for school.')
check('Backpack subtask parsed',e,1,lambda rs:end(rs)['request']=='backpack')
check('Pause retains school goal',e,3,lambda rs:end(rs)['task_state']=='paused' and end(rs)['goal']=='Help me get ready for school.')
check('Background cancellation leaves paused goal intact',e,4,lambda rs:end(rs)['task_state']=='paused' and end(rs)['goal']=='Help me get ready for school.')
check('Direct resume retains goal and active subtask',e,5,lambda rs:end(rs)['task_state']=='active' and end(rs)['request']=='backpack')
check('Generic done never completes backpack',e,6,lambda rs:end(rs)['completed']==[])
check('Exact positive backpack completion recorded',e,7,lambda rs:bool(end(rs)['completed']) and end(rs)['goal']=='Help me get ready for school.')
e='preview_map_boundary'
check('Actual external map decoder called',e,0,lambda rs:any(r['request']['op']=='map_read' and r['response']['result'].get('localization')=='preview-only' and not r['response']['result'].get('route_map_present') for r in rs))
e='clock_and_ordinary_conversation'
for t in [0,1]:check('Clock answer obtains fresh production lease',e,t,lambda rs:any(r['request']['op']=='clock_read' for r in rs) and any(r['request']['op']=='deliver_code' and r['response']['result'].get('delivered') for r in rs))
print(json.dumps({'scope':'Code-state checks only. Full response semantics require independent reviewer. No device or safety inference.','checks':checks,'counts':dict(collections.Counter(c['status'] for c in checks))},indent=2))
