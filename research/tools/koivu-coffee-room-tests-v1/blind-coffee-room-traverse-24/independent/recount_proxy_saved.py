"""Saved JSON reference-proxy recount only; no planner/NPZ imports."""
from pathlib import Path
import json,hashlib,math
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text())
r=load(ROOT/'reference-proxy-diagnostic/RESULT.json');c=load(ROOT/'reference-proxy-diagnostic/COUNTS.json');l=load(ROOT/'postrun/LOCALIZATION.json');rows=r['blockedNeighborhoodRows']
assert r['counts']==c and r['phoneNeighborhoodSourceSHA256']==sha(ROOT/'postrun/LOCALIZATION.json')
assert r['routeFrozenManifestSHA256']==sha(ROOT/'FROZEN.json')=='cf52680013ba59c6427f8bbd12d85e15ed09436342be9dfd93e7e35b03a6fa74'
assert len(rows)==len({tuple(x['sourceIJ'])for x in rows})==158
critical=l['minimumClearanceWitnessCellsSourceIJ'];near={(i+di,j+dj)for i,j in critical for di in range(-3,4)for dj in range(-3,4) if 0<=i+di<151 and 0<=j+dj<179}
assert len(near)==436 and all(tuple(x['sourceIJ'])in near for x in rows)
assert len(critical)==32 and all(x in l['pointWitnessSourceIJ']for x in critical)
sets={'neighborhoodBlocked':rows,'neighborhoodHighObstacleBlocked':[x for x in rows if x['phoneFlags']['highObstacle']],'neighborhoodMissingSupportBlocked':[x for x in rows if not x['phoneFlags']['support']],'neighborhoodHighUnknownBlocked':[x for x in rows if x['phoneFlags']['highUnknown']],'neighborhoodLow1Blocked':[x for x in rows if x['phoneFlags']['low1']],'neighborhoodNearDipBlocked':[x for x in rows if x['phoneFlags']['nearDip']]}
out={}
for name,sub in sets.items():
 counts=dict.fromkeys(c[name],0);counts['cells']=len(sub);part={'geometry':set(),'floorOnlyProxy':set(),'noFloor':set()}
 for x in sub:
  key=tuple(x['sourceIJ']);cov=x['referenceVertexCount']>0;floor=x['referenceFloorHeightMetres']is not None;low=x['referenceLowBandMaxMetres']is not None and x['referenceLowBandMaxMetres']>=.025;body=x['referenceBodyBandMaxMetres']is not None;geom=low or body;fo=cov and floor and not geom
  assert fo==x['referenceFloorWithoutSavedObstacleVerticesProxy'] and not x['phoneFlags']['walk']
  values={'referenceCovered':cov,'referenceFloorProxyPresent':floor,'referenceLowAtLeast2p5cm':low,'referenceBodyBandVertex':body,'referenceLowOrBodyGeometry':geom,'referenceFloorAndNoSavedLowOrBodyGeometry':fo,'referenceMissingCoverage':not cov,'referenceNoFloorProxy':not floor}
  for k,v in values.items():counts[k]+=int(v)
  if geom:part['geometry'].add(key)
  if fo:part['floorOnlyProxy'].add(key)
  if not floor:part['noFloor'].add(key)
 assert counts==c[name]
 out[name]={'recounted':counts,'geometryFloorOnlyNoFloorDisjointForTheseSavedRows':not(part['geometry']&part['floorOnlyProxy']or part['geometry']&part['noFloor']or part['floorOnlyProxy']&part['noFloor']),'threeGroupsCoverSavedRows':len(set.union(*part.values()))==len(sub)}
assert not r['plannerOrRouteRerun'] and not r['referenceFedToPlanner']
result={'scope':'Independent arithmetic of saved blocked-row JSON and source inspection; no NPZ materialization or route rerun','sourceFilesSHA256':{str(p.relative_to(ROOT)):sha(p)for p in [ROOT/'reference-proxy-diagnostic/SCOPE.md',ROOT/'reference-proxy-diagnostic/triage.py',ROOT/'reference-proxy-diagnostic/RESULT.json',ROOT/'reference-proxy-diagnostic/COUNTS.json',ROOT/'postrun/localize.py',ROOT/'postrun/LOCALIZATION.json']},'countsReproduced':out,'criticalPointWitnessCells':32,'phoneOnlyNeighborhoodCellsFromWitness':436,'newReferenceInputToPlanner':False,'originalRouteManifestUnchanged':True,'rawArrayValuesIndependentlyVerified':False}
(ROOT/'independent/PROXY_RECOUNT.json').write_text(json.dumps(result,indent=2)+'\n');print('Saved-proxy recount passed for six blocked subsets; 158 unique blocked rows in 436-cell phone-only witness neighborhood.')
