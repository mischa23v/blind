#!/usr/bin/env python3
"""Read saved evidence only: no evaluator imports, geometry loads or physics runs."""
import csv, hashlib, json, lzma, math
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parent/'journey-benchmark-readiness-84/evaluator-forward-recovery-05'
def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
def result(n):
    return json.loads((ROOT/f'episodes/episode-{n:03d}/result/RESULT.json').read_text())
r=result(56); terminal=r['terminal']; guard=terminal['underbodyGuard']; hit=guard['halfSegments'][1]
trace=ROOT/'episodes/episode-056/result/TICK_EVIDENCE.jsonl.xz'
with lzma.open(trace,'rt') as f:
    count=0
    for line in f:
        last=json.loads(line); count+=1
assert {k:v for k,v in last.items() if k not in ('tick','leg')} == terminal
assert last['tick']==800 and count==801
assert not terminal['candidateStateCommitted'] and terminal['lastCommittedMotionTick']==799
assert not guard['halfSegments'][0]['contact'] and hit['contact']
assert hit['raw']['firstReferenceCellID']==10277130
assert all(not c['actualBody']['contact'] for c in terminal['contacts'])
assert r['actualBodyContactEvents']==0 and r['rejectedPredictedUnderbodyContactEvents']==1
pose=terminal['poseDelivery']['capture']; comparisons=[]
for n in range(55,60):
    other=result(n)
    assert other['pairPlanSHA256']==r['pairPlanSHA256']
    assert other['cacheResultSHA256']==r['cacheResultSHA256']
    assert other['cacheManifestSHA256']==r['cacheManifestSHA256']
    path=ROOT/f'episodes/episode-{n:03d}/result/ACTUAL_TRACE_PARTIAL.csv'
    with path.open() as f: rows=list(csv.DictReader(f))
    nearest=min(rows,key=lambda a:math.hypot(float(a['x'])-pose['position'][0],float(a['z'])-pose['position'][2]))
    comparisons.append({'episode':n,'condition':other['schedule']['conditionID'],'status':other['status'],
      'distanceMetres':other['actualDistanceMetres'],'ticks':other['ticks'],
      'underbodyRejections':other['rejectedPredictedUnderbodyContactEvents'],
      'nearestSavedActualPose':{k:float(nearest[k]) for k in ('tick','x','y','z','yaw')},
      'nearestHorizontalDistanceMetres':math.hypot(float(nearest['x'])-pose['position'][0],float(nearest['z'])-pose['position'][2])})
with (ROOT/'episodes/episode-056/result/ACTUAL_TRACE_PARTIAL.csv').open() as f:
    final=list(csv.DictReader(f))[-1]
# Reconstruct the recorded guard OBB in model coordinates, not a new collision query.
# Frozen source oriented_container.py:47-95; yaw-only second half, identical XZ.
dyaw=float(final['yawDelta'])/2
middle_yaw=pose['yaw']+3*float(final['yawDelta'])/4
pad=2*math.hypot(.15,.225)*math.sin(abs(dyaw)/4)
a,b=.15+pad,.225+pad
c,s=math.cos(middle_yaw),math.sin(middle_yaw)
lo,hi=hit['lowerY'],hit['upperY']
local=[(-a,lo,-b),(a,lo,-b),(a,hi,-b),(-a,hi,-b),(-a,lo,b),(a,lo,b),(a,hi,b),(-a,hi,b)]
corners=[[pose['position'][0]+c*x-s*z,y,pose['position'][2]+s*x+c*z] for x,y,z in local]
with (ROOT/'episodes/episode-056/result/ACTUAL_TRACE_PARTIAL.csv').open() as f:
    stationary=[v for v in csv.DictReader(f) if float(v['x'])==pose['position'][0] and float(v['z'])==pose['position'][2]]
files=[ROOT/'FROZEN.json' ,ROOT/'MATRIX.json',ROOT/'CACHE_MANIFEST.json',trace]
files += [ROOT/name for name in ('local_support.py','oriented_ground_obb_container.py','run_episode.py','oriented_container.py')]
files += [ROOT/f'episodes/episode-{n:03d}/result/RESULT.json' for n in range(55,60)]
out={'scope':'saved record inspection only; no physics rerun or semantic hazard classification',
 'checksPassed':['terminal equals final saved tick','801 tick records, terminal tick800','rejected state uncommitted, last commit799','only second guard half hits','exact recorded face10277130','main body halves clear','zero committed body contact and one underbody rejection','five conditions share plan/cache hashes'],
 'pose':pose,'appliedCommand':terminal['appliedCommand'],'proposedYawRadiansDerived':pose['yaw']+float(final['yawDelta']),
 'proposedPosition':[float(final[k]) for k in ('proposedX','proposedY','proposedZ')],
 'attemptedVerticalDisplacementMetres':float(final['proposedY'])-float(final['y']),
 'derivedSecondGuardOBB':{'coordinateFrame':'model','midpointYawRadians':middle_yaw,'halfExtentsForwardLateral':[a,b],'cornersVTKOrder':corners,'newCollisionQueryPerformed':False},'stationaryXZRows':{'firstTick':int(stationary[0]['tick']),'lastTick':int(stationary[-1]['tick']),'count':len(stationary),'yawChangeRadians':float(stationary[-1]['yaw'])-float(stationary[0]['yaw'])},'underbodyGuard':guard,'samePairComparisons':comparisons,
 'inputSHA256':{str(p.relative_to(HERE.parent.parent)):digest(p) for p in files if p.exists()},
 'limitations':['reference collision veto, not phone hazard detection','conservative sweep may overcount; exact triangle surface intersection with enclosure is not an exact swept-body collision','triangle vertices/contact point/semantic identity not established','nearest recorded position is not identical orientation or clearance proof','ground contacts unmeasured']}
(HERE/'EVIDENCE.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({'checksPassed':out['checksPassed'],'comparisons':comparisons},indent=2))
