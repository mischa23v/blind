#!/usr/bin/env python3
"""Read saved CI evidence and original public JSON only; no native imports/runs."""
import json,pathlib,hashlib,math,collections
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[1];repo=ROOT
j=json.loads((HERE/'INPUT_EVIDENCE.json').read_text());ev=j
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
checks={n:sha(repo/n)==h for n,h in ev['sourceSHA256'].items()};assert all(checks.values())
rooms={r:json.loads((repo/f'ios/BlindAssistTests/Fixtures/RoomPlanApple/{r}.capturedRoom.json').read_text()) for r in ['Hallway2','Bedroom3']}
bed=rooms['Bedroom3']['objects'][0]
def box_clearance(p,b):
 t=b['transform'];d=b['dimensions'];v=[p[i]-t[12+i] for i in range(3)];local=[sum(t[4*c+i]*v[i] for i in range(3)) for c in range(3)]
 return math.hypot(max(abs(local[0])-d[0]/2,0),max(abs(local[2])-d[2]/2,0))
def segdist(p,a,b):
 v=[b[i]-a[i] for i in [0,2]];q=[p[i]-a[i] for i in [0,2]];f=max(0,min(1,sum(x*y for x,y in zip(v,q))/sum(x*x for x in v)))
 return math.hypot(*(q[i]-f*v[i] for i in range(2)))
reports=[]
for report in ev['reports'][:3]:
 rows=[]
 for o in report['report']['outcomes']:
  r={k:v for k,v in o.items() if k not in ['productionGuidanceReceipts','segments','routePoints']}
  if o.get('nativeComplete'):
   r['nativeYValues']=sorted(set(p[1] for p in o['routePoints']))
   r['projectionVerticalOffsets']={k:o['projected'+k][1]-o['requested'+k][1] for k in ['Start','Goal']}
   r['contactSegments']=[s for s in o['segments'] if s.get('bodyContact') or s.get('marginContact')]
   r['noncontactEndpointConnectors']=[s['kind'] for s in o['segments'] if not s.get('bodyContact') and not s.get('marginContact') and not s['kind'].startswith('detour-')]
   if o.get('initialMarginContact') and o.get('sourceSHA256')==ev['sourceSHA256']['ios/BlindAssistTests/Fixtures/RoomPlanApple/Bedroom3.capturedRoom.json']:
    d=box_clearance(o['requestedStart'],bed);r['analyticBedOBBHorizontalClearanceMetres']=d;r['analyticBedMarginOverlapMetres']=.32204651832580566-d
   if o.get('pair')=='hall-corner':
    walls=[w for w in rooms['Hallway2']['walls'] if w['identifier'] in o['obstacleSurfaceIDs']]
    r['analyticOriginalWallSegmentChecks']=[]
    for w in walls:
     t=w['transform'];h=w['dimensions'][0]/2;a=[t[12+i]-h*t[i] for i in range(3)];b=[t[12+i]+h*t[i] for i in range(3)]
     ds=[segdist(p,a,b) for p in o['routePoints']]
     r['analyticOriginalWallSegmentChecks'].append({'wallID':w['identifier'],'minimumWaypointToOriginalWallSegmentMetres':min(ds),'atNativeWaypointIndex':ds.index(min(ds)),'rawRadiusMetres':o['rawRadius'],'effectiveRadiusMetres':o['effectiveRadius'],'caveat':'Original full wall extent, not door-cutout-aware triangle clearance; not a new collision oracle.'})
  rows.append(r)
 reports.append({'attachment':report['attachmentName'],'attachmentSHA256':report['sha256'],'outcomes':dict(collections.Counter(o['outcome'] for o in report['report']['outcomes'])),'rows':rows})
out={'inputLogSHA256':j['inputLogSHA256'],'commit':j['expected_commit'],'nativeCases':j['case_count'],'sourceChecks':checks,'reports':reports,'nativeExecutionPerformed':False,'sourceOrGeometryModified':False}
expected=json.loads((HERE/'RESULTS.json').read_text());assert out==expected, 'Saved result mismatch'
print(json.dumps({'sourceChecks':len(checks),'nativeCases':j['case_count'],'reports':[{'attachment':r['attachment'],'outcomes':r['outcomes']} for r in reports]},indent=2))
