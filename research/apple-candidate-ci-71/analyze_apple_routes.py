#!/usr/bin/env python3
"""Diagnostic only; no route acceptance or collision/clearance claims."""
import ctypes as C,gzip,json,math
from pathlib import Path
H=Path(__file__).resolve().parent
r=json.loads(gzip.decompress((H/'fixture/room.json.gz').read_bytes()))
d=json.loads((H/'diagnostic-apple-run/ROUTE_DIAGNOSTIC.json').read_text())
f=lambda x:C.c_float(x).value
mins=[min(map(f,r['vertices'][axis::3]))for axis in range(3)]
m=C.CDLL('libm.so.6');m.fmaf.argtypes=[C.c_float]*3;m.fmaf.restype=C.c_float
cs=f(.025)
rows=[]
for k in [1,4]:
 for j,p in enumerate(d['actualOriginal'][k]['points'][1:-1],1):
  for axis in [0,2]:
   n=round((p[axis]-mins[axis])/cs)
   actual=f(p[axis]);separate=f(mins[axis]+f(n*cs));fused=m.fmaf(n,cs,mins[axis])
   rows.append(dict(pair=k,waypoint=j,axis=axis,integerGridCoordinate=n,apple=actual,separate=separate,fused=fused,appleEqualsFused=actual==fused,appleEqualsSeparate=actual==separate))
length=lambda points:sum(math.dist(a,b)for a,b in zip(points,points[1:]))
summary=[]
for ak,bk in [('actualOriginal','expectedPython58'),('actualExcluded','expectedPython66')]:
 for i,(a,b)in enumerate(zip(d[ak],d[bk])):
  summary.append(dict(routeSet=ak,pair=i,actualPoints=len(a['points']),expectedPoints=len(b['points']),actualLength=length(a['points']),expectedLength=length(b['points']),lengthDifference=length(a['points'])-length(b['points'])))
print(json.dumps(dict(scope='Numerical diagnosis only, not collision validation or changed acceptance',physicalAuthority=False,appleRun=40415772372,appleCommit='3ab6fe02dd0231bc96c8678859f612b53220c7a9',boundsFloat32=mins,cellSizeFloat32=cs,formulaSource='DetourNavMeshBuilder.cpp:494,496',testedWaypointCoordinates=len(rows),allAppleCoordinatesEqualFused=all(x['appleEqualsFused']for x in rows),coordinatesDifferingFromSeparate=sum(not x['appleEqualsSeparate']for x in rows),routeLengths=summary,coordinateEvidence=rows,conclusion='Strong evidence of contracted multiply-add differences; full causality requires controlled compiler variant. Existing strict parity remains failed.'),indent=2))
