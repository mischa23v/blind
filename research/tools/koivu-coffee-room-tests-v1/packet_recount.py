"""Read-only saved-evidence recount. No map/native/reference geometry execution.
Run `python packet_recount.py` from the packet; prints JSON, writes no files.
"""
from pathlib import Path
import hashlib,json,math
import numpy as np
ROOT=Path(__file__).resolve().parent
def load(p): return json.loads((ROOT/p).read_text())
def close(a,b): assert math.isclose(float(a),float(b),abs_tol=1e-9,rel_tol=0),(a,b)
def main():
    checks={}
    for folder,queries,legs in [('blind-remaining-room-traverse-23',99,1),('blind-small-room-entry-return-24',96,0)]:
        top=load(folder+'/planning-01/result/RESULTS.json');total=0
        assert not top['referenceInputsUsed'] and not top['movementExecuted'] and top['oneEpisodeSelected'] is None
        for row in top['results']:
            path=folder+'/planning-01/result/'+row['artifact'];b=(ROOT/path).read_bytes();assert hashlib.sha256(b).hexdigest()==row['sha256']
            r=json.loads(b);assert r['completedPlannedLegs']==row['completedPlannedLegs']==legs
            attempts=sum(len(x['attempts'])for x in r['legs']);assert attempts==r['nativeQueries']==row['nativeQueries'];total+=attempts
            assert sum(x['status']=='fixedPhoneModelLegAccepted' for leg in r['legs'] for x in leg['attempts'])==legs
            assert all(not x['movementExecuted'] and not x['physicalAuthority'] for leg in r['legs'] for x in leg['attempts'])
        assert total==queries
        checks[folder]={'nativeQueries':total,'admittedLegsPerProfile':legs,'fullItineraryCompleted':False,'movementExecuted':False}
    coffee='blind-coffee-room-traverse-24/run-01/result/'
    top=load(coffee+'RESULTS.json');assert top['movementEpisodesExecuted']==0 and not top['referenceGeometryLoaded'] and not top['referenceArraysRead']
    counts={};expected={'body45cmMargin0':16,'body45cmMargin5cm':14,'abstract28cmProfile':18}
    for name,count in expected.items():
        r=load(coffee+name+'.json');routes=r['routes'];assert len(routes)==42
        assert {(x['startEndpointID'],x['goalEndpointID'])for x in routes}=={(a,b)for a in range(7)for b in range(7)if a!=b}
        accepted=[x for x in routes if x['status']=='fixedPhoneModelLegAccepted'];assert len(accepted)==r['summary']['accepted']==count
        assert sum(x['nativeAndOriginalRectangleResult']['reason']=='incomplete' for x in routes)==24
        lengths=[]
        for x in accepted:
            p=np.asarray(x['planarFootprintValidationPath'],float)
            length=float(np.linalg.norm(np.diff(p[:,[0,2]],axis=0),axis=1).sum());lengths.append(length)
            close(length,x['openPathCheck']['horizontalLengthMetres'])
            assert x['sampledFootprintDiagnostic']['lowUnresolvedSampledCells']>0
        close(max(lengths),r['summary']['acceptedLengthMetresMinMax'][1]);counts[name]={'accepted':count,'queries':42,'longestAcceptedMetres':max(lengths),'nativeIncomplete':24}
    checks['coffee']=counts
    base='blind-remaining-room-partial-executor-25/'
    r=load(base+'run-01/result/RESULT.json');q=load(base+'run-01/result/QUERY_OPTIMIZATION.json');run=load(base+'run-01/RUN_RECEIPT.json')
    with np.load(ROOT/base/'run-01/result/ACTOR_TRACE.npz',allow_pickle=False)as z:t=z['trace'];columns=z['columns'].tolist()
    assert t.shape==(139,17) and r['ticks']==139 and np.isfinite(t).all()
    assert columns[2:5]==['x','y','z'] and columns[9:11]==['forward','yawDelta'] and columns[14]=='currentLowUnresolvedCells'
    assert r['arrival'] and r['status']=='arrivalReferenceModelOnly' and not r['physicalAuthority']
    assert [r['geometry'][k]for k in ['width','depth','height','margin']]==[.45,.3,1.6,0.]
    p=np.asarray(r['settledStart']);distance=0.;yaw=float(t[0,5]-t[0,10])
    for row in t:
        yaw+=float(row[10]);np.testing.assert_allclose(row[[2,4]],p[[0,2]]+row[9]*np.array([math.cos(yaw),math.sin(yaw)]),rtol=0,atol=1e-9)
        distance+=float(np.linalg.norm(row[[2,4]]-p[[0,2]]));p=row[2:5].copy()
    close(distance,2.76);close(distance,r['actualDistanceMetres'])
    unresolved=int((t[:,14]>0).sum());assert unresolved==r['ticksWithSampledLowUnresolvedExposure']==125
    assert np.all(t[:,12:14]==0)and r['actualBodyContactEvents']==r['marginContactEvents']==0
    assert r['ticksWithGroundContact'] is None and r['groundTriangleContactReports'] is None
    err=float(np.linalg.norm(p-np.asarray(r['originalTaskGoal'])));assert err<=.35 and t[-1,11]<=.34
    assert not r['terminal']['pendingMotion']and t[-1,9]==t[-1,10]==0 and r['terminal']['cue']['goalReached']
    assert len(q)==554 and sum(x['nativeBoundsCallsTotal']for x in q)==34902
    assert all(x['completed']and not x['returnedContact']and not x['fallbackUsed']for x in q)
    assert run['success']and run['exitCode']==0 and run['peakSampledOrWaitedTreeRSSBytes']<=run['budgets']['RSSBytes']
    checks['partialEpisode']={'arrival':True,'actualDistanceMetres':distance,'ticks':139,'unresolvedLowTicks':unresolved,'bodyContactEvents':0,'marginContactEvents':0,'groundContactsUnmeasured':True,'full3DGoalErrorMetres':err,'queryRows':len(q),'nativeBoundsCalls':34902,'finalStopAndDrainedFIFO':True}
    print(json.dumps({'status':'PASS','scope':'Independent saved JSON/NPZ arithmetic only; no reference rescore, map load, native route query, or source execution','checks':checks},indent=2,sort_keys=True))
if __name__=='__main__':main()
