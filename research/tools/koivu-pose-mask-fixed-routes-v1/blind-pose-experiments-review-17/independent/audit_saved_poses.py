"""Saved poses and receipt arithmetic only; no images, fitting, ICP, fusion, or maps."""
from pathlib import Path
import hashlib,json,math,resource,signal,time
START=time.monotonic();resource.setrlimit(resource.RLIMIT_CPU,(2,2));resource.setrlimit(resource.RLIMIT_FSIZE,(1024**2,1024**2));signal.alarm(5)
import numpy as np
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;WS=ROOT.parent;UP=ROOT/'upstream';P=UP/'pose-consistency/poses'
ORIGINAL=WS/'blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json'
META=WS/'blind-split-candidate-game-03/inputs/koivu_5cm_v2_pipeline2_out.npz'
OLD_FITS=WS/'blind-pose-consistency-review-16/upstream/per_frame_floor.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
pinpath=ROOT/'SOURCE_PINS.json';pins=json.loads(pinpath.read_text());verified=[]
assert pins['commit']=='b0be8628b159e0fc0446a7af8c57c13c99553a77'and len(pins['files'])==24
for r in pins['files']:
 raw=(UP/r['path']).read_bytes();h=hashlib.sha256(raw).hexdigest();blob=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
 assert h==r['sha256']and blob==r['gitBlob']and len(raw)==r['bytes']
 verified.append({'path':r['path'],'sha256':h,'gitBlob':blob,'bytes':len(raw)})
assert sha(ORIGINAL)=='c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3'
assert sha(META)=='a2fc5c13f86bf7033131347fd9b6d61db23ab716d12d668a3d969b9e87dbf48d'
assert sha(OLD_FITS)=='680a0e077b7ac357b72811fa5fb87c8e3f4d7de6033524e0d0a2f25a4c4a3b2c'
original=json.loads(ORIGINAL.read_text());new=json.loads((P/'koivu_floorfix_transformations.json').read_text());kr=json.loads((P/'koivu_floorfix_RECEIPT.json').read_text())
assert len(original['frames'])==len(new['frames'])==294
assert set(new)-set(original)=={'pose_refinement'}and not set(original)-set(new)
assert all(original[k]==new[k]for k in original if k!='frames')
assert new['pose_refinement']['rules']==kr['rules']
with np.load(META,allow_pickle=False)as z:L=np.eye(4);L[:3,:3]=z['R'];L[:3,3]=z['t']
Li=np.linalg.inv(L);changed=[];unchanged=[];matrices=[];maximum_frame_rotation_orthogonality_before=0.;maximum_frame_rotation_orthogonality_after=0.
for i,(f0,f1)in enumerate(zip(original['frames'],new['frames'])):
 assert {k:v for k,v in f0.items()if k!='transform_matrix'}=={k:v for k,v in f1.items()if k!='transform_matrix'}
 C0=np.asarray(f0['transform_matrix'],float);C1=np.asarray(f1['transform_matrix'],float)
 assert C0.shape==C1.shape==(4,4)and np.isfinite(C0).all()and np.isfinite(C1).all()
 maximum_frame_rotation_orthogonality_before=max(maximum_frame_rotation_orthogonality_before,float(abs(C0[:3,:3].T@C0[:3,:3]-np.eye(3)).max()))
 maximum_frame_rotation_orthogonality_after=max(maximum_frame_rotation_orthogonality_after,float(abs(C1[:3,:3].T@C1[:3,:3]-np.eye(3)).max()))
 if np.array_equal(C0,C1):unchanged.append(i);continue
 changed.append(i);M=L@C1@np.linalg.inv(C0)@Li;Q=M[:3,:3];u=M[:3,3];c0=(L@C0)[:3,3];c1=(L@C1)[:3,3];delta=c1-c0
 sv=np.linalg.svd(Q,compute_uv=False);angle=math.acos(float(np.clip((np.trace(Q)-1)/2,-1,1)))
 axis=np.array([Q[2,1]-Q[1,2],Q[0,2]-Q[2,0],Q[1,0]-Q[0,1]])/(2*math.sin(angle))
 orth=float(abs(Q.T@Q-np.eye(3)).max());affine=float(abs(M[3]-[0,0,0,1]).max());equation=float(abs(delta-((Q-np.eye(3))@c0+u)).max())
 assert orth<1e-12 and affine<1e-12 and abs(np.linalg.det(Q)-1)<1e-12 and max(abs(sv-1))<1e-12 and equation<1e-12
 assert round(math.degrees(angle),2)==kr['decisions'][str(i)]['tilt_deg']
 matrices.append({'poseIndexZeroBased':i,'originalRGBFrameID':Path(f0['file_path']).stem,'originalDepthFrameID':Path(f0['depth_file_path']).stem,'levelCorrectionM':M.tolist(),'rotationDegrees':math.degrees(angle),'rotationAxis':axis.tolist(),'rotationAxisZMagnitude':float(abs(axis[2])),'EulerZYXMatrixYawDegrees':math.degrees(math.atan2(Q[1,0],Q[0,0])),'determinant':float(np.linalg.det(Q)),'singularValues':sv.tolist(),'rotationOrthogonalityMaxAbsError':orth,'affineBottomRowMaxAbsError':affine,'oldCameraLevelXYZ':c0.tolist(),'newCameraLevelXYZ':c1.tolist(),'actualCameraLevelDisplacementMetres':delta.tolist(),'actualCameraHorizontalDisplacementMetres':float(np.linalg.norm(delta[:2])),'globalLevelTransformTranslationMetres':u.tolist(),'cameraDisplacementEquationMaxAbsError':equation,'sourceNNDecision':kr['decisions'][str(i)]})
assert changed==kr['corrected']==[23,24,61,62,63,119,132,229,230]
assert len(unchanged)==285 and set(kr['poseInconsistent'])<=set(unchanged)

def audit_receipt(room,receipt,frames,has_original):
 flagged=receipt['flagged'];acc=receipt['corrected'];rej=receipt['poseInconsistent'];dec=receipt['decisions'];n=len(frames)
 assert sorted(set(flagged))==flagged and set(acc).isdisjoint(rej)and set(acc)|set(rej)==set(flagged)
 assert set(map(int,dec))==set(flagged)
 log=next(x for x in receipt['log']if x['stage']=='floorfix')
 assert log['flagged']==len(flagged)and log['corrected']==len(acc)and log['keptPoseInconsistent']==len(rej)
 assert log['framesWithFloorFit']+log['noFloorFit']==n
 decisions=[]
 for i in flagged:
  x=dec[str(i)];accepted=x['decision']=='corrected';assert accepted==(i in acc)
  row={'poseIndexZeroBased':i,'exportedRGBFrameID':Path(frames[i]['file_path']).stem,'exportedDepthFrameID':Path(frames[i]['depth_file_path']).stem,'IDComparedWithOriginalCapture':has_original,'savedDecision':x,'accepted':accepted}
  if 'nonfloorNN_mm_before'in x:
   b=x['nonfloorNN_mm_before'];a=x['nonfloorNN_mm_after'];diff=b-a;required=max(.1*b,2.)
   lower=min((b-.05)-(a+.05)-2.,.9*(b-.05)-(a+.05));upper=min((b+.05)-(a-.05)-2.,.9*(b+.05)-(a-.05))
   rounded=diff>=required;classification='guaranteedPass'if lower>=0 else'guaranteedFail'if upper<0 else'roundingAmbiguous'
   assert rounded==accepted and classification!='roundingAmbiguous'and(classification=='guaranteedPass')==accepted
   row.update(roundedImprovementMM=diff,roundedRequiredImprovementMM=required,roundedCriterionPassed=rounded,roundingIntervalCriterionMarginMM=[lower,upper],roundingIntervalClassification=classification)
  else:row['roundedNNRecount']='unavailable: reason-only record'
  decisions.append(row)
 return {'scope':'Saved receipt/export fields; no original-pose comparison'if not has_original else'Saved receipt plus exact original-pose comparison','totalExportedFrames':n,'fittedFramesReported':log['framesWithFloorFit'],'noFitFramesReported':log['noFloorFit'],'flagged':len(flagged),'corrected':len(acc),'rejected':len(rej),'allDecisionsRecounted':decisions,'unflaggedTargetEligiblePoolCount':n-len(flagged),'fittedUnflaggedInTargetPoolCount':log['framesWithFloorFit']-len(flagged),'noFitIncludedInUnflaggedTargetPoolCount':log['noFloorFit'],'targetPoolCountsAreBeforeTemporalGapAndPointAvailability':True,'noFitPerFrameIDsUnavailableInReceipt':True,'originalMatricesCompared':has_original}
coffee=json.loads((P/'coffee_floorfix_transformations.json').read_text());cr=json.loads((P/'coffee_floorfix_RECEIPT.json').read_text())
receipts={'koivu':audit_receipt('koivu',kr,original['frames'],True),'coffee':audit_receipt('coffee',cr,coffee['frames'],False)}
oldfits=json.loads(OLD_FITS.read_text());oldflags={r['frame']for r in oldfits if abs(r['offset_at_centroid'])>.025 or r['tilt']>1.2}
newflags=set(kr['flagged'])
result={'scope':'Independent saved-pose/receipt audit only; no depth/ICP/fusion/map run','commit':pins['commit'],'verifiedSourceFiles':verified,'sourcePinsSHA256':sha(pinpath),'originalKoivuPoseSHA256':sha(ORIGINAL),'originalSuppliedLevelMetadataSHA256':sha(META),'koivuFrames':294,'koivuChangedMatrices':changed,'koivuExactlyUnchangedMatrices':unchanged,'all294PerFrameNonPoseFieldsExactlyEqual':True,'allOriginalTopLevelNonFrameFieldsExactlyEqual':True,'addedTopLevelField':'pose_refinement','relativeCorrectionsRigidNoScale':True,'inheritedOriginalPoseMaxRotationOrthogonalityError':maximum_frame_rotation_orthogonality_before,'refinedPoseMaxRotationOrthogonalityError':maximum_frame_rotation_orthogonality_after,'derivedLevelCorrections':matrices,'cameraHorizontalDisplacementRangeMetres':[min(r['actualCameraHorizontalDisplacementMetres']for r in matrices),max(r['actualCameraHorizontalDisplacementMetres']for r in matrices)],'maximumCorrectionRotationScaleError':max(max(abs(np.array(r['singularValues'])-1))for r in matrices),'receipts':receipts,'oldFloat64Axial2p5cmFlagCount':len(oldflags),'newFloat32Euclidean2p5cmFlagCount':len(newflags),'newOnlyFlagIndices':sorted(newflags-oldflags),'oldOnlyFlagIndices':sorted(oldflags-newflags),'differencesAreNotJustOld3cmThreshold':True,'targetNoFitInclusionSource':'unflagged=[i for i in range(n) if i not in flag]; no-fit never enters flag, so no-fit is included before abs(j-i)>=25','nonfloorValidationIsFinalHoldout':False,'reason':'The same non-floor NN data chooses which corrections to accept. It is validation for a floor-only candidate, not an untouched final test.','noIndependentHorizontalOrYawParameterDoesNotMeanZeroCameraHorizontalMotion':True,'coffeeOriginalCaptureMatricesAvailable':False,'noPhysicalSafetyClaim':True}
for r in verified:assert sha(UP/r['path'])==r['sha256']
assert sha(ORIGINAL)==result['originalKoivuPoseSHA256']and sha(META)==result['originalSuppliedLevelMetadataSHA256']
result['inputHashesVerifiedBeforeAfter']=True;result['wallSeconds']=time.monotonic()-START;result['peakRSSBytes']=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024
assert result['peakRSSBytes']<256*1024**2
signal.alarm(0)
with(HERE/'POSE_RECEIPT_AUDIT.json').open('x')as f:json.dump(result,f,indent=2,allow_nan=False);f.write('\n')
print(json.dumps({'changed':changed,'unchanged':len(unchanged),'cameraHorizontalDisplacementRangeMetres':result['cameraHorizontalDisplacementRangeMetres'],'relativeScaleError':result['maximumCorrectionRotationScaleError'],'receipts':{k:{x:v[x]for x in('totalExportedFrames','fittedFramesReported','noFitFramesReported','flagged','corrected','rejected','unflaggedTargetEligiblePoolCount','fittedUnflaggedInTargetPoolCount','noFitIncludedInUnflaggedTargetPoolCount')}for k,v in receipts.items()},'wallSeconds':result['wallSeconds'],'peakRSSBytes':result['peakRSSBytes']}),flush=True)
