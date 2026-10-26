"""Independent saved-array audit only: no native calls, fusion, original decode or FARO."""
from pathlib import Path
import json,hashlib,resource,time
import numpy as np
resource.setrlimit(resource.RLIMIT_CPU,(30,30));started=time.monotonic()
ROOT=Path(__file__).resolve().parent;WS=ROOT.parents[1];RUN=ROOT/'run-01';D=RUN/'map';V1=ROOT.parent/'map/run-01/map'
checks=0
def ok(v,label):
 global checks
 if not v:raise AssertionError(label)
 checks+=1
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):
 with np.load(p,allow_pickle=False) as z:return {k:z[k]for k in z.files}
def equal(a,b,label):ok(np.array_equal(a,b,equal_nan=True),label)
R=json.loads((D/'MAP_RECEIPT.json').read_text());receipt=json.loads((RUN/'RUN_RECEIPT.json').read_text());frozen=json.loads((ROOT/'FROZEN.json').read_text())
ok(receipt['success'] and receipt['exitCode']==0,'terminal success')
ok(sha(ROOT/'FROZEN.json')==receipt['frozenConfigSHA256'],'frozen receipt pin')
for name,h in frozen['files'].items():ok(sha(WS/name)==h,'frozen file '+name)
for name,h in R['outputs'].items():ok(sha(D/name)==h,'output '+name)
ok(sha(V1/'MAP.npz')==R['rawV1MapSHA256'],'original v1 map pin')
raw=load(V1/'MAP.npz');assoc=load(D/'RAW_NATIVE_ASSOCIATIONS.npz');ev=load(D/'SURFACE_EVIDENCE.npz');leaves=load(D/'OCTOMAP_LEAVES.npz');surface=json.loads((D/'SURFACE.json').read_text())
manifest=json.loads((ROOT.parent/'map/depths/DEPTH_INPUT_MANIFEST.json').read_text());scans=[json.loads(x)for x in (D/'SCANS.jsonl').read_text().splitlines() if x.strip()]
ok(len(scans)==294 and [s['frame']for s in scans]==list(range(294)),'all fixed scans')
for s,e in zip(scans,manifest['files']):
 ok(s['file']==e['file'] and s['sha256']==e['sha256'],'scan source association')
 ok(s['occupiedKeys']==s['representativeRays']<=s['originalPoints'],'per-scan representative keys')
 ok(s['originalPoints']==733572,'all frame pixels')
ok(sum(s['originalPoints'] for s in scans)==R['inputPixels']==215670168,'full endpoint count')
ok(sum(s['nativeBoundaryDifferentPixels']for s in scans)==R['nativeBoundaryDifferentPixels']==577,'boundary changed pixels')
ok(max(s['float32MaxCoordinateConversion']for s in scans)==R['maxFloat32PointConversion'],'max conversion report')
i=raw['voxelIndices'].astype(np.int64);n=len(i);w=int(raw['surfaceWidth']);h=int(raw['surfaceDepth']);total=w*h
ok(n==R['rawVoxels']==811806 and int(raw['voxelHitCount'].astype(np.uint64).sum())==R['inputPixels'],'raw endpoint count')
ri=assoc['rawIndex'];keys=assoc['nativeKeys'];ni=assoc['nativeQueryIndex'];p=len(ri)
ok(p==R['associationPairs']==812380,'association count');equal(ni,np.arange(p),'query index identity');ok(keys.dtype==np.uint16 and keys.shape==(p,3),'native key shape/type');ok(np.all((ri>=0)&(ri<n)),'raw indexes in range')
packed=(keys[:,0].astype(np.uint64)<<32)|(keys[:,1].astype(np.uint64)<<16)|keys[:,2].astype(np.uint64)
order=np.lexsort((packed,ri));ok(not np.any((ri[order][1:]==ri[order][:-1])&(packed[order][1:]==packed[order][:-1])),'actual raw/native key pairs unique')
count=np.bincount(ri,minlength=n);ok(np.all(count>0) and assoc['associationComplete'].all(),'all raw voxels associated')
ok(int(assoc['defaultKeyObserved'].sum())+R['nonCentreKeyAssociations']==p and R['nonCentreKeyAssociations']==574,'default/deviant association accounting')
known=assoc['known'].astype(bool);occupied=assoc['occupied'].astype(bool);hits=assoc['hitScans'];frees=assoc['freeScans']
ok(np.all(known) and np.all(hits>0),'every endpoint-associated key known and hit');ok(np.all((hits<=294)&(frees<=294)),'association scan-count bounds')
def per_raw_count(flag):return np.bincount(ri,weights=np.asarray(flag,dtype=np.uint8),minlength=n)
known_all=per_raw_count(known)==count;occupied_any=per_raw_count(occupied)>0;free_all=per_raw_count(frees>0)==count;hit_all=per_raw_count(hits>0)==count
raw_free=assoc['associationComplete']&(count>0)&known_all&~occupied_any&free_all&hit_all
for key,v in [('rawAssociationCount',count),('rawKnownAll',known_all),('rawOccupiedAny',occupied_any),('rawFreeEvidenceAll',free_all),('rawHitEvidenceAll',hit_all),('rawKnownFreeWithEvidence',raw_free)]:equal(ev[key],v,key)
# Finest leaves have the fixed native key-centre geometry. This is an audit of
# saved keys/scores, not a replacement native classifier or spatial query.
xyz=leaves['xyzSizeProbability'];L=len(xyz);ok(L==R['nativeLeaves']==1422787,'leaf count');ok(np.isfinite(xyz).all() and np.isfinite(leaves['logOdds']).all(),'finite leaves');ok(np.all(xyz[:,3]==.05),'all leaves at native resolution')
leaf_key_signed=np.rint(xyz[:,:3]/.05+32768-.5).astype(np.int64);ok(np.all((leaf_key_signed>=0)&(leaf_key_signed<=65535)),'leaf native key bounds')
reconstructed=(leaf_key_signed.astype(np.float64)-32768+.5)*.05;ok(np.max(abs(reconstructed-xyz[:,:3]))<1e-12,'native centre identity')
leaf_code=(leaf_key_signed[:,0].astype(np.uint64)<<32)|(leaf_key_signed[:,1].astype(np.uint64)<<16)|leaf_key_signed[:,2].astype(np.uint64);sort=np.argsort(leaf_code);ordered=leaf_code[sort];ok(np.all(ordered[1:]>ordered[:-1]),'leaf keys unique');lookup=np.searchsorted(ordered,packed);ok(np.all(lookup<L),'association lookup in bounds');equal(ordered[lookup],packed,'every associated key exists in leaf export');lookup=sort[lookup]
for a,b in [('probability',xyz[:,4]),('logOdds',leaves['logOdds']),('hitScans',leaves['hitScans']),('freeScans',leaves['freeScans'])]:equal(assoc[a],b[lookup],'association/leaf '+a)
# Upstream default occupied log-odds threshold is exactly zero; check saved flag consistency only.
equal(occupied,leaves['logOdds'][lookup]>=0,'saved upstream occupied flags consistent with default native log threshold')
ok(int(leaves['hitScans'].astype(np.uint64).sum())==sum(s['occupiedKeys']for s in scans),'all native hit updates reconcile')
ok(int(leaves['freeScans'].astype(np.uint64).sum())==sum(s['freeKeys']for s in scans),'all native free updates reconcile')
conflicts=int(((leaves['hitScans']>0)&(leaves['freeScans']>0)).sum());ok(conflicts==R['nativeConflictedLeafCount']==scans[-1]['conflictKeys'],'conflict counts reconcile')
# Reconstruct original support/classification without importing the implementation.
mn=raw['voxelMinimumObservedY'];mx=raw['voxelMaximumObservedY'];views=raw['voxelSourceFrameCount'];surf=(i[:,2]//2)*w+i[:,0]//2
ground=(mn>=-.03)&(mx<=.03)&(views>=2);raw_obstacle=(mx>.03)&(mn<1.75);below=(mn<-.03)&(mx>-.25)
quad=np.zeros((total,4),bool);quad[surf[ground],(i[ground,2]%2)*2+i[ground,0]%2]=True;support=quad.all(1)
occ_cells=np.zeros(total,bool);unresolved=np.zeros(total,bool);below_cells=np.zeros(total,bool);ground_conflict=np.zeros(total,bool)
occ_cells[surf[raw_obstacle&occupied_any]]=True;unresolved[surf[raw_obstacle&~raw_free&~occupied_any]]=True;below_cells[surf[below]]=True;ground_conflict[surf[ground&raw_free]]=True;blocked=~support|occ_cells|unresolved|below_cells
for key,v in [('support',support),('rawGround',ground),('rawObstacle',raw_obstacle),('rawBelowFloorContradiction',below),('surfacePositiveOccupied',occ_cells),('surfacePositiveUnresolved',unresolved),('surfaceBelowFloorContradiction',below_cells),('surfaceMissingSupport',~support),('blocked',blocked),('rawGroundNativeFreeWithEvidence',ground&raw_free),('surfaceGroundNativeFreeConflict',ground_conflict)]:equal(ev[key],v,key)
equal(support,raw['surfaceSupport'],'v1 support unchanged');equal(raw_obstacle,raw['voxelObstacle'],'v1 obstacle candidates unchanged');equal(below,raw['voxelFloorContradiction'],'v1 below-floor contradictions unchanged')
eligible=np.flatnonzero(~blocked);equal(ev['eligibleCells'],eligible,'eligible set');projected=ev['projectedSampleCoverage'];ok(projected.shape==(len(eligible),90),'same 90 samples per candidate')
unknown=ev['coverage_sampleNativeUnknown'];sample_occupied=ev['coverage_sampleNativeOccupied'];no_free=ev['coverage_sampleNoActualFreeScan'];admitted=projected&~unknown&~sample_occupied&~no_free
for key,v in [('coverage_sampleMissingOriginalProjection',~projected),('coverage_sampleAdmitted',admitted),('coverage_cellClearanceEstimated',admitted.all(1))]:equal(ev[key],v,key)
clear=np.zeros(total,bool);clear[eligible]=admitted.all(1);equal(ev['surfaceClearanceKnown'],clear,'surface clearance set')
ok(int(clear.sum())==R['surfaceClearanceCells']==359 and len(eligible)==R['surfaceUnblockedCells']==372 and int(support.sum())==2637,'key surface totals')
for k,v in R['classificationCounts'].items():ok(int(ev[k].sum())==v,'classification count '+k)
for k,v in R['coverageCounts'].items():ok(int(ev['coverage_'+k].sum())==v,'coverage count '+k)
ok(surface['width']==w and surface['depth']==h and surface['resolution']==.1 and len(surface['cells'])==total,'Surface schema dimensions')
for j,c in enumerate(surface['cells']):ok(c=={'floor':0. if support[j]else None,'clearance':1.75 if clear[j]else None,'blocked':bool(blocked[j]),'floorUncertainty':None},'Surface cell '+str(j))
ok(not R['FAROUsed'] and not R['physicalAuthority'],'scope flags');ok((RUN/'stderr.log').stat().st_size==0,'stderr empty')
peak=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024;ok(peak<1024**3,'recount RSS bound')
out={'scope':'Saved arrays/JSON only; no native engine calls, original decode, FARO, fusion or game','passed':True,'assertions':checks,'frames':294,'inputPixels':R['inputPixels'],'rawVoxels':n,'associationPairs':p,'boundaryDeviationAssociations':R['nonCentreKeyAssociations'],'boundaryDeviationPixels':R['nativeBoundaryDifferentPixels'],'uniqueNativeAssociatedKeys':int(len(np.unique(packed))),'nativeLeaves':L,'nativeHitUpdates':int(leaves['hitScans'].astype(np.uint64).sum()),'nativeFreeUpdates':int(leaves['freeScans'].astype(np.uint64).sum()),'nativeConflictedLeaves':conflicts,'supportedCells':int(support.sum()),'unblockedCells':len(eligible),'sampledClearanceCells':int(clear.sum()),'groundPriorNativeFreeConflictCells':int(ground_conflict.sum()),'clearanceCellsWithGroundPriorNativeFreeConflict':int((clear&ground_conflict).sum()),'coverageScheduledSamples':int(projected.size),'coverageAdmittedSamples':int(admitted.sum()),'classificationReasonCountsOverlap':True,'coverageReasonCountsOverlap':True,'resources':{'wallSeconds':time.monotonic()-started,'reviewPeakRSSBytes':peak},'pins':{'recountScriptSHA256':sha(Path(__file__)),'mapReceiptSHA256':sha(D/'MAP_RECEIPT.json'),'runnerReceiptSHA256':sha(RUN/'RUN_RECEIPT.json'),'frozenSHA256':sha(ROOT/'FROZEN.json')},'physicalOrNavigationSuccessEstablished':False}
with (ROOT/'POSTRUN_RECOUNT.json').open('x')as f:json.dump(out,f,indent=2);f.write('\n')
print(json.dumps(out,indent=2))
