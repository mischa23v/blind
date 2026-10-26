from pathlib import Path
import importlib.util,json,hashlib,math
import numpy as np
ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('coffee_proxy_inputs',ROOT/'coffee_routes.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
flags,meta=m.phone_inputs();local=json.loads((ROOT/'postrun/LOCALIZATION.json').read_text());mask=flags['walk'];critical=np.asarray(local['minimumClearanceWitnessCellsSourceIJ']);near=np.zeros(mask.shape,bool);critical_mask=np.zeros(mask.shape,bool)
for i,j in critical:near[max(0,i-3):i+4,max(0,j-3):j+4]=True;critical_mask[i,j]=True
allow=('ref_n','ref_low_max','ref_body_max','ref_floor_h')
with np.load(m.META,allow_pickle=False)as z:ref={k:z[k].copy()for k in allow}
if any(v.shape!=mask.shape for v in ref.values()):raise ValueError('reference column schema')
cov=ref['ref_n']>0;floor=np.isfinite(ref['ref_floor_h']);low=ref['ref_low_max']>=.025;body=np.isfinite(ref['ref_body_max']);geom=low|body;floor_only_proxy=cov&floor&~geom
cats={'referenceCovered':cov,'referenceFloorProxyPresent':floor,'referenceLowAtLeast2p5cm':low,'referenceBodyBandVertex':body,'referenceLowOrBodyGeometry':geom,'referenceFloorAndNoSavedLowOrBodyGeometry':floor_only_proxy,'referenceMissingCoverage':~cov,'referenceNoFloorProxy':~floor}
sets={'neighborhoodAll':near,'neighborhoodBlocked':near&~mask,'neighborhoodHighObstacleBlocked':near&~mask&flags['highObstacle'],'neighborhoodMissingSupportBlocked':near&~mask&~flags['support'],'neighborhoodHighUnknownBlocked':near&~mask&flags['highUnknown'],'neighborhoodLow1Blocked':near&~mask&flags['low1'],'neighborhoodNearDipBlocked':near&~mask&flags['nearDip'],'criticalPointWitnessCells':critical_mask,'neighborhoodWalk':near&mask}
counts={name:{'cells':int(s.sum()),**{label:int((s&test).sum())for label,test in cats.items()}}for name,s in sets.items()}
rows=[]
for i,j in np.argwhere(near&~mask):
 xy=meta['lo'][:2]*.05+(np.array([i,j])+.5)*.05
 rows.append({'sourceIJ':[int(i),int(j)],'levelXYMetres':xy.tolist(),'phoneFlags':{k:bool(v[i,j])for k,v in flags.items()},'referenceVertexCount':int(ref['ref_n'][i,j]),'referenceFloorHeightMetres':float(ref['ref_floor_h'][i,j])if floor[i,j]else None,'referenceLowBandMaxMetres':float(ref['ref_low_max'][i,j])if np.isfinite(ref['ref_low_max'][i,j])else None,'referenceBodyBandMaxMetres':float(ref['ref_body_max'][i,j])if body[i,j]else None,'referenceFloorWithoutSavedObstacleVerticesProxy':bool(floor_only_proxy[i,j])})
result={'candidateCheckpoint':'b0be8628b159e0fc0446a7af8c57c13c99553a77','candidate':'older coffee_floorfix split0.7, NOT latest Opus color/v3','analysisMode':'postrun isolated saved-reference-vertex-column diagnostic; no triangle scorer and no map edits','referenceKeysRead':list(allow),'selectionWasFrozenPhoneOnlyBeforeReferenceRead':True,'phoneNeighborhoodSourceSHA256':m.sha(ROOT/'postrun/LOCALIZATION.json'),'metadataNPZSHA256':m.sha(m.META),'routeFrozenManifestSHA256':m.sha(ROOT/'FROZEN.json'),'counts':counts,'blockedNeighborhoodRows':rows,'physicalBarrierVerified':False,'falsePhoneBarrierVerified':False,'plannerOrRouteRerun':False,'referenceFedToPlanner':False,'limitations':['No actual coffee RGB/depth frames or occupied/free leaf clouds are local; collapsed flags cannot identify source frames or physical semantics.','Vertex absence is not mesh-surface absence; this is not enough to remove a blocker or claim traversability.','The available reference arrays were generated and registered upstream; no independent registration/triangle replay was performed here.','Semantic venue is the dataset name coffee_room, not proof of a public cafe or accessible customer route.']}
(ROOT/'reference-proxy-diagnostic/RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(counts,indent=2))
