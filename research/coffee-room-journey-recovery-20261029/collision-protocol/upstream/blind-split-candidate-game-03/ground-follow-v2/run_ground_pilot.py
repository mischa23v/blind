"""Same frozen phone-only route, additive connected-ground simulator correction.

Reference physics chooses only vertical support, never XZ, yaw, route or goal.
No changes to the frozen first episode, phone map, margin, controller or body.
"""
from pathlib import Path
import json,math,sys,time
from dataclasses import asdict
import numpy as np
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;WS=ROOT.parent
sys.path.insert(0,str(ROOT/'source'))
from run_pilot import (ControllerProcess,support_check,contact_status,load_surface,
    transform,serial_vtk,ActorFIFO,ActorProfile,ActorCommand,sha,dump)
from oriented_container import OrientedReferenceContainer
from ground_support import GroundSupport
from oriented_ground_container import GroundedReferenceContainer

def verify(expected):
    path=HERE/'FROZEN.json'
    if sha(path)!=expected:raise ValueError('manifest changed')
    for p,h in json.loads(path.read_text())['files'].items():
        if sha(WS/p)!=h:raise ValueError('pinned source/input changed: '+p)

def connected_support(row,ground,previous_y):
    result=support_check(row,previous_y)
    not_ground=[int(p['referenceCellID']) for p in row['probes']
                if p['hit'] and not ground.is_ground(int(p['referenceCellID']))]
    result.update(groundComponentConfirmedForAllProbes=not not_ground and result['hitCount']==9,
                  nonGroundProbeCellIDs=not_ground,
                  supportPolicy='nine first-hit probes on initially seeded shared-edge <=5 degree component')
    result['acceptedFiniteSupportModel']=bool(result['acceptedFiniteSupportModel'] and not not_ground)
    return result

def proposed_ground_motion(scorer,ground,state,proposed,yaw,dyaw):
    """Two short straight physical segments, each with finite connected support.

    Mid/end Y follow actual reference support; XZ and yaw are unchanged from the
    independent actor. Missing/disconnected support is rejected, not repaired.
    """
    midpoint=(state+proposed)*.5
    midrow=scorer.support_probes(midpoint,yaw+dyaw*.5)
    midcheck=connected_support(midrow,ground,float(state[1]))
    if not midcheck['acceptedFiniteSupportModel']:
        return None,[midcheck],None
    midpoint[1]=midcheck['heightMaximum']
    endrow=scorer.support_probes(proposed,yaw+dyaw)
    endcheck=connected_support(endrow,ground,float(midpoint[1]))
    if not endcheck['acceptedFiniteSupportModel']:
        return None,[midcheck,endcheck],None
    proposed=proposed.copy();proposed[1]=endcheck['heightMaximum']
    length=float(np.linalg.norm(midpoint-state)+np.linalg.norm(proposed-midpoint))
    if length>.025000001:
        return None,[midcheck,endcheck],{'reason':'3D movement cap including ground following','attempted3DDistanceMetres':length}
    return (midpoint,proposed),[midcheck,endcheck],{'attempted3DDistanceMetres':length}

def episode(route,base,out):
    start=np.array(route['start'],float);goal=np.array(route['goal'],float);yaw=float(route['initialYawRadians'])
    nominal=start.copy();initial_support=base.support_probes(start,yaw);initial_check=support_check(initial_support)
    result={'scope':'Same permissive offline phone-map route with connected-ground reference physics; not live clearance',
        'condition':'baseline','physicalAuthority':False,'gameEpisodesScheduled':1,'arrival':False,'motionExecuted':False,
        'actualDistanceMetres':0.,'actual3DDistanceMetres':0.,'attemptedDistanceMetres':0.,
        'actualBodyContactEvents':0,'marginContactEvents':0,'nearFootAmbiguousContactEvents':0,
        'ticksWithGroundContact':0,'groundTriangleContactReports':0,
        'initialReferenceSupport':initial_support,'initialSupportCheck':initial_check,
        'nominalStart':nominal.tolist(),'goal':goal.tolist(),
        'sourceConfidence':'unavailable and not synthesized','trackingState':'unavailable and not synthesized',
        'farOnlyDipConflict':'unassessed in supplied masks','strictStatClearFeasibility':'external logs report no 2–6m routes; unchanged failure retained',
        'preservedFirstAttempt':'pilot-01; 0.1753554739 m then margin-only smooth-ground clipping',
        'groundSemantics':'only original shared-edge <=5 degree component seeded from all nine initial support IDs; no disconnected top or step relabelling',
        'continuousSupportProven':False,'semanticGroundTruthEstablished':False}
    if not initial_check['acceptedFiniteSupportModel']:
        result.update(status='invalidStartReferenceSupport',goalErrorMetres=float(np.linalg.norm((start-goal)[[0,2]])),ticks=0);return result
    route_points=np.vstack((start,np.asarray(route['nativeInitialRoute']['points'],float),goal))
    seeds=[int(p['referenceCellID'])for p in initial_support['probes']]
    try:ground=GroundSupport.from_scorer(base,route_points,seeds)
    except (ValueError,RuntimeError)as e:
        result.update(status='invalidStartGroundComponent',reason=str(e),ticks=0,goalErrorMetres=float(np.linalg.norm((start-goal)[[0,2]])));return result
    result['groundComponent']=ground.receipt
    scorer=GroundedReferenceContainer(base.surface,base.transform,ground=ground,body=base.body)
    start[1]=initial_check['heightMaximum'];state=start.copy()
    result['settledStart']=start.tolist();result['referenceFootAnchorCorrectionMetres']=float(start[1]-nominal[1])
    result['footAnchorPolicy']='world-only connected-ground maximum of finite 9-probe support, updated at each half-step; no horizontal correction'
    contacts=scorer.swept_contacts(start,start,yaw,0.);result['initialContacts']=contacts;status=contact_status(contacts)
    if status:
        result.update(status='invalidStart:'+status,actualBodyContactEvents=int(contacts['actualBody']['contact']),marginContactEvents=int(contacts['horizontalMargin']['contact']),nearFootAmbiguousContactEvents=int(status=='firstContactTriangleNearFootAmbiguous'),goalErrorMetres=float(np.linalg.norm((state-goal)[[0,2]])),ticks=0);return result
    controller=ControllerProcess(out);actor=ActorFIFO(ActorProfile());trace=[]
    distance=0.;distance3d=0.;attempted=0.;stationary=0;last={};status='timeout'
    pose_revision=controller.initial['mapRevision'];flagged_ticks=0;missing_flag_ticks=0
    try:
        controller.ask({'command':'beginRun','goal':goal.tolist()})
        for tick in range(1200):
            now=100+tick/15
            pose={'kind':'simulated-physics-body-pose','position':state.tolist(),'yaw':yaw,'capturedAt':now,'mapRevision':pose_revision}
            cue=controller.ask({'command':'tick','tick':tick,'now':now,'deliveredPose':pose})
            current_flags=cue.get('phoneFlagReceipt',{}).get('lowUnresolvedCells',-1)
            proposed_flags=cue.get('proposedPhoneFlagReceipt',{}).get('lowUnresolvedCells',-1)
            flagged_ticks+=current_flags>0;missing_flag_ticks+=current_flags<0
            command=ActorCommand(cue['forwardMetres'],cue['yawRadians'],tick,cue['sourceCapturedAt'],cue['reason'])
            applied=actor.step(tick,command);proposed=state.copy();proposed_yaw=yaw+applied.yaw_radians
            proposed[[0,2]]+=[math.cos(proposed_yaw)*applied.forward_metres,math.sin(proposed_yaw)*applied.forward_metres]
            if np.linalg.norm(proposed-state)>.025000001 or abs(applied.yaw_radians)>math.radians(1)+1e-10:raise RuntimeError('actor cap')
            moved=abs(applied.forward_metres)>0 or abs(applied.yaw_radians)>0;attempted+=abs(applied.forward_metres)
            pending=any(c.forward_metres or c.yaw_radians for _,c in actor.pending)
            contacts=[];support=None;motion=None;actual_contact=False;margin_contact=False;ground_reports=0
            if moved:
                segment,support,motion=proposed_ground_motion(scorer,ground,state,proposed,yaw,applied.yaw_radians)
                if segment is None:status='unknownReferenceSupportDuringMotion' if motion is None else 'groundFollowMovementCap'
                else:
                    midpoint,proposed=segment
                    for a,b,ay,d in ((state,midpoint,yaw,applied.yaw_radians*.5),(midpoint,proposed,yaw+applied.yaw_radians*.5,applied.yaw_radians*.5)):
                        contact=scorer.swept_contacts(a,b,ay,d);contacts.append(contact)
                        ground_reports+=sum(int(contact[k].get('groundContactCount',0))for k in ('actualBody','horizontalMargin'))
                        failure=contact_status(contact)
                        if failure:
                            status=failure;actual_contact=bool(contact['actualBody']['contact']);margin_contact=bool(contact['horizontalMargin']['contact'])
                            result['actualBodyContactEvents']+=int(actual_contact);result['marginContactEvents']+=int(margin_contact)
                            result['nearFootAmbiguousContactEvents']+=int(failure=='firstContactTriangleNearFootAmbiguous');break
                    if status=='timeout':
                        state=proposed;yaw=proposed_yaw;distance+=abs(applied.forward_metres);distance3d+=motion['attempted3DDistanceMetres'];result['motionExecuted']=True
            result['ticksWithGroundContact']+=int(ground_reports>0);result['groundTriangleContactReports']+=ground_reports
            error=float(np.linalg.norm((state-goal)[[0,2]]))
            arrival=bool(cue['goalReached']and not moved and not pending and error<=.35 and distance>0 and distance>=max(0,float(np.linalg.norm((start-goal)[[0,2]]))-.35))
            if arrival:status='arrivalReferenceModelOnly';result['arrival']=True
            stationary=0 if moved else stationary+1
            if stationary>=150 and not pending and not arrival:status='deadlockNoMotion'
            trace.append([tick,now,*state,yaw,*proposed,applied.forward_metres,applied.yaw_radians,error,int(actual_contact),int(margin_contact),current_flags,proposed_flags,ground_reports])
            last={'cue':cue,'appliedCommand':asdict(applied),'contacts':contacts,'support':support,'motion':motion,'pendingMotion':pending,'actualGoalErrorMetres':error}
            if tick%60==0:print(json.dumps({'phase':'actor_tick','tick':tick,'distance':distance,'goalError':error,'status':status}),flush=True)
            if status!='timeout':break
    finally:controller.close()
    np.savez_compressed(out/'ACTOR_TRACE.npz',trace=np.asarray(trace),columns=np.asarray(['tick','time','x','y','z','yaw','proposedX','proposedY','proposedZ','forward','yawDelta','goalError','actualBodyContact','marginContact','currentLowUnresolvedCells','proposedLowUnresolvedCells','groundTriangleContactReports']))
    result.update(status=status,ticks=tick+1,actualDistanceMetres=distance,actual3DDistanceMetres=distance3d,attemptedDistanceMetres=attempted,goalErrorMetres=last['actualGoalErrorMetres'],finalPosition=state.tolist(),finalYawRadians=yaw,terminal=last,traceSHA256=sha(out/'ACTOR_TRACE.npz'),nominalSpeedMetresPerSecond=.30,maximumSpeedMetresPerSecond=.375,warningBurden='not measured: no live sensor/hazard stream in offline game',ticksWithSampledLowUnresolvedExposure=flagged_ticks,ticksWithoutCurrentFlagReceipt=missing_flag_ticks,traceMissingFlagSentinel=-1)
    return result

def main(expected):
    verify(expected);runtime=serial_vtk();out=HERE/'run-01/result';out.mkdir(exist_ok=False);began=time.monotonic()
    route=json.loads((ROOT/'FIRST_ROUTE.json').read_text())
    if route.get('selected')is not True:raise ValueError('no frozen phone route')
    surface,mesh_info,reader=load_surface()
    with np.load(ROOT/'inputs/koivu_5cm_v2_pipeline2_out.npz',allow_pickle=False)as m:a={'R':m['R'],'t':m['t']}
    A=np.asarray(json.loads((WS/'blind-koivu-faro-acquisition-04/selected-reference/icp_iphone.json').read_text())['gt_transformation'])
    scorer=OrientedReferenceContainer(surface,transform(a,A));result=episode(route,scorer,out)
    result.update(runtime=runtime,referenceMesh=mesh_info,wallSeconds=time.monotonic()-began,FAROUsedByController=False,referencePhysicsNeverSelectsRoute=True,firstNonGroundContactTerminates=True,routeSHA256=sha(ROOT/'FIRST_ROUTE.json'))
    verify(expected);dump(out/'RESULT.json',result);print(json.dumps({'phase':'terminal','status':result['status'],'arrival':result['arrival'],'distance':result.get('actualDistanceMetres',0),'ticks':result.get('ticks',0),'actualBodyContacts':result.get('actualBodyContactEvents',0),'marginContacts':result.get('marginContactEvents',0)}),flush=True)
if __name__=='__main__':main(sys.argv[1])
