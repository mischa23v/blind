"""Independent saved-evidence arithmetic only; no VTK/native/mesh/map query.

Run from any working directory: python /path/to/recount_saved.py
The output is created exclusively; retain prior runs before rerunning.
Source hashes are rechecked, but raw datasets and binaries are not reread here.
"""
from pathlib import Path
import hashlib,json,math,re,time,resource
import numpy as np
HERE=Path(__file__).resolve().parent;STAGE=HERE.parent;WS=STAGE.parent
EXPECTED_RESULT='b24bd9cb312ec5b2401eb7583e3b3b8457019c985c1e150b3458469b398a1ceb'
EXPECTED_TRACE='f7ca7acb14d18d98eb7fce7fd220aa04f95fdfe92febbb38d7eb776ae806a714'
EXPECTED_FROZEN='568653ea6cd6c4211add254a0ecdde13732a7958293ead94fe235bb244dd241a'
SOURCE_SUFFIXES={'.py','.swift','.h','.hpp','.c','.cpp','.md'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def close(a,b,tol=1e-9):
    if not np.allclose(a,b,atol=tol,rtol=0):raise AssertionError((a,b))
def load(p):return json.loads(Path(p).read_text())
def plane_height(x,z,yaw,plane,width,depth):
    # The max over the declared nine planar support locations equals the max
    # over the four rectangle corners (centre and quadrants lie in their hull).
    a,b,c=plane;f=a*math.cos(yaw)+b*math.sin(yaw);l=-a*math.sin(yaw)+b*math.cos(yaw)
    return a*x+b*z+c+abs(f)*depth*.5+abs(l)*width*.5

def main():
    began=time.monotonic();result_path=STAGE/'run-01/result/RESULT.json';trace_path=STAGE/'run-01/result/ACTOR_TRACE.npz'
    query_path=STAGE/'run-01/result/QUERY_OPTIMIZATION.json';run_path=STAGE/'run-01/RUN_RECEIPT.json';frozen_path=STAGE/'FROZEN.json'
    assert sha(result_path)==EXPECTED_RESULT and sha(trace_path)==EXPECTED_TRACE and sha(frozen_path)==EXPECTED_FROZEN
    r=load(result_path);q=load(query_path);run=load(run_path);pins=load(frozen_path)['files']
    assert run['success'] and run['exitCode']==0 and run['failure']is None and run['frozenManifestSHA256']==EXPECTED_FROZEN
    assert run['wallSeconds']<=run['budgets']['wallSeconds'] and run['sampledTreeCPUSeconds']<=run['budgets']['CPUSeconds'] and run['peakSampledOrWaitedTreeRSSBytes']<=run['budgets']['RSSBytes']
    sources={p:h for p,h in pins.items()if Path(p).suffix in SOURCE_SUFFIXES}
    for p,h in sources.items():assert sha(WS/p)==h,p
    prior_path=WS/'blind-split-candidate-game-03/camera-approach-executor-14/run-01/result/SUMMARY.json'
    original_path=WS/'blind-split-candidate-game-03/ground-follow-v3/run-01/result/RESULT.json'
    plan_path=STAGE/'SELECTED_PLAN.json'
    for p in (prior_path,original_path,plan_path):assert sha(p)==pins[str(p.relative_to(WS))]
    prior=load(prior_path)['sharedGround'];original=load(original_path);plan=load(plan_path)
    assert r['planSHA256']==sha(plan_path) and r['correctedMapRevision']==plan['mapRevision']
    assert r['nominalStart']==plan['startCoordinateProvenance']['originalGameXYZ']
    assert r['originalTaskGoal']==r['goal']==plan['taskGoalCoordinateProvenance']['originalGameXYZ']
    assert r['arrival'] and r['motionExecuted'] and r['status']=='arrivalReferenceModelOnly' and r['physicalAuthority']is False
    assert [r['geometry'][k]for k in ('width','depth','height','margin')]==[.45,.30,1.6,0.]
    assert r['ticksWithGroundContact']is None and r['groundTriangleContactReports']is None
    assert all(r[k]==0 for k in ('actualBodyContactEvents','marginContactEvents','nearFootAmbiguousContactEvents'))
    g=r['groundComponent'];plane=np.asarray(g['planeCoefficientsYEqualsAXPlusBZPlusC'],float)
    np.testing.assert_array_equal(plane,prior['planeCoefficientsYEqualsAXPlusBZPlusC'])
    assert g['expandedMembershipBroadPlaneDiagnostic']==g['broadPlaneCoefficientsYEqualsAXPlusBZPlusC']
    assert g['expandedMembershipBroadPlaneFitDiagnostic']==g['broadPlaneFit']
    assert g['initialSupportSeedIDs']==prior['initialSupportSeedIDs']==[x['referenceCellID']for x in original['initialReferenceSupport']['probes']]
    assert g['referenceTransformSHA256']==prior['referenceTransformSHA256']
    assert g['candidateCells']<=g['candidateCap']==3_000_000 and g['surfaceGeometryChanged']is False
    close(np.asarray(r['settledStart'])[[0,2]],np.asarray(r['nominalStart'])[[0,2]],0)
    with np.load(trace_path,allow_pickle=False)as z:t=z['trace'];columns=z['columns'].tolist()
    expected=['tick','time','x','y','z','yaw','proposedX','proposedY','proposedZ','forward','yawDelta','goalError','actualBodyContact','marginContact','currentLowUnresolvedCells','proposedLowUnresolvedCells','unmeasuredGroundContactSentinel']
    assert columns==expected and t.shape==(r['ticks'],len(columns)) and np.isfinite(t).all()
    assert len(t)==139;np.testing.assert_array_equal(t[:,0],np.arange(len(t)));close(t[:,1],100+np.arange(len(t))/15)
    assert np.max(np.abs(t[:,9]))<=.025000001 and np.max(np.abs(t[:,10]))<=math.radians(1)+1e-10
    assert np.all(t[:,12:14]==0) and np.all(t[:,16]==-1)
    previous=np.asarray(r['settledStart'],float);previous_yaw=float(t[0,5]-t[0,10]);initial_yaw=previous_yaw
    goal=np.asarray(r['originalTaskGoal'],float);horizontal=[];three_d=[];max_association=0.;max_plane=0.;moving=0
    width=r['geometry']['width'];depth=r['geometry']['depth']
    close(previous[1],plane_height(previous[0],previous[2],previous_yaw,plane,width,depth))
    for row in t:
        pos=row[2:5];yaw=float(row[5]);forward=float(row[9]);dyaw=float(row[10]);close(yaw,previous_yaw+dyaw)
        expected_xz=previous[[0,2]]+forward*np.array([math.cos(yaw),math.sin(yaw)])
        max_association=max(max_association,float(np.max(np.abs(pos[[0,2]]-expected_xz))))
        close(pos[[0,2]],expected_xz);close(pos,row[6:9]);close(row[11],np.linalg.norm((pos-goal)[[0,2]]))
        distance=float(np.linalg.norm((pos-previous)[[0,2]]));horizontal.append(distance);close(distance,abs(forward))
        moved=bool(forward or dyaw)
        if moved:
            moving+=1;mid=(previous+pos)*.5;mid[1]=plane_height(mid[0],mid[2],previous_yaw+dyaw*.5,plane,width,depth)
            segment=float(np.linalg.norm(mid-previous)+np.linalg.norm(pos-mid));assert segment<=.025000001
            max_plane=max(max_plane,abs(float(pos[1])-plane_height(pos[0],pos[2],yaw,plane,width,depth)))
        else:close(pos,previous,0);segment=0.
        three_d.append(segment);previous=pos.copy();previous_yaw=yaw
    # Conservative all-yaw circle-AABB outside original western exclusion.
    rad=math.hypot(width/2,depth/2);xy=t[:,[2,4]]*np.array([1.,-1.]);lo=xy-rad;hi=xy+rad
    assert not np.any((lo[:,0]<=-3)&(hi[:,1]>=1)&(lo[:,1]<=3.5))
    assert max_association<=1e-9 and max_plane<=1e-9
    close(sum(horizontal),r['actualDistanceMetres']);close(sum(abs(t[:,9])),r['attemptedDistanceMetres']);close(sum(three_d),r['actual3DDistanceMetres'])
    close(t[-1,2:5],r['finalPosition'],0);close(t[-1,5],r['finalYawRadians'],0)
    terminal=r['terminal'];cue=terminal['cue'];applied=terminal['appliedCommand'];error3d=float(np.linalg.norm(t[-1,2:5]-goal))
    assert cue['goalReached'] and cue['reason']=='deliveredPoseGoalStop' and cue['forwardMetres']==cue['yawRadians']==0
    assert terminal['pendingMotion']is False and applied['forward_metres']==applied['yaw_radians']==0 and applied['reaction_delay_ticks']==0
    assert t[-1,9]==t[-1,10]==0 and applied['applied_tick']==applied['issued_tick']==len(t)-1
    assert cue['phoneFlagReceipt']['sampledFit'] and cue['phoneFlagReceipt']['referenceInputUsed']is False
    assert error3d<=.35 and t[-1,11]<=.34 and r['actualDistanceMetres']>0
    close(error3d,terminal['actualFull3DGoalErrorMetres']);close(t[-1,11],r['goalErrorMetres']);close(cue['goalError'],r['goalErrorMetres'])
    assert r['actualDistanceMetres']>=np.linalg.norm((np.asarray(r['settledStart'])-goal)[[0,2]])-.35
    assert r['ticksWithSampledLowUnresolvedExposure']==int((t[:,14]>0).sum()) and r['ticksWithoutCurrentFlagReceipt']==int((t[:,14]<0).sum())
    for k in ('actualBody','horizontalMargin'):assert r['initialContacts'][k]['contact']is False
    assert len(q)==2+4*moving
    native_calls=0;candidate_reports=0;exact_tests=0;positive_fallbacks=0
    for i,row in enumerate(q):
        assert row['index']==i and row['completed'] and row['exceptionType']is None and row['tiledFailureDetails']is None
        assert row['prepassContact']is False and row['returnedContact']is False and row['fallbackUsed']is False
        assert row['prepassBoxQueryDelta']==row['actualBoxQueryCounterDelta']==1 and row['fallbackBoxQueryDelta']==0
        assert row['fallbackExactTriangleTests']==0 and row['actualExactTriangleCounterDelta']==row['prepassExactTriangleTests']==row['returnedPassExactTriangleTests']
        assert row['nativeBoundsCallsTotal']==row['tiledQuery']['tileQueries'] and row['fallbackNativeBoundsCalls']==0
        assert re.fullmatch('[0-9a-f]{64}',row['sortedCandidateIDsSHA256'])
        tiled=row['tiledQuery'];assert tiled['uniqueOriginalIDs']<=tiled['resourceCaps']['uniqueIDs'] and tiled['rawReturnedIDs']<=tiled['resourceCaps']['rawIDs'] and tiled['tileQueries']<=tiled['resourceCaps']['tiles']
        native_calls+=row['nativeBoundsCallsTotal'];candidate_reports+=tiled['uniqueOriginalIDs'];exact_tests+=row['actualExactTriangleCounterDelta'];positive_fallbacks+=row['fallbackUsed']
    # Check none of the reviewed source identities changed during arithmetic.
    for p,h in sources.items():assert sha(WS/p)==h,p
    receipt={'status':'PASS','scope':'Independent saved-result/trace/query-receipt arithmetic; no geometry or native execution; no re-evaluation of contact truth',
      'scriptSHA256':sha(__file__),'inputPins':{str(p.relative_to(WS)):sha(p)for p in (result_path,trace_path,query_path,run_path,frozen_path,prior_path,original_path,plan_path)},
      'sourceFilesRehashedBeforeAndAfter':len(sources),'sourcePins':sources,'largeDatasetAndBinaryPinsNotRehashedHere':True,
      'arrival':True,'ticks':len(t),'movingTicksIncludingYawOnly':moving,'actualDistanceMetres':sum(horizontal),'actual3DDistanceMetres':sum(three_d),'bodyContactEvents':0,'marginContactEvents':0,
      'originalTaskGoalHorizontalErrorMetres':float(t[-1,11]),'originalTaskGoalFull3DErrorMetres':error3d,'finalActualStopAndDrainedFIFO':True,
      'maxAbsoluteHorizontalPoseCommandAssociationErrorMetres':max_association,'maxActorPlaneHeightAssociationErrorMetres':max_plane,'maxHorizontalCommandMetres':float(np.max(abs(t[:,9]))),'maxYawCommandRadians':float(np.max(abs(t[:,10]))),'maxReconstructedHalfSegmentSum3DMetres':max(three_d),
      'initialYawReconstructedFromTraceRadians':initial_yaw,'initialYawIndependentlyReprojectedFromSourceMetadata':False,
      'exactStage14ActorPlanePreserved':True,'originalNineGroundSeedIDsPreserved':True,'expandedGroundCandidateCount':g['candidateCells'],'groundClassificationCap':g['candidateCap'],'expandedBroadFitSeparateFromActiveActorPlane':True,
      'queryRows':len(q),'actualTiledNativeBoundsCalls':native_calls,'candidateReportsNotUniqueTriangles':candidate_reports,'exactTrianglePredicateTests':exact_tests,'positiveFallbacks':positive_fallbacks,
      'groundContactsUnmeasuredNotZero':True,'ticksWithSampledLowUnresolvedExposure':int((t[:,14]>0).sum()),'sampledRSSBytes':run['peakSampledOrWaitedTreeRSSBytes'],
      'limitations':['One nominal 45 cm zero-margin body on a partial offline provided-map leg, not a whole-room traversal or live sensing','Reference cleaned/completed geometry and finite nine-ray support are not continuous measured clearance','No independent reference rescore; saved negative query assertions and exact source identities recounted','No new loop or 100-run result'],
      'wallSeconds':time.monotonic()-began,'peakOwnRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024}
    with (HERE/'RECEIPT.json').open('x')as f:json.dump(receipt,f,indent=2,allow_nan=False);f.write('\n')
    print(json.dumps({k:receipt[k]for k in ('status','ticks','actualDistanceMetres','actual3DDistanceMetres','queryRows','actualTiledNativeBoundsCalls','wallSeconds')}))
if __name__=='__main__':main()
