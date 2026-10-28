#!/usr/bin/env python3
"""Lightweight evidence accounting; no builds/network/physics or source edits."""
import hashlib,json,zipfile
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
load=lambda p:json.loads(p.read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
t=load(HERE/'TRACKER.json'); checks=[]
for p,h in load(HERE/'SOURCE_PINS.json').items():
 assert sha((ROOT/p).read_bytes())==h,p
checks.append('immutable source hashes')
ids={r['id'] for r in t['workstreams']}
assert len(ids)==len(t['workstreams'])
by={r['id']:r for r in t['workstreams']}
def walk(k,active):
 assert k not in active, 'dependency cycle'
 for dep in by[k]['depends_on']:assert dep in ids;walk(dep,active|{k})
for k in ids:walk(k,set())
for r in t['workstreams']:
 for p in r['evidence']:assert (ROOT/p).exists(),p
checks.append('unique workstreams, existing evidence, acyclic dependencies')
f=load(ROOT/'research/journey-benchmark-readiness-84/final-20261028-0325/FINAL_RESULT.json')
assert f['scheduled']==100 and f['completedMovementEpisodes']==94 and f['arrivals']==90
assert len(f['supportStops'])==3 and len(f['predictedUnderbodyRejections'])==1
assert len(f['interruptedUnknown'])==5 and len(f['resourceLimitedPartial'])==1
assert 90+3+1+5+1==100 and not f['physicalAuthority']
assert t['matrix']=={k:f[k] for k in t['matrix']}
checks.append('final100 accounting and nonphysical scope')
for lap in t['historical_assisted_laps']:
 with zipfile.ZipFile(ROOT/lap['archive']) as z:raw=z.read(lap['member'])
 assert sha(raw)==lap['member_sha256']
 v=json.loads(raw)
 for k,x in lap.items():
  if k not in ['archive','member','member_sha256']:assert v[k]==x,k
 assert v['arrival'] and not v['physicalAuthority'] and v['sourceROIManuallyAssisted']
assert [x['completedLaps'] for x in t['historical_assisted_laps']]==[1,3]
checks.append('actual archived one/three-lap result bytes and assisted scope')
o=load(ROOT/'tests/scenarios/integrated/coverage-obligations.json')
assert len(o['navigation'])==40 and len(o['blocked_obligations'])==360
s=load(ROOT/'research/evaluations/integrated-scenarios-20261025/EXECUTION_SUMMARY.json')
assert s['unique_partial_code_sequences']==372 and s['full_user_model_device_episodes_completed']==0
assert len({e['id'] for e in s['episodes']})==372
families=load(ROOT/'tests/scenarios/integrated/requirement-coverage.json')['families']
assert len(t['family_mapping'])==len(families)==53
assert [f['id'] for f in t['family_mapping']]==[f['family_id'] for f in families]
assert all(f['full_family_status']=='NOT_COMPLETE' for f in families)
checks.append('400 obligations, 372 partial sequences, 53 incomplete families')
assert by['F01']['state']=='DEFERRED_BY_USER'
checks.append('Jev deferred, not active')
result={'passed':True,'checks':checks,'scope':'Saved evidence/accounting only; no new physics/native/device execution','source_pin_count':len(load(HERE/'SOURCE_PINS.json'))}
(HERE/'CHECK_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
