"""20 routes x 5 conditions movement game on a FROZEN phone-only map, reference-scored.

Reused unchanged: research/tools/koivu-offline-game-v1/impairments.py (pose FIFO with delay/jitter/drop; actor FIFO
with reaction delay, translation scale, forced wrong-turn pulses), the condition table of run_game.profiles
(copied verbatim below), reference_container.py (VTK triangle contact of a yaw-independent 0.54 m square,
height 1.6 m, 2 mm floor exclusion; support rays) and the pinned Recast/Detour adapter.
New here (because the Swift SurfaceGameWorker cannot be built in this container): a Python controller that
plans on the frozen phone mask with Detour (disc = lateral half-width 0.225 + margin 0.15) and follows the
corridor with the same point-follower arithmetic as game_model.follow_candidate; replans from the DELIVERED
pose every 15 ticks or when > 0.15 m off the corridor; stops when the delivered pose is stale (> 0.5 s), when no
route exists, or when the delivered pose is within the goal tolerance.
Planner/controller never see the reference. Routes are frozen (ROUTES.json with map hash) before any reference
query. No repositioning, no route replacement after failure.

usage: game100.py select <run_dir> <map_npz> <out_dir> <recast_dir>
       game100.py run    <run_dir> <map_npz> <out_dir> <recast_dir> <icp.json> <gt_mesh.ply>
"""
import sys,os,json,math,hashlib,time
from collections import Counter
from dataclasses import asdict
import numpy as np
from scipy import ndimage
HERE=os.path.dirname(os.path.abspath(__file__))
GAME='/home/user/blind/research/tools/koivu-offline-game-v1'
REFCMP='/home/user/blind/research/koivu-reference-comparison/workspaces/blind-koivu-reference-comparison-06'
sys.path.insert(0,GAME);sys.path.insert(0,REFCMP);sys.path.insert(0,HERE)
from impairments import ActorFIFO,ActorProfile,ActorCommand,SensorFIFO,SensorProfile
RES=.05;LAT=.225;MARGIN=.15;DISC=LAT+MARGIN;FORE=.15
P=dict(hz=15,ticks=1200,step=.02,maxYawDeg=1.,alignDeg=5.,goalTol=.35,inset=.01,poseMaxAge=.5,replanTicks=15,offCorridor=.15,deadlock=150,
       seed=271828,lattice=.25,sep=(2.,6.),routes=20,maxEndpointUse=2)

def sha(p):return hashlib.sha256(open(p,'rb').read()).hexdigest()

def profiles(route,condition):   # verbatim semantics of run_game.profiles
    scale=(.8,1.25)[route['routeID']%2] if condition in ('motion-scale','combined') else 1.
    delay=3 if condition in ('delay','combined') else 0
    wrong=condition in ('wrong-turn','combined')
    actor=ActorProfile(reaction_delay_ticks=delay,translation_scale=scale,
        wrong_turn_start_tick=75 if wrong else None,wrong_turn_end_tick_exclusive=80 if wrong else None,
        wrong_turn_yaw_radians=math.radians((-1,1)[route['seed']%2]))
    sensor=SensorProfile(seed=route['seed'],delay_ticks=delay,
        jitter_ticks=2 if condition=='combined' else 0,drop_probability=.05 if condition=='combined' else 0.)
    return actor,sensor
CONDITIONS=('baseline','delay','motion-scale','wrong-turn','combined')

class Map:
    def __init__(self,run,mapname,recast):
        sys.path.insert(0,recast);from detour_engine import Engine,Config;from routes import quads
        o=np.load(os.path.join(run,'pipeline2_out.npz'));self.R=o['R'];self.t=o['t'];self.lo=o['lo']
        self.path=os.path.join(run,mapname);self.sha=sha(self.path);self.walk=np.load(self.path)['walk']
        self.origin=(self.lo[0]*RES,self.lo[1]*RES);V,T=quads(self.walk,self.origin,RES)
        self.engine=Engine(V,T,Config(radius=DISC,height=1.75,cell_size=.05,max_climb=0.),mode='known-provided-map')
    def route(self,a,b):
        r=self.engine.route((a[0],0.,a[1]),(b[0],0.,b[1]));pa=np.array(r.projected_start);pb=np.array(r.projected_goal)
        ok=r.complete and np.isfinite(pa).all() and np.hypot(*(pa[[0,2]]-a))<=.1 and np.hypot(*(pb[[0,2]]-b))<=.1
        return ([(p[0],p[2]) for p in r.points] if ok else None)

def select(run,mapname,out,recast):
    import routes_rect as RR
    os.makedirs(out,exist_ok=True);M=Map(run,mapname,recast);w=M.walk;lo=M.lo
    np.savez('policyD.npz',lo=lo)   # routes_rect reads lo from here
    d=ndimage.distance_transform_edt(w)*RES-RES*math.sqrt(2)/2
    step=int(round(P['lattice']/RES));cand=[]
    for i in range(0,w.shape[0],step):
        for j in range(0,w.shape[1],step):
            if d[i,j]>=DISC:
                c=((i+lo[0]+.5)*RES,(j+lo[1]+.5)*RES)
                if any(RR.rect_ok(w,M.origin,c[0],c[1],math.radians(k*5)) for k in range(72)):cand.append(c)
    rng=np.random.default_rng(P['seed']);pairs=[(a,b) for a in range(len(cand)) for b in range(len(cand)) if a!=b and P['sep'][0]<=math.dist(cand[a],cand[b])<=P['sep'][1]]
    order=rng.permutation(len(pairs));use=Counter();routes=[];tested=0
    for k in order:
        a,b=pairs[k]
        if use[a]>=P['maxEndpointUse'] or use[b]>=P['maxEndpointUse']:continue
        tested+=1;pts=M.route(cand[a],cand[b])
        if pts is None:continue
        Pth=[(cand[a][0],0.,cand[a][1])]+[(p[0],0.,p[1]) for p in pts[1:]]
        if RR.sweep_ok(w,M.origin,Pth)!='ok':continue
        seg=np.subtract(pts[1],pts[0]) if len(pts)>1 else np.subtract(cand[b],cand[a])
        rid=len(routes);routes.append(dict(routeID=rid,seed=P['seed']+rid,start=list(cand[a]),goal=list(cand[b]),straightDistanceMetres=math.dist(cand[a],cand[b]),
            initialYawRadians=math.atan2(seg[1],seg[0]),initialPath=[list(p) for p in pts],pathLengthMetres=float(np.sum(np.linalg.norm(np.diff(np.asarray(pts),axis=0),axis=1))),status='selectedPhoneOnly'))
        use[a]+=1;use[b]+=1
        if len(routes)==P['routes']:break
    while len(routes)<P['routes']:routes.append(dict(routeID=len(routes),seed=P['seed']+len(routes),status='insufficientPhoneMapPairs'))
    frozen=dict(map=os.path.basename(M.path),mapSHA256=M.sha,params=P,disc=DISC,latticeCandidates=len(cand),pairsInRange=len(pairs),pairsTested=tested,
                selectionRule='phone map only: 0.5 m lattice centres with disc 0.375 and rectangle fit at some heading; pairs 2-6 m; shuffled with seed; Detour complete AND swept-rectangle check (0.45x0.30 + 0.15 margin) on the phone map; each endpoint used at most twice',routes=routes,referenceQueried=False)
    json.dump(frozen,open(os.path.join(out,'ROUTES.json'),'w'),indent=1)
    print(json.dumps({k:frozen[k] for k in ('latticeCandidates','pairsInRange','pairsTested')}),'selected',sum(r['status']=='selectedPhoneOnly' for r in routes))

class Controller:
    def __init__(self,M,goal):self.M=M;self.goal=np.asarray(goal);self.pose=None;self.path=None;self.last_plan=-999
    def tick(self,tick,now,delivered):
        if delivered is not None:self.pose=delivered
        if self.pose is None:return 0.,0.,'noPose',None
        age=now-self.pose['capturedAt']
        if age>P['poseMaxAge']:return 0.,0.,'stalePose',self.pose['capturedAt']
        p=np.asarray(self.pose['position']);yaw=self.pose['yaw']
        if np.linalg.norm(p-self.goal)<=P['goalTol']-P['inset']:return 0.,0.,'goalReachedByDeliveredPose',self.pose['capturedAt']
        off=None
        if self.path is not None:
            Q=np.asarray(self.path);seg=[np.linalg.norm(np.cross(np.r_[b-a,0],np.r_[a-p,0]))/max(np.linalg.norm(b-a),1e-9) if np.dot(p-a,b-a)>=0 and np.dot(p-b,a-b)>=0 else min(np.linalg.norm(p-a),np.linalg.norm(p-b)) for a,b in zip(Q[:-1],Q[1:])]
            off=min(seg) if seg else np.linalg.norm(p-Q[0])
        if self.path is None or tick-self.last_plan>=P['replanTicks'] or (off is not None and off>P['offCorridor']):
            pts=self.M.route(p,self.goal);self.last_plan=tick
            if pts is None:self.path=None;return 0.,0.,'noPhoneMapRouteFromDeliveredPose',self.pose['capturedAt']
            self.path=[p.tolist()]+[list(q) for q in pts[1:]]
        # path[0] is the planning position (kept only for the off-corridor test); targets are the corridor corners after it,
        # as in game_model.follow_candidate (which follows result.points[1:]). Fix of attempt-5 bug that steered back to path[0].
        target=next((np.asarray(q) for q in self.path[1:] if np.linalg.norm(np.asarray(q)-p)>.01),None)
        if target is None:return 0.,0.,'noDistinctCandidatePoint',self.pose['capturedAt']
        dv=target-p;err=math.atan2(math.sin(math.atan2(dv[1],dv[0])-yaw),math.cos(math.atan2(dv[1],dv[0])-yaw))
        turn=max(-math.radians(P['maxYawDeg']),min(math.radians(P['maxYawDeg']),err))
        fwd=min(P['step'],float(np.linalg.norm(dv))) if abs(err)<=math.radians(P['alignDeg']) else 0.
        return fwd,turn,'following',self.pose['capturedAt']

def run(run_dir,mapname,out,recast,icp,ply):
    import vtk
    from reference_geometry import ReferenceSurface
    from reference_container import ReferenceContainer
    F=json.load(open(os.path.join(out,'ROUTES.json')));M=Map(run_dir,mapname,recast)
    if M.sha!=F['mapSHA256']:raise SystemExit('map changed after route freeze')
    A=np.array(json.load(open(icp))['gt_transformation'])
    Pfl=np.eye(4);Pfl[:3,:3]=M.R.T;Pfl[:3,3]=-M.R.T@M.t
    Lfg=np.eye(4);Lfg[:3,:3]=[[1,0,0],[0,0,-1],[0,1,0]]
    G2R=A@Pfl@Lfg
    rd=vtk.vtkPLYReader();rd.SetFileName(ply);rd.Update();mesh=rd.GetOutput()
    t0=time.time();surf=ReferenceSurface(mesh);print('reference locator built',round(time.time()-t0,1),'s',flush=True)
    scorer=ReferenceContainer(surf,G2R)
    g=lambda xy:np.array([xy[0],0.,-xy[1]])
    results=[]
    for route in F['routes']:
        for cond in CONDITIONS:
            rid=f"route-{route['routeID']:02d}-{cond}";res=dict(runID=rid,routeID=route['routeID'],condition=cond,arrival=False,contactEvents=0,motionExecuted=False,physicalAuthority=False)
            if route['status']!='selectedPhoneOnly':res.update(status='routeUnavailable');results.append(res);continue
            ap,sp=profiles(route,cond);res['actorProfile']=asdict(ap);res['poseProfile']=asdict(sp)
            st=np.asarray(route['start'],float);goal=np.asarray(route['goal'],float);yaw=route['initialYawRadians']
            sup=scorer.swept_support(g(st),g(st));con=scorer.swept_contact(g(st),g(st))
            if con['contact'] or not sup['sampledSupportKnown']:
                res.update(status='invalidStartReferenceOverlap' if con['contact'] else 'invalidStartReferenceSupport',initialContact=con,initialSupport={k:v for k,v in sup.items() if k!='heights'});results.append(res);continue
            ctl=Controller(M,goal);actor=ActorFIFO(ap);poses=SensorFIFO(sp);cnt=Counter();travel=0.;stationary=0;status='timeout';minclear=None
            for tick in range(P['ticks']):
                now=100+tick/P['hz']
                poses.submit(tick,{'tick':tick,'receivedAt':now,'command':'continue','pose':{'position':st.tolist(),'yaw':yaw,'capturedAt':now}})
                dl=poses.release(tick,now);delivered=dl[-1].packet['pose'] if dl else None
                fwd,turn,reason,src=ctl.tick(tick,now,delivered);cnt['reason:'+reason]+=1
                applied=actor.step(tick,ActorCommand(fwd,turn,tick,src,reason))
                ny=yaw+applied.yaw_radians;prop=st+applied.forward_metres*np.array([math.cos(ny),math.sin(ny)])
                moved=abs(applied.forward_metres)>0 or abs(applied.yaw_radians)>0
                pending=any(c.forward_metres!=0 or c.yaw_radians!=0 for _,c in actor.pending)
                if moved and abs(applied.forward_metres)>0:
                    con=scorer.swept_contact(g(st),g(prop));sup=scorer.swept_support(g(st),g(prop))
                    if con['contact']:status='referenceContactDuringMotion';res['contactEvents']=1;res['firstContact']=con;break
                    if not sup['sampledSupportKnown']:status='unknownReferenceSupportDuringMotion';break
                    travel+=abs(applied.forward_metres);cnt['motionTicks']+=1
                st=prop;yaw=ny
                err=float(np.linalg.norm(st-goal))
                if reason=='goalReachedByDeliveredPose' and not moved and not pending and err<=P['goalTol'] and travel>=max(0,route['straightDistanceMetres']-P['goalTol']):status='cleanArrival';break
                stationary=0 if moved else stationary+1
                if stationary>=P['deadlock'] and not pending:status='stoppedNoMotion:'+reason;break
            res.update(status=status,arrival=status=='cleanArrival',motionExecuted=cnt['motionTicks']>0,ticks=tick+1,travelMetres=round(travel,3),
                       finalGoalErrorMetres=round(float(np.linalg.norm(st-goal)),3),counts=dict(cnt),routeLengthMetres=route['pathLengthMetres'])
            results.append(res);print(json.dumps({k:res[k] for k in ('runID','status','ticks','travelMetres','finalGoalErrorMetres')}),flush=True)
    summ=Counter(r['status'].split(':')[0] for r in results)
    out_j=dict(mapSHA256=F['mapSHA256'],params=P,disc=DISC,reference='author-registered FARO (evaluator only); yaw-independent 0.54 m square container, 1.6 m, 2 mm floor exclusion',
               controller='Python substitute for the Swift SurfaceGameWorker (not buildable here); Detour on frozen phone mask',summary=dict(summ),
               byCondition={c:dict(Counter(r['status'].split(':')[0] for r in results if r['condition']==c)) for c in CONDITIONS},results=results)
    json.dump(out_j,open(os.path.join(out,'GAME_RESULTS.json'),'w'),indent=1);print('SUMMARY',json.dumps(dict(summ)))
if __name__=='__main__':
    mode=sys.argv[1]
    if mode=='select':select(*sys.argv[2:6])
    else:run(*sys.argv[2:8])
