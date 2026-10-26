"""20 routes x 5 conditions on a FROZEN phone-only map, scored by the published v3 connected-ground world model.

Reused unchanged from master 7506ad9 (research/tools/koivu-split-candidate-game-v1/blind-split-candidate-game-03):
  OrientedReferenceContainer (actual 0.45x0.30x1.60 m oriented body AND separate 0.15 m horizontal-margin
  enclosure, 2 mm floor exclusion), GroundSupport + GroundedReferenceContainer (seeded connected low-slope ground,
  one robust support plane for actor height, ground triangles accounted separately, every other triangle stays an
  obstacle), support_check / contact_status / connected_support / plane_support_height / proposed_ground_motion,
  score_reference.transform, impairments.ActorFIFO/SensorFIFO, and the condition table of run_game.profiles.
New: in-process Python controller (game100.Controller; Detour on the frozen phone mask, disc 0.375) because the
Swift SurfaceGameWorker cannot be built here; the five impairment conditions; the 20x5 loop and the tally.
Planner/controller never receive reference geometry, contacts or support. First contact (body or margin) ends a
run. No repositioning, no route replacement.

usage: game_v3.py <run_dir> <map_npz> <routes_dir(with ROUTES.json)> <recast_dir> <icp.json> <gt_mesh.ply>
"""
import sys,os,json,math,time
from collections import Counter
from dataclasses import asdict
import numpy as np
HERE=os.path.dirname(os.path.abspath(__file__))
W='$SCRATCH/split3/research/tools/koivu-split-candidate-game-v1'
B=W+'/blind-split-candidate-game-03'
# priority order: v3 ground model first (v2 has older files with the same names)
sys.path[:0]=[B+'/ground-follow-v3',B+'/source',W+'/blind-opus-reference-scoring-audit-02/source',W+'/blind-koivu-reference-comparison-06',W+'/blind-authored-navigation-pilot/source',HERE,B+'/ground-follow-v2']
import vtk
from reference_geometry import ReferenceSurface
from score_reference import transform
from oriented_container import OrientedReferenceContainer
from ground_support import GroundSupport
from oriented_ground_container import GroundedReferenceContainer
from fast_container import FastGroundedContainer
EQUIV={'checked':0,'max':40}
from run_ground_pilot import connected_support,plane_support_height,proposed_ground_motion
from run_pilot import support_check,contact_status
from impairments import ActorFIFO,ActorCommand,SensorFIFO
from game100 import Map,Controller,profiles,CONDITIONS,P,DISC,sha

SETUP={}
def episode(route,cond,M,base):
    ap,sp=profiles(route,cond)
    L2G=lambda xy,h=0.:np.array([xy[0],h,-xy[1]])
    start=L2G(route['start']);goal=L2G(route['goal']);yaw=-float(route['initialYawRadians'])
    res=dict(runID=f"route-{route['routeID']:02d}-{cond}",routeID=route['routeID'],condition=cond,arrival=False,motionExecuted=False,actualBodyContactEvents=0,marginContactEvents=0,
             nearFootAmbiguousContactEvents=0,actualDistanceMetres=0.,ticks=0,actorProfile=asdict(ap),poseProfile=asdict(sp),physicalAuthority=False)
    key=route['routeID']
    if key not in SETUP:   # route-level world setup: depends only on start, frozen path and seeds, never on condition
        init=base.support_probes(start,yaw);ic=support_check(init)
        if not ic['acceptedFiniteSupportModel']:SETUP[key]=('invalidStartReferenceSupport',ic)
        else:
            pts=np.vstack((start,np.array([L2G(p) for p in route['initialPath']]),goal))
            seeds=[int(p['referenceCellID']) for p in init['probes']];sp_pts=[[p['modelXZ'][0],p['modelHeightY'],p['modelXZ'][1]] for p in init['probes']]
            tg=time.time()
            try:
                ground=GroundSupport.from_scorer(base,pts,seeds,sp_pts)
                SETUP[key]=('ok',(init,ground,(FastGroundedContainer(base.surface,base.transform,ground=ground,body=base.body),GroundedReferenceContainer(base.surface,base.transform,ground=ground,body=base.body)),round(time.time()-tg,1)))
            except (ValueError,RuntimeError) as e:SETUP[key]=('invalidStartGroundComponent',str(e)[:200])
            print(json.dumps({'phase':'ground_ready','route':key,'seconds':round(time.time()-tg,1),'state':SETUP[key][0]}),flush=True)
    kind,val=SETUP[key]
    if kind!='ok':res.update(status=kind,reason=val if isinstance(val,str) else None,initialSupportCheck=val if isinstance(val,dict) else None);return res
    init,ground,(scorer,slow),res['groundSetupSeconds']=val
    eq_left=[5] if cond=='baseline' else [0]
    start[1]=plane_support_height(init,ground);state=start.copy()
    if not connected_support(init,ground,float(start[1]))['acceptedFiniteSupportModel']:res.update(status='invalidStartPlaneSupportAssociation');return res
    c0=scorer.swept_contacts(start,start,yaw,0.);s0=contact_status(c0)
    if s0:res.update(status='invalidStart:'+s0,actualBodyContactEvents=int(c0['actualBody']['contact']),marginContactEvents=int(c0['horizontalMargin']['contact']));return res
    ctl=Controller(M,route['goal']);actor=ActorFIFO(ap);poses=SensorFIFO(sp);cnt=Counter()
    dist=0.;stationary=0;status='timeout';straight=float(np.linalg.norm((start-goal)[[0,2]]))
    for tick in range(P['ticks']):
        now=100+tick/P['hz']
        poses.submit(tick,{'tick':tick,'receivedAt':now,'command':'continue','pose':{'position':[float(state[0]),float(-state[2])],'yaw':-yaw,'capturedAt':now}})
        dl=poses.release(tick,now);delivered=dl[-1].packet['pose'] if dl else None
        fwd,turn_level,reason,src=ctl.tick(tick,now,delivered);cnt['reason:'+reason]+=1
        applied=actor.step(tick,ActorCommand(fwd,-turn_level,tick,src,reason))
        proposed=state.copy();pyaw=yaw+applied.yaw_radians
        proposed[[0,2]]+=[math.cos(pyaw)*applied.forward_metres,math.sin(pyaw)*applied.forward_metres]
        moved=abs(applied.forward_metres)>0 or abs(applied.yaw_radians)>0
        pending=any(c.forward_metres or c.yaw_radians for _,c in actor.pending)
        if moved:
            seg,support,motion=proposed_ground_motion(scorer,ground,state,proposed,yaw,applied.yaw_radians)
            if seg is None:status='unknownReferenceSupportDuringMotion' if motion is None else 'groundFollowMovementCap'
            else:
                mid,proposed=seg
                for a,b,ay,d in ((state,mid,yaw,applied.yaw_radians*.5),(mid,proposed,yaw+applied.yaw_radians*.5,applied.yaw_radians*.5)):
                    c=scorer.swept_contacts(a,b,ay,d);f=contact_status(c)
                    if eq_left[0]>0:   # built-in equivalence guard against the original slow scorer
                        cs=slow.swept_contacts(a,b,ay,d);eq_left[0]-=1;EQUIV['checked']+=1
                        for k in ('actualBody','horizontalMargin'):
                            if bool(cs[k]['contact'])!=bool(c[k]['contact']) or cs[k].get('firstReferenceCellID')!=c[k].get('firstReferenceCellID'):raise SystemExit('FAST/SLOW SCORER MISMATCH '+k)
                    if f:
                        status=f;res['actualBodyContactEvents']=int(c['actualBody']['contact']);res['marginContactEvents']=int(c['horizontalMargin']['contact'])
                        res['nearFootAmbiguousContactEvents']=int(f=='firstContactTriangleNearFootAmbiguous')
                        hit=c['actualBody'] if c['actualBody']['contact'] else c['horizontalMargin']
                        res['firstContact']={k:hit.get(k) for k in ('reason','firstReferenceCellID','firstTriangleHeightRelativeToStartFootRange')};break
                if status=='timeout':state=proposed;yaw=pyaw;dist+=abs(applied.forward_metres);res['motionExecuted']=True;cnt['motionTicks']+=1
        else:state=proposed;yaw=pyaw
        err=float(np.linalg.norm((state-goal)[[0,2]]))
        if reason=='goalReachedByDeliveredPose' and not moved and not pending and err<=P['goalTol'] and dist>0 and dist>=max(0,straight-P['goalTol']):status='arrivalReferenceModelOnly';res['arrival']=True
        stationary=0 if moved else stationary+1
        if stationary>=P['deadlock'] and not pending and not res['arrival']:status='stoppedNoMotion:'+reason
        if tick%150==0:print(json.dumps({'phase':'tick','run':res['runID'],'tick':tick,'dist':round(dist,3),'err':round(err,3)}),flush=True)
        if status!='timeout':break
    res.update(status=status,ticks=tick+1,actualDistanceMetres=round(dist,3),goalErrorMetres=round(err,3),routeLengthMetres=route['pathLengthMetres'],counts=dict(cnt))
    return res

def main():
    run,mapname,rdir,recast,icp,ply=sys.argv[1:7];t0=time.time()
    F=json.load(open(os.path.join(rdir,'ROUTES.json')));M=Map(run,mapname,recast)
    if M.sha!=F['mapSHA256']:raise SystemExit('map changed after route freeze')
    o=np.load(os.path.join(run,'pipeline2_out.npz'));A=np.array(json.load(open(icp))['gt_transformation'])
    rd=vtk.vtkPLYReader();rd.SetFileName(ply);rd.Update();surf=ReferenceSurface(rd.GetOutput())
    base=OrientedReferenceContainer(surf,transform({'R':o['R'],'t':o['t']},A));print('reference ready',round(time.time()-t0,1),'s',flush=True)
    results=[];sub=os.environ.get('ROUTE_SUBSET')
    keep=set(range(int(sub.split('-')[0]),int(sub.split('-')[1])+1)) if sub else None
    for route in F['routes']:
        if keep is not None and route['routeID'] not in keep:continue
        for cond in CONDITIONS:
            if route['status']!='selectedPhoneOnly':results.append(dict(runID=f"route-{route['routeID']:02d}-{cond}",routeID=route['routeID'],condition=cond,status='routeUnavailable',arrival=False));continue
            r=episode(route,cond,M,base);results.append(r)
            print(json.dumps({k:r.get(k) for k in ('runID','status','ticks','actualDistanceMetres','goalErrorMetres')}),flush=True)
    key=lambda s:s.split(':')[0] if not s.startswith('invalidStart') else 'invalidStart'
    summ=Counter(key(r['status']) for r in results)
    out=dict(mapSHA256=F['mapSHA256'],routesSHA256=sha(os.path.join(rdir,'ROUTES.json')),params=P,disc=DISC,worldModel='master 7506ad9 v3 connected-ground world; contact via decision-equivalent fast path (fast_container.py) with in-run equivalence guard',equivalenceChecks=EQUIV['checked'],
             controller='Python in-process substitute for Swift SurfaceGameWorker; Detour on frozen phone mask; never sees reference',
             summary=dict(summ),byCondition={c:dict(Counter(key(r['status']) for r in results if r['condition']==c)) for c in CONDITIONS},
             arrivals=sum(r['arrival'] for r in results),bodyContacts=sum(r.get('actualBodyContactEvents',0) for r in results),marginContacts=sum(r.get('marginContactEvents',0) for r in results),
             wallSeconds=round(time.time()-t0,1),results=results)
    json.dump(out,open(os.path.join(rdir,'GAME_RESULTS'+(('_part_'+sub) if sub else '')+'.json'),'w'),indent=1)
    print('SUMMARY',json.dumps({k:out[k] for k in ('summary','arrivals','bodyContacts','marginContacts','wallSeconds')}))
if __name__=='__main__':main()
