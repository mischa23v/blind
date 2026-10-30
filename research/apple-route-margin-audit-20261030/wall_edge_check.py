#!/usr/bin/env python3
"""Saved projected wall-edge arithmetic only, not a replacement 3D collider.
Both implicated walls are vertical. No native execution or source mutations.
"""
import json,struct,math,pathlib
HERE=pathlib.Path(__file__).resolve().parent
j=json.loads((HERE/'INPUT_EVIDENCE.json').read_text());r=j['reports'];f=next(f for f in r[-1]['report']['fixtures'] if f['fixtureID']=='Hallway2');vs=[struct.unpack('<f',struct.pack('<I',i))[0]for i in f['worldPositionBits']];pts=[vs[i:i+3]for i in range(0,len(vs),3)]
def d(p,a,b):
 v=[b[i]-a[i] for i in [0,2]];q=[p[i]-a[i] for i in [0,2]];n=sum(x*x for x in v);u=max(0,min(1,sum(x*y for x,y in zip(v,q))/n))if n else 0;return math.hypot(*(q[i]-u*v[i] for i in range(2)))
for rr in r[:2]:
 o=next(x for x in rr['report']['outcomes'] if x.get('pair')=='hall-corner' and x.get('nativeComplete'))
 best=(1e9,None)
 for ti,id in enumerate(f['triangleFeatureIDs']):
  if id not in o['obstacleSurfaceIDs']:continue
  tri=[pts[k]for k in f['triangleIndices'][ti*3:ti*3+3]]
  for s in o['segments']:
   low=min(s['from'][1],s['to'][1]);hi=max(s['from'][1],s['to'][1])+o['effectiveHeight']
   if min(v[1]for v in tri)>hi or max(v[1]for v in tri)<low:continue
   for a,b in zip(tri,tri[1:]+tri[:1]):
    m=min(d(s['from'],a,b),d(s['to'],a,b),d(a,s['from'],s['to']),d(b,s['from'],s['to']))
    if m<best[0]:best=(m,{'triangle':ti,'id':id,'segment':s['kind'],'tri':tri})
 print(o['profile'],best,'overlap',o['effectiveRadius']-best[0])
