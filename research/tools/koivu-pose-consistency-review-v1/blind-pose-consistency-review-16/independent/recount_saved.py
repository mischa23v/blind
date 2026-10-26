"""Saved external JSON recount. No raw depths, ICP, native fitting, or map edits."""
from pathlib import Path
import ast,hashlib,json,math,resource,signal,time
start=time.monotonic();resource.setrlimit(resource.RLIMIT_CPU,(2,2));resource.setrlimit(resource.RLIMIT_FSIZE,(1024**2,1024**2));signal.alarm(5)
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;WS=ROOT.parent
POSE=WS/'blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json'
POSE_SHA='c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
pinpath=ROOT/'SOURCE_PINS.json';pinhash=sha(pinpath);pins=json.loads(pinpath.read_text());checks=[]
for row in pins['files']:
 p=ROOT/'upstream'/row['path'];raw=p.read_bytes();h=hashlib.sha256(raw).hexdigest();blob=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
 assert h==row['sha256']and blob==row['gitBlob']and len(raw)==row['bytes'],row['path']
 checks.append({'path':row['path'],'bytes':len(raw),'sha256':h,'gitBlob':blob})
assert sha(POSE)==POSE_SHA
frames=json.loads(POSE.read_text())['frames'];assert len(frames)==294
rows=json.loads((ROOT/'upstream/per_frame_floor.json').read_text());icp=json.loads((ROOT/'upstream/icp_check.json').read_text())
ids=[r['frame']for r in rows];assert len(ids)==len(set(ids))and all(0<=i<294 for i in ids)
by={r['frame']:r for r in rows};nofit=sorted(set(range(294))-set(ids))
def record(i):return {'poseIndexZeroBased':i,'originalRGBFrameID':Path(frames[i]['file_path']).stem,'originalDepthFrameID':Path(frames[i]['depth_file_path']).stem}
def runs(ids):
 out=[]
 for x in ids:
  if not out or x!=out[-1][-1]+1:out.append([x])
  else:out[-1].append(x)
 return [{'start':g[0],'end':g[-1],'count':len(g),'startOriginalFrameID':record(g[0])['originalDepthFrameID'],'endOriginalFrameID':record(g[-1])['originalDepthFrameID']}for g in out]
thresholds={}
for cm in (2.5,3.):
 bad=sorted(r['frame']for r in rows if abs(r['offset_at_centroid'])>cm/100 or r['tilt']>1.2)
 thresholds[str(cm)]={'absoluteOffsetCentimetresStrictlyGreaterThan':cm,'tiltDegreesStrictlyGreaterThan':1.2,'flagged':len(bad),'fittedNotFlagged':len(rows)-len(bad),'noFit':len(nofit),'denominatorTotalFrames':294,'denominatorFittedFrames':len(rows),'frames':[record(i)for i in bad],'runs':runs(bad)}
extra=sorted(set(x['poseIndexZeroBased']for x in thresholds['2.5']['frames'])-set(x['poseIndexZeroBased']for x in thresholds['3.0']['frames']))
tilt_errors=[abs(r['tilt']-math.degrees(math.atan(math.hypot(*r['k'][:2]))))for r in rows]
assert max(tilt_errors)<1e-12
# Frozen source's declared order is read as literal AST, never imported/executed.
tree=ast.parse((ROOT/'upstream/scripts/icp_check.py').read_text());declared=next(ast.literal_eval(n.value)for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='tests'for t in n.targets))
assert [x['frame']for x in icp]==declared
readme_shown=[60,61,62,63,118,250,30,200];omitted=[i for i in declared if i not in readme_shown]
icp_records=[]
for r in icp:
 i=r['frame'];fit=by.get(i)
 icp_records.append({**record(i),'tableRow':r,'perFrameFloorRow':fit,'READMEtableShown':i in readme_shown,'positiveReportedFitness':r['fitness']>0,'absoluteFloorOffsetImproved':abs(r['floorOffset_after_cm'])<abs(r['floorOffset_before_cm']),'floorTiltImproved':r['floorTilt_after']<r['floorTilt_before'],'gateFlag2p5cm':None if fit is None else abs(fit['offset_at_centroid'])>.025 or fit['tilt']>1.2,'gateFlag3cm':None if fit is None else abs(fit['offset_at_centroid'])>.03 or fit['tilt']>1.2})
controls=[x for x in icp_records if x['poseIndexZeroBased']in(250,30,200)];suspects=[x for x in icp_records if x['poseIndexZeroBased']in(60,61,62,63,118)]
assert len(controls)==3 and len(suspects)==5
# Published gate arithmetic only; no hit arrays or reference geometry are loaded.
gate={'publishedLowBandCells':574,'publishedRows':[{'group':'onlyInconsistent','cells':194,'reportedReferenceReal':4},{'group':'includesConsistent','cells':65,'reportedReferenceReal':7},{'group':'noNearHits','cells':315,'reportedReferenceReal':45}], 'countsReproducedFromRawEvidence':False,'selectionAndReferenceCoverageArraysPublishedInSixFilePacket':False}
assert sum(x['cells']for x in gate['publishedRows'])==574
for row in gate['publishedRows']:row['reportedReferenceRealFraction']=row['reportedReferenceReal']/row['cells']
result={'scope':'Independent saved-JSON arithmetic/source review only; no depth, ICP, fitting, mapping or geometry run','repository':pins['repository'],'commit':pins['commit'],'verifiedGitBlobs':checks,'SOURCE_PINS_SHA256':pinhash,'poseFileSHA256':POSE_SHA,'fittedFrameCount':len(rows),'noFitFrameCount':len(nofit),'noFitFrames':[record(i)for i in nofit],'thresholdCounts':thresholds,'additional2p5cmVs3cmFrames':[record(i)for i in extra],'maximumSavedTiltFromCoefficientErrorDegrees':max(tilt_errors),'ICPDeclaredTestCount':len(declared),'ICPPublishedRecordCount':len(icp),'READMEtableRecordCount':len(readme_shown),'READMEtableOmitted':[record(i)for i in omitted],'ICPRecords':icp_records,'shownSuspectDenominator':len(suspects),'shownSuspectsAbsoluteOffsetImproved':sum(x['absoluteFloorOffsetImproved']for x in suspects),'shownControlDenominator':len(controls),'shownControlsTiltIncreased':sum(x['tableRow']['floorTilt_after']>x['tableRow']['floorTilt_before']for x in controls),'shownControlsAbsoluteOffsetWorsened':sum(not x['absoluteFloorOffsetImproved']for x in controls),'publishedGateArithmetic':gate,'all294FrameIDAssociation': [record(i)for i in range(294)],'rawDepthRead':False,'nativeICPExecuted':False,'mapChanged':False,'physicalAuthority':False}
assert sha(pinpath)==pinhash and sha(POSE)==POSE_SHA
for row in checks:assert sha(ROOT/'upstream'/row['path'])==row['sha256']
result['inputHashesVerifiedBeforeAfter']=True;result['wallSeconds']=time.monotonic()-start;result['peakRSSBytes']=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024
assert result['peakRSSBytes']<256*1024**2
signal.alarm(0)
with(HERE/'RECOUNT.json').open('x')as f:json.dump(result,f,indent=2,allow_nan=False);f.write('\n')
print(json.dumps({'fit':len(rows),'nofit':len(nofit),'thresholds':{k:{q:v[q]for q in('flagged','fittedNotFlagged','noFit')}for k,v in thresholds.items()},'extra2p5':extra,'omittedICP':omitted,'ICPclassifications':[{k:r[k]for k in('poseIndexZeroBased','originalDepthFrameID','gateFlag2p5cm','gateFlag3cm','absoluteFloorOffsetImproved','floorTiltImproved','positiveReportedFitness')}for r in icp_records],'wallSeconds':result['wallSeconds'],'peakRSSBytes':result['peakRSSBytes']}),flush=True)
