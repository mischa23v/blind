#!/usr/bin/env python3
"""One bounded, preregistered 20×5 offline phone-map game evaluation.

The controller is a separate stdin process and never receives reference geometry
or scoring. Reference prevention terminates failure; it is not planner help.
"""
import argparse,json,math,os,selectors,subprocess,sys,time
from collections import Counter
from dataclasses import asdict
from pathlib import Path
import numpy as np
import vtk

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'blind-authored-navigation-pilot/source'))
from impairments import ActorFIFO,ActorProfile,ActorCommand,SensorFIFO,SensorProfile
from reference_container import ReferenceContainer
from reference_geometry import ReferenceSurface,serial_vtk
from game_model import sha

CONDITIONS=('baseline','delay','motion-scale','wrong-turn','combined')
TRACE_COLUMNS=['tick','time','bodyX','bodyY','bodyZ','bodyYaw','proposedX','proposedY','proposedZ',
               'issuedForward','issuedYaw','appliedForward','appliedYaw','poseAge','goalError',
               'referenceContact','referenceSampledSupport','pendingMotion']


def profiles(route,condition):
    scale=(.8,1.25)[route['routeID']%2] if condition in ('motion-scale','combined') else 1.
    delay=3 if condition in ('delay','combined') else 0
    wrong=condition in ('wrong-turn','combined')
    actor=ActorProfile(reaction_delay_ticks=delay,translation_scale=scale,
        wrong_turn_start_tick=75 if wrong else None,wrong_turn_end_tick_exclusive=80 if wrong else None,
        wrong_turn_yaw_radians=math.radians((-1,1)[route['seed']%2]))
    sensor=SensorProfile(seed=route['seed'],delay_ticks=delay,
        jitter_ticks=2 if condition=='combined' else 0,drop_probability=.05 if condition=='combined' else 0.)
    return actor,sensor


class ControllerProcess:
    def __init__(self,surface,expected,output):
        self.err=open(output/'controller.stderr.log','x')
        self.p=subprocess.Popen([sys.executable,str(HERE/'game_controller.py')],stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,stderr=self.err,text=True,bufsize=1)
        self.selector=selectors.DefaultSelector();self.selector.register(self.p.stdout,selectors.EVENT_READ)
        try:self.initial=self.ask({'command':'initialize','surfacePath':str(surface),'surfaceSHA256':expected})
        except Exception:self.close();raise
    def ask(self,p):
        self.p.stdin.write(json.dumps(p,separators=(',',':'),allow_nan=False)+'\n');self.p.stdin.flush()
        if not self.selector.select(timeout=15):raise RuntimeError('offline controller timeout')
        line=self.p.stdout.readline()
        if not line:raise RuntimeError('offline controller terminated')
        row=json.loads(line)
        if row.get('physicalAuthority') is not False:raise RuntimeError('physical authority boundary')
        return row
    def close(self):
        if not self.p.stdin.closed:self.p.stdin.close()
        if self.p.poll() is None:
            try:self.p.wait(timeout=5)
            except subprocess.TimeoutExpired:self.p.kill();self.p.wait()
        self.selector.close();self.p.stdout.close();self.err.close()


def episode(route,condition,controller,scorer,map_revision,output):
    run_id=f"route-{route['routeID']:02d}-{condition}"
    actor_profile,pose_profile=profiles(route,condition)
    result={'runID':run_id,'routeID':route['routeID'],'condition':condition,'seed':route['seed'],
            'actorProfile':asdict(actor_profile),'simulatedPoseDeliveryProfile':asdict(pose_profile),
            'scheduled':True,'motionExecuted':False,'arrival':False,'cleanArrival':False,
            'contactEvents':0,'motionContactEvents':0,'initialContainerOverlap':False,
            'actualDistanceMetres':0.,'attemptedDistanceMetres':0.,'ticks':0,
            'physicalAuthority':False,'referenceClassification':'surface-relative; not established physical obstacle truth'}
    if route['status']!='selectedPhoneOnly':
        result['status']='routeUnavailable';result['reason']=route['status'];return result
    result['initialPhoneRouteComplete']=route['nativeInitialRoute']['complete']
    state=np.asarray(route['start'],dtype=float);goal=np.asarray(route['goal'],dtype=float);yaw=route['initialYawRadians']
    support=scorer.swept_support(state,state);contact=scorer.swept_contact(state,state)
    result['initialReferenceSupport']=support;result['initialReferenceContact']=contact
    result['initialContainerOverlap']=contact['contact'];result['contactEvents']=int(contact['contact'])
    result['goalErrorMetres']=float(np.linalg.norm((state-goal)[[0,2]]))
    if not support['sampledSupportKnown'] or contact['contact']:
        result['status']='invalidStartSupportAndOverlap' if contact['contact'] and not support['sampledSupportKnown'] else (
            'invalidStartReferenceOverlap' if contact['contact'] else 'invalidStartReferenceSupport')
        result['reason']='no truth-based repositioning; floor registration/unknown support or container overlap unresolved'
        return result
    if not route['nativeInitialRoute']['complete']:
        result['status']='noPhoneMapRoute';result['reason']=route['nativeInitialRoute']['reason'];return result
    controller.ask({'command':'beginRun','runID':run_id,'goal':goal.tolist()})
    actor=ActorFIFO(actor_profile);poses=SensorFIFO(pose_profile)
    trace=[];counts=Counter();travel=0.;attempted=0.;stationary=0;status='timeout';last={};pending=False
    for tick in range(1200):
        now=100+tick/15
        capture={'kind':'simulated-kinematic-body-pose','runID':run_id,'tick':tick,'capturedAt':now,
                 'position':state.tolist(),'yaw':yaw,'mapRevision':map_revision}
        disposition=poses.submit(tick,{'tick':tick,'receivedAt':now,'command':'continue','pose':capture})
        deliveries=poses.release(tick,now)
        counts['posePacketsDropped']+=disposition.dropped;counts['ticksWithoutPoseDelivery']+=not deliveries
        counts['posePacketsReleased']+=len(deliveries)
        counts['posePacketsDeliveredToController']+=bool(deliveries)
        counts['posePacketsCoalescedBeforeController']+=max(0,len(deliveries)-1)
        delivered=deliveries[-1].packet['pose'] if deliveries else None
        row=controller.ask({'command':'physicsTick','runID':run_id,'tick':tick,'now':now,'deliveredPose':delivered})
        counts['stopReason:'+row['reason']]+=1
        command=ActorCommand(row['forwardMetres'],row['yawRadians'],tick,row['sourceCapturedAt'],row['reason'])
        applied=actor.step(tick,command)
        proposed=state.copy();proposed_yaw=yaw+applied.yaw_radians
        proposed[[0,2]]+=[math.cos(proposed_yaw)*applied.forward_metres,math.sin(proposed_yaw)*applied.forward_metres]
        moved=abs(applied.forward_metres)>0 or abs(applied.yaw_radians)>0
        if np.linalg.norm(proposed-state)>.025000001 or abs(applied.yaw_radians)>math.radians(1)+1e-10:
            raise RuntimeError('actuator increment cap')
        attempted+=abs(applied.forward_metres)
        counts['motionAfterIssuedStopTicks']+=moved and command.forward_metres==0 and command.yaw_radians==0
        counts['wrongTurnPulseTicks']+=applied.forced_wrong_turn
        counts['staleAppliedCommandTicks']+=bool(moved and applied.source_captured_at is not None and now-applied.source_captured_at>.5)
        pending=any(c.forward_metres!=0 or c.yaw_radians!=0 for _,c in actor.pending)
        contact=scorer.swept_contact(state,proposed) if moved else {'contact':False,'notQueried':'noAppliedMotion'}
        support=scorer.swept_support(state,proposed) if moved else {'sampledSupportKnown':True,'notQueried':'unchangedInitiallyCheckedFootprint'}
        if contact['contact']:
            status='referenceContactDuringMotion';result['contactEvents']+=1;result['motionContactEvents']+=1
        elif not support['sampledSupportKnown']:status='unknownReferenceSupportDuringMotion'
        else:
            state=proposed;yaw=proposed_yaw;travel+=abs(applied.forward_metres)
            counts['appliedMotionTicks']+=moved
        error=float(np.linalg.norm((state-goal)[[0,2]]))
        arrived=bool(row['goalReachedByDeliveredPose'] and not moved and not pending and error<=.35
                     and travel>=max(0,route['straightDistanceMetres']-.35))
        if arrived:status='cleanArrival'
        stationary=0 if moved else stationary+1
        if stationary>=150 and not pending and not arrived:status='deadlockNoMotion'
        trace.append([tick,now,*state,yaw,*proposed,command.forward_metres,command.yaw_radians,
                      applied.forward_metres,applied.yaw_radians,row.get('poseAgeSeconds',math.nan),error,
                      int(contact['contact']),int(support['sampledSupportKnown']),int(pending)])
        last={'controller':row,'appliedCommand':asdict(applied),'pendingNonzeroCommands':pending,
              'referenceContact':contact,'referenceSupport':support,'trueGoalErrorMetres':error}
        if status!='timeout':break
    result.update(status=status,motionExecuted=counts['appliedMotionTicks']>0,arrival=status=='cleanArrival',
        cleanArrival=status=='cleanArrival',actualDistanceMetres=travel,attemptedDistanceMetres=attempted,
        ticks=tick+1,goalErrorMetres=last['trueGoalErrorMetres'],counts=dict(counts),terminal=last,
        finalPosition=state.tolist(),finalYawRadians=yaw)
    path=output/(run_id+'.npz')
    np.savez_compressed(path,columns=np.asarray(TRACE_COLUMNS),trace=np.asarray(trace,dtype=np.float64))
    result['trace']={'path':path.name,'sha256':sha(path),'rows':len(trace)}
    return result


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--mode',choices=['game'],required=True)
    parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=False)
    config=json.loads((HERE/'GAME_INPUTS.json').read_text())
    for name in ('surface','map','routes'):
        if sha(config[name]['path'])!=config[name]['sha256']:raise ValueError(name+' changed after freeze')
    routes=json.loads(Path(config['routes']['path']).read_text())
    if (len(routes['routeSlots'])!=20 or routes['surfaceSHA256']!=config['surface']['sha256']
        or [r['routeID'] for r in routes['routeSlots']]!=list(range(20))
        or any(r['seed']!=271828+r['routeID'] for r in routes['routeSlots'])):
        raise ValueError('route ownership/identity')
    runtime=serial_vtk();start=time.monotonic();results=[];controller=None;scorer=None
    try:
        if any(r['status']=='selectedPhoneOnly' for r in routes['routeSlots']):
            print(json.dumps({'phase':'referenceMeshLoadStart'}),flush=True)
            reader=vtk.vtkPLYReader();errors=[];reader.AddObserver('ErrorEvent',lambda *_:errors.append('VTK PLY read error'))
            reader.SetFileName(config['referenceMesh']['path']);reader.Update();mesh=reader.GetOutput()
            if errors:raise RuntimeError(';'.join(errors))
            surface=ReferenceSurface(mesh,progress=lambda row:print(json.dumps(row),flush=True))
            with np.load(config['map']['path']) as mapping:app_to_phone=mapping['appToPhone'].copy()
            author=np.asarray(json.loads(Path(config['referenceAlignment']['path']).read_text())['gt_transformation'])
            scorer=ReferenceContainer(surface,author@app_to_phone)
            controller=ControllerProcess(config['surface']['path'],config['surface']['sha256'],args.output)
        for route in routes['routeSlots']:
            for condition in CONDITIONS:
                result=episode(route,condition,controller,scorer,config['surface']['sha256'],args.output)
                (args.output/(result['runID']+'.json')).write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
                results.append(result)
                print(json.dumps({'completedSchedules':len(results),'runID':result['runID'],'status':result['status'],
                                  'contactEvents':result['contactEvents'],'actualDistanceMetres':result['actualDistanceMetres']}),flush=True)
    finally:
        if controller:controller.close()
    counts=Counter(r['status'] for r in results)
    summary={'scope':'100 correlated offline known-phone-map game schedules in one real-recorded room; not live iPhone accuracy/safety',
        'scheduledRuns':100,'completedSchedules':len(results),'distinctRooms':1,'routeCount':20,'conditions':list(CONDITIONS),
        'runsWithAnyReferenceContainerOverlap':sum(r['contactEvents']>0 for r in results),
        'runsHittingDuringMotion':sum(r['motionContactEvents']>0 for r in results),
        'totalContactEvents':sum(r['contactEvents'] for r in results),
        'totalMotionContactEvents':sum(r['motionContactEvents'] for r in results),
        'initialOverlapRuns':sum(r['initialContainerOverlap'] for r in results),
        'nearFootAmbiguousContactEvents':sum(bool(r.get('initialReferenceContact',{}).get('nearFootOrFloorRegistrationAmbiguity'))
            +bool(r.get('terminal',{}).get('referenceContact',{}).get('nearFootOrFloorRegistrationAmbiguity')) for r in results),
        'motionExecutedRuns':sum(r['motionExecuted'] for r in results),'arrivals':sum(r['arrival'] for r in results),
        'cleanArrivals':sum(r['cleanArrival'] for r in results),'terminalCategories':dict(counts),
        'nominalSpeedMetresPerSecond':.30,'maximumSpeedMetresPerSecond':.375,
        'goalToleranceMetres':.35,'tickBudgetPerRun':1200,'hz':15,
        'contactCounting':'first static or swept reference-container overlap is one event and terminates run; triangle counts are not events',
        'referenceLimit':'cleaned/completed unlabeled FARO surface, not measured-support mask or physical solid truth; floor offset can invalidate setup',
        'supportLimit':'finite probes only; gaps between probes unproved; no true floor adjustment',
        'mapLimit':'processed phone model, absent original confidence/tracking/time; finite projected coverage and3cm floor-band ambiguity',
        'poseSource':'simulated kinematic body pose, delayed/impaired explicitly; no prerecorded counterfactual sensor replay',
        'FAROUsedByController':False,'physicalAuthority':False,'runtime':runtime,'wallSeconds':time.monotonic()-start,
        'sourceInputReceipt':'parent bounded runner SOURCE_DATA_PINS.json',
        'referenceSupportNativeQueries':scorer.support_native_queries if scorer else 0,
        'referenceCellIntersectionQueries':scorer.collision_native_queries if scorer else 0,
        'referenceLoaded':scorer is not None,'runs':[{'runID':r['runID'],'status':r['status'],'contactEvents':r['contactEvents'],
            'motionContactEvents':r['motionContactEvents'],'actualDistanceMetres':r['actualDistanceMetres']} for r in results]}
    (args.output/'SUMMARY.json').write_text(json.dumps(summary,indent=2,allow_nan=False)+'\n')
    print(json.dumps(summary,allow_nan=False),flush=True)

if __name__=='__main__':main()
