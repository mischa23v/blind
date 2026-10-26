"""Saved arrays/JSON only; never reread depth images or execute upstream functions."""
from pathlib import Path
import hashlib,json,resource,signal,time
START=time.monotonic();resource.setrlimit(resource.RLIMIT_CPU,(2,2));resource.setrlimit(resource.RLIMIT_FSIZE,(1024**2,1024**2));signal.alarm(5)
import numpy as np
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;WS=ROOT.parent;OUT=ROOT/'run-01/result'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
expected='4ee880e20500252df73496f1ee1870872e8315d7fb565a04eec701cd2e39514d'
assert sha(OUT/'RESULT.json')==expected
r=json.loads((OUT/'RESULT.json').read_text());receipt=json.loads((ROOT/'run-01/RUN_RECEIPT.json').read_text());freeze=json.loads((ROOT/'FROZEN.json').read_text())
assert receipt['success']and receipt['frozenManifestSHA256']==sha(ROOT/'FROZEN.json')
nondepth={k:v for k,v in freeze['files'].items()if '/depths/frame_'not in k};depthpins={k:v for k,v in freeze['files'].items()if '/depths/frame_'in k}
assert len(depthpins)==294 and len(nondepth)==18
for k,h in nondepth.items():assert sha(WS/k)==h,k
manifest=json.loads((WS/'blind-koivu-game-07/map/depths/DEPTH_INPUT_MANIFEST.json').read_text())
assert depthpins=={'blind-koivu-game-07/map/depths/'+x['file']:x['sha256']for x in manifest['files']}
a=json.loads((OUT/'REPRODUCED_PLANES.json').read_text());b=json.loads((ROOT/'upstream/per_frame_floor.json').read_text())
assert len(a)==len(b)==r['fits']==252
assert [x['frame']for x in a]==[x['frame']for x in b]
maxima={k:0. for k in ('tilt','offset_at_centroid','resid_mad','k','camH')}
for x,y in zip(a,b):
 assert x['n']==y['n']
 for k in maxima:maxima[k]=max(maxima[k],float(np.max(abs(np.asarray(x[k])-np.asarray(y[k])))))
assert maxima==r['maxAbsoluteDifferenceFromSavedPlaneFields']
assert all(v<=1e-10 for v in maxima.values())==r['savedPlanesMatchWithin1eMinus10']
assert sum(abs(x['offset_at_centroid'])>.025 or x['tilt']>1.2 for x in a)==r['inconsistentFrames']==78
assert 294-len(a)==r['noFitFrames']==42
with np.load(OUT/'GATE_COUNTS.npz',allow_pickle=False)as z:d={k:z[k]for k in z.files}
with np.load(WS/'blind-split-candidate-game-03/inputs/koivu_5cm_v2_pipeline2_out.npz',allow_pickle=False)as z:
 low=z['D1__low1']&z['D1__support']&~z['D1__highObstacle'];cov=z['ref_n']>0;real=cov&((z['ref_low_max']>=.025)|(z['ref_body_max']>-np.inf))
gh,bh,nh=d['goodHits'],d['badHits'],d['noFitHits']
assert gh.shape==bh.shape==nh.shape==low.shape
assert all(v.dtype.kind in 'iu'and np.all(v>=0)for v in (gh,bh,nh))
assert np.array_equal(d['lowD1'],low)
groups={'onlyInconsistent':low&(bh>0)&(gh==0)&(nh==0),'anyConsistent':low&(gh>0),'noNearBandHits':low&(bh==0)&(gh==0)&(nh==0),'hasNoFitButNoConsistent':low&(nh>0)&(gh==0)}
union=np.zeros_like(low);counts={}
for k,m in groups.items():
 assert np.array_equal(m,d[k])and not np.any(union&m);union|=m
 counts[k]={'cells':int(m.sum()),'suppliedReferenceVertexProxyPositive':int((m&real).sum()),'suppliedReferenceCoverageCells':int((m&cov).sum()),'noReferenceCoverageCells':int((m&~cov).sum())}
assert np.array_equal(union,low)and counts==r['groups']and int(low.sum())==r['D1LowSupportedNotHighCells']==574
for k,h in nondepth.items():assert sha(WS/k)==h,k
assert sha(OUT/'RESULT.json')==expected
result={'confirmed':True,'sourceAndRuntimeNonDepthPinsRehashed':18,'depthManifestEntriesMatchedToFreezeWithoutDepthReread':294,'reproducedPlaneRows':252,'allSavedInlierCountsAndFrameIndicesMatched':True,'maxSavedPlaneFieldDifferences':maxima,'flaggedAt2p5cm':78,'noFit':42,'D1LowSupportedNotHighCells':574,'groups':counts,'disjointExhaustiveGateGroups':True,'referenceScope':'Existing saved vertex-column proxy only; not actual mesh/triangle queries. D1 groups are not the active split0.7 mask.','notIndependentlyRecountableFromSavedArrays':['zeroAxialDepthSamples','axialVsEuclideanThresholdMembershipDisagreementsAllSamples'],'noNearBandHitsMeaning':'No raw axial-depth-selected low-band hits, not proof of far-only native occupancy provenance.','rawDepthRead':False,'ICPOrFitExecuted':False,'mapChanged':False,'wallSeconds':time.monotonic()-START,'peakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024,'inputOutputHashes':{str(p.relative_to(ROOT)):sha(p)for p in [OUT/'RESULT.json',OUT/'REPRODUCED_PLANES.json',OUT/'GATE_COUNTS.npz',ROOT/'FROZEN.json',ROOT/'run-01/RUN_RECEIPT.json']}}
assert result['peakRSSBytes']<256*1024**2
signal.alarm(0)
with(HERE/'REPRODUCTION_RECOUNT.json').open('x')as f:json.dump(result,f,indent=2,allow_nan=False);f.write('\n')
print(json.dumps(result),flush=True)
