"""One actual bounded offline A→B attempt, with independent reference physics."""
from pathlib import Path
import hashlib,json,math,os,selectors,subprocess,sys,time
from dataclasses import asdict
import numpy as np
ROOT=Path(__file__).resolve().parents[1];WS=ROOT.parent
sys.path.insert(0,str(WS/'blind-opus-reference-scoring-audit-02/source'))
from score_reference import load_surface,transform
from reference_geometry import serial_vtk
from oriented_container import OrientedReferenceContainer
sys.path.insert(0,str(WS/'blind-authored-navigation-pilot/source'))
from impairments import ActorFIFO,ActorProfile,ActorCommand

def sha(p):
    h=hashlib.sha256()
    with Path(p).open('rb')as f:
        while b:=f.read(1024**2):h.update(b)
    return h.hexdigest()
def dump(p,value):Path(p).write_text(json.dumps(value,indent=2,allow_nan=False)+'\n')
def verify(expected):
    if sha(ROOT/'FROZEN_PILOT.json')!=expected:raise ValueError('manifest changed')
    for p,h in json.loads((ROOT/'FROZEN_PILOT.json').read_text())['files'].items():
        if sha(WS/p)!=h:raise ValueError('pinned source/input changed: '+p)

class ControllerProcess:
    def __init__(self,out):
        self.err=(out/'controller.stderr.log').open('x')
        self.p=subprocess.Popen([sys.executable,str(ROOT/'source/pilot_controller.py')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.err,text=True,bufsize=1)
        self.selector=selectors.DefaultSelector();self.selector.register(self.p.stdout,selectors.EVENT_READ)
        try:self.initial=self.ask({'command':'initialize','splitPath':str(ROOT/'inputs/koivu_5cm_occthres_split0.7.npz'),'metadataPath':str(ROOT/'inputs/koivu_5cm_v2_pipeline2_out.npz')})
        except BaseException:self.close();raise
    def ask(self,row):
        self.p.stdin.write(json.dumps(row,allow_nan=False)+'\n');self.p.stdin.flush()
        if not self.selector.select(15):raise RuntimeError('controller timeout')
        line=self.p.stdout.readline()
        if not line:raise RuntimeError('controller terminated')
        result=json.loads(line)
        if result.get('physicalAuthority')is not False:raise RuntimeError('physical authority boundary')
        return result
    def close(self):
        if not self.p.stdin.closed:self.p.stdin.close()
        try:self.p.wait(timeout=3)
        except subprocess.TimeoutExpired:self.p.kill();self.p.wait()
        self.selector.close();self.p.stdout.close();self.err.close()

def support_check(row,foot=None):
    heights=[p['modelHeightY']for p in row['probes']if p['hit']]
    span=max(heights)-min(heights)if heights else None
    error=max(abs(v-(0 if foot is None else foot))for v in heights)if heights else None
    accepted=len(heights)==9 and span<=.02 and error<=(.03 if foot is None else .02)
    return {'acceptedFiniteSupportModel':bool(accepted),'hitCount':len(heights),'missingCount':9-len(heights),'spreadMetres':span,'maximumAnchorErrorMetres':error,'heightMinimum':min(heights)if heights else None,'heightMaximum':max(heights)if heights else None,'continuousSupportProven':False,'semanticFloorEstablished':False}

def contact_status(contacts):
    actual=contacts['actualBody'];margin=contacts['horizontalMargin']
    hit=actual if actual['contact']else margin
    if not hit['contact']:return None
    near=max(hit['firstTriangleHeightRelativeToStartFootRange'])<=.03
    if near:return 'firstContactTriangleNearFootAmbiguous'
    return 'referenceActualBodyContact'if actual['contact']else'referenceMarginContact'

def episode(route,scorer,out):
    start=np.array(route['start'],float);goal=np.array(route['goal'],float);yaw=float(route['initialYawRadians'])
    nominal=start.copy();initial_support=scorer.support_probes(start,yaw);initial_check=support_check(initial_support)
    result={'scope':'One permissive offline candidate-map episode; not live or physical clearance','condition':'baseline','physicalAuthority':False,'gameEpisodesScheduled':1,'arrival':False,'motionExecuted':False,'actualDistanceMetres':0.,'attemptedDistanceMetres':0.,'actualBodyContactEvents':0,'marginContactEvents':0,'nearFootAmbiguousContactEvents':0,'initialReferenceSupport':initial_support,'initialSupportCheck':initial_check,'nominalStart':nominal.tolist(),'goal':goal.tolist(),'sourceConfidence':'unavailable and not synthesized','trackingState':'unavailable and not synthesized','farOnlyDipConflict':'unassessed in supplied masks','strictStatClearFeasibility':'external logs report no 2–6m routes; unchanged failure retained'}
    if not initial_check['acceptedFiniteSupportModel']:
        result.update(status='invalidStartReferenceSupport',goalErrorMetres=float(np.linalg.norm((start-goal)[[0,2]])),ticks=0);return result
    start[1]=initial_check['heightMaximum'];state=start.copy();foot=float(start[1]);result['settledStart']=start.tolist();result['referenceFootAnchorCorrectionMetres']=foot-float(nominal[1]);result['footAnchorPolicy']='world initialization only; fixed thereafter; no horizontal relocation or planner correction'
    contacts=scorer.swept_contacts(start,start,yaw,0.);result['initialContacts']=contacts;status=contact_status(contacts)
    if status:
        result.update(status='invalidStart:'+status,actualBodyContactEvents=int(contacts['actualBody']['contact']),marginContactEvents=int(contacts['horizontalMargin']['contact']),nearFootAmbiguousContactEvents=int(status=='firstContactTriangleNearFootAmbiguous'),goalErrorMetres=float(np.linalg.norm((state-goal)[[0,2]])),ticks=0);return result
    controller=ControllerProcess(out)
    actor=ActorFIFO(ActorProfile());trace=[];distance=0.;attempted=0.;stationary=0;last={};status='timeout';pose_revision=controller.initial['mapRevision'];flagged_ticks=0;missing_flag_ticks=0
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
            contact=None;support=None
            if moved:
                contact=scorer.swept_contacts(state,proposed,yaw,applied.yaw_radians)
                midpoint=(state+proposed)*.5
                support=[support_check(scorer.support_probes(midpoint,yaw+applied.yaw_radians*.5),foot),support_check(scorer.support_probes(proposed,proposed_yaw),foot)]
                contact_failure=contact_status(contact)
                if contact_failure:
                    status=contact_failure;result['actualBodyContactEvents']+=int(contact['actualBody']['contact']);result['marginContactEvents']+=int(contact['horizontalMargin']['contact']);result['nearFootAmbiguousContactEvents']+=int(contact_failure=='firstContactTriangleNearFootAmbiguous')
                elif not all(x['acceptedFiniteSupportModel']for x in support):status='unknownReferenceSupportDuringMotion'
                else:state=proposed;yaw=proposed_yaw;distance+=abs(applied.forward_metres);result['motionExecuted']=True
            error=float(np.linalg.norm((state-goal)[[0,2]]))
            arrival=bool(cue['goalReached']and not moved and not pending and error<=.35 and distance>0 and distance>=max(0,float(np.linalg.norm((start-goal)[[0,2]]))-.35))
            if arrival:status='arrivalReferenceModelOnly';result['arrival']=True
            stationary=0 if moved else stationary+1
            if stationary>=150 and not pending and not arrival:status='deadlockNoMotion'
            trace.append([tick,now,*state,yaw,*proposed,applied.forward_metres,applied.yaw_radians,error,int(bool(contact and contact['actualBody']['contact'])),int(bool(contact and contact['horizontalMargin']['contact'])),current_flags,proposed_flags])
            last={'cue':cue,'appliedCommand':asdict(applied),'contacts':contact,'support':support,'pendingMotion':pending,'actualGoalErrorMetres':error}
            if tick%60==0:print(json.dumps({'phase':'actor_tick','tick':tick,'distance':distance,'goalError':error,'status':status}),flush=True)
            if status!='timeout':break
    finally:controller.close()
    np.savez_compressed(out/'ACTOR_TRACE.npz',trace=np.asarray(trace),columns=np.asarray(['tick','time','x','y','z','yaw','proposedX','proposedY','proposedZ','forward','yawDelta','goalError','actualBodyContact','marginContact','currentLowUnresolvedCells','proposedLowUnresolvedCells']))
    result.update(status=status,ticks=tick+1,actualDistanceMetres=distance,attemptedDistanceMetres=attempted,goalErrorMetres=last['actualGoalErrorMetres'],finalPosition=state.tolist(),finalYawRadians=yaw,terminal=last,traceSHA256=sha(out/'ACTOR_TRACE.npz'),nominalSpeedMetresPerSecond=.30,maximumSpeedMetresPerSecond=.375,warningBurden='not measured: no live sensor/hazard stream in offline game',ticksWithSampledLowUnresolvedExposure=flagged_ticks,ticksWithoutCurrentFlagReceipt=missing_flag_ticks,traceMissingFlagSentinel=-1)
    return result

def main(expected):
    verify(expected);runtime=serial_vtk();out=ROOT/'pilot-01/result';out.mkdir(exist_ok=False);began=time.monotonic()
    route=json.loads((ROOT/'FIRST_ROUTE.json').read_text())
    if route.get('selected')is not True:
        dump(out/'RESULT.json',{'status':'noPhoneMapRoute','arrival':False,'physicalAuthority':False,'gameEpisodesScheduled':1,'route':route});return
    surface,mesh_info,reader=load_surface()
    with np.load(ROOT/'inputs/koivu_5cm_v2_pipeline2_out.npz',allow_pickle=False)as m:a={'R':m['R'],'t':m['t']}
    A=np.asarray(json.loads((WS/'blind-koivu-faro-acquisition-04/selected-reference/icp_iphone.json').read_text())['gt_transformation'])
    scorer=OrientedReferenceContainer(surface,transform(a,A));result=episode(route,scorer,out)
    result.update(runtime=runtime,referenceMesh=mesh_info,wallSeconds=time.monotonic()-began,FAROUsedByController=False,referencePhysicsNeverSelectsRoute=True,firstContactTerminates=True,continuousSupportProven=False,routeSHA256=sha(ROOT/'FIRST_ROUTE.json'))
    verify(expected);dump(out/'RESULT.json',result);print(json.dumps({'phase':'terminal','status':result['status'],'arrival':result['arrival'],'distance':result.get('actualDistanceMetres',0),'ticks':result.get('ticks',0),'actualBodyContacts':result.get('actualBodyContactEvents',0),'marginContacts':result.get('marginContactEvents',0)}),flush=True)
if __name__=='__main__':main(sys.argv[1])
