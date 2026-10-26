"""Phone-only 20x5 trial attempts using existing Detour and bounded point follower.

This process cannot import the reference evaluator. Frozen output is scored separately.
"""
import argparse,json,math,os,sys,time
from pathlib import Path
import numpy as np
from shapely.geometry import Polygon,box
from local_support import funcs,load,dump,sha,HERE,paths

def rectangle_cells(xy,yaw,half_forward,half_lateral,origin,res,shape,pad=0):
    c,s=math.cos(yaw),math.sin(yaw);rot=np.array([[c,-s],[s,c]])
    corners=np.array([[-half_forward-pad,-half_lateral-pad],[half_forward+pad,-half_lateral-pad],
                      [half_forward+pad,half_lateral+pad],[-half_forward-pad,half_lateral+pad]])@rot.T+xy
    poly=Polygon(corners);mn=np.floor((corners.min(0)-origin)/res).astype(int);mx=np.floor((corners.max(0)-origin)/res).astype(int)
    if np.any(mn<0)or np.any(mx>=shape):return None
    cells=[]
    for i in range(mn[0],mx[0]+1):
        for j in range(mn[1],mx[1]+1):
            low=origin+np.array([i,j])*res
            if poly.intersects(box(*low,*(low+res))):cells.append((i,j))
    return np.asarray(cells,int)

def check_pose(data,xy,yaw,cfg):
    cells=rectangle_cells(xy,yaw,cfg['bodyDepthMetres']/2+cfg['horizontalMarginMetres'],cfg['bodyWidthMetres']/2+cfg['horizontalMarginMetres'],data['lo'][:2]*.05,.05,data['walk'].shape)
    if cells is None:return False,{'outsideMap':True}
    i,j=cells.T;reasons={k:int(data[k][i,j].sum())for k in ('lowObstacle','lowOrSupportUnresolved','stepEdge','occupiedBodyOrHead','unknownBodyOrHead')}
    reasons['missingSupport']=int((~data['support'][i,j]).sum());reasons['footprintCells']=len(cells)
    return bool(data['walk'][i,j].all()),reasons

def swept_map_ok(data,a,b,yaw,dyaw,cfg):
    # Conservative midpoint OBB enclosure, as the existing reference OBB adapter.
    hf=cfg['bodyDepthMetres']/2+cfg['horizontalMarginMetres'];hl=cfg['bodyWidthMetres']/2+cfg['horizontalMarginMetres']
    midyaw=yaw+dyaw/2;c,s=math.cos(midyaw),math.sin(midyaw);delta=b-a
    padding=2*math.hypot(hf,hl)*math.sin(abs(dyaw)/4)
    hf+=abs(delta@np.array([c,s]))/2;hl+=abs(delta@np.array([-s,c]))/2
    cells=rectangle_cells((a+b)/2,midyaw,hf,hl,data['lo'][:2]*.05,.05,data['walk'].shape,pad=padding)
    return cells is not None and bool(data['walk'][cells[:,0],cells[:,1]].all())

def main(ws,out):
    begun=time.monotonic();freeze=load(out/'FROZEN.json');cfg=freeze['protocol'];map_receipt=load(out/'MAP_RESULT.json')
    assert sha(out/'PHONE_MAP.npz')==map_receipt['mapSHA256']
    data=np.load(out/'PHONE_MAP.npz');native=ws/'checkpoint/tools/navigation-recast';sys.path.insert(0,str(native))
    dll_directory=os.add_dll_directory('C:/msys64/ucrt64/bin')if os.name=='nt'else None
    from detour_engine import Engine,Config
    _,branch,_=paths(ws)
    quads=funcs(branch/'scripts/routes.py',['quads'],{'np':np})['quads']
    follow=funcs(ws/'checkpoint/research/tools/koivu-offline-game-v1/game_model.py',['follow_candidate'],{'np':np,'math':math})['follow_candidate']
    engine=None;engine_error=None
    try:
        vertices,triangles=quads(data['walk'],data['lo'][:2]*.05,.05)
        if len(vertices)==0:engine_error='No phone walkable columns'
        else:
            vertices[:,2]*=-1;triangles=triangles[:,[0,2,1]].copy()
            engine=Engine(vertices,triangles,Config(radius=freeze['radiusMetres'],height=1.75,cell_size=.05,max_climb=0.),mode='known-provided-map')
    except ValueError as exc:engine_error=str(exc)
    dump(out/'TRIAL_SOURCE_FREEZE.json',dict(sourceSHA256=sha(Path(__file__)),frozenPairsSHA256=sha(out/'FROZEN.json'),mapSHA256=map_receipt['mapSHA256'],
        nativeLibrarySHA256=sha(native/'libblind_detour.so'),nativePin='9f4ce64458dfae86e1239c525ddc219c4e9e06f1',speedMultipliers=[.8,.9,1.,1.1,1.2],
        simulatedPose='Exact nominal body pose, no sensor or human-compliance claim',plannerReadsReference=False))
    rows=[];traces=[]
    for pair in freeze['pairs']:
        for repetition,speed in enumerate((.8,.9,1.,1.1,1.2)):
            trial=len(rows);xy=np.array(pair['startXY']);goal=np.array(pair['goalXY']);yaw=pair['initialYaw'];travel=0.
            result=dict(trial=trial,pair=pair['pair'],repetition=repetition,nominalSpeedMultiplier=speed,status=None,distanceMetres=0.,ticks=0,
                        startXY=xy.tolist(),goalXY=goal.tolist(),referenceScored=False,arrival=False,reason=None)
            ok,admission=check_pose(data,xy,yaw,cfg);result['startAdmission']=admission
            if not ok:result.update(status='invalid_start',reason='correctedPhoneBodyFootprintNotAdmitted')
            elif engine is None:result.update(status='stop',reason='noNativeWalkableMap')
            elif not check_pose(data,goal,yaw,cfg)[0]:result.update(status='stop',reason='goalFootprintNotAdmitted')
            else:
                try:
                    for tick in range(1200):
                        pos=np.array([xy[0],0.,-xy[1]]);target=np.array([goal[0],0.,-goal[1]])
                        r=engine.route(pos,target)
                        pa,pb=np.array(r.projected_start),np.array(r.projected_goal)
                        if not r.complete or len(r.points)<2 or not np.isfinite(pa).all() or not np.isfinite(pb).all() or np.linalg.norm(pa-pos)>.1 or np.linalg.norm(pb-target)>.1:
                            result.update(status='stop',reason='noAssociatedCompleteRoute');break
                        forward,turn,reason=follow(pos,-yaw,r.points[1:]);forward*=speed;dyaw=-turn
                        proposed=xy+forward*np.array([math.cos(yaw+dyaw),math.sin(yaw+dyaw)])
                        if not swept_map_ok(data,xy,proposed,yaw,dyaw,cfg):result.update(status='stop',reason='phoneSweptRectangleWithheld');break
                        xy=proposed;yaw+=dyaw;travel+=forward
                        cell=np.floor(xy/.05).astype(int)-data['lo'][:2];height=float(data['floorHeight'][tuple(cell)])
                        traces.append([trial,tick,*xy,height,yaw,forward,dyaw]);result['ticks']=tick+1
                        if np.linalg.norm(xy-goal)<=.1 and travel>=np.linalg.norm(np.array(pair['startXY'])-goal)-.1:
                            result.update(status='arrival',reason='phoneModelArrivalPendingReference',arrival=True);break
                    else:result.update(status='failure',reason='tickLimit')
                except (ValueError,RuntimeError)as exc:result.update(status='failure',reason=str(exc))
            result['distanceMetres']=travel;result['finalXY']=xy.tolist();rows.append(result)
    if engine:engine.close()
    counts={k:sum(r['status']==k for r in rows)for k in ('arrival','collision','stop','invalid_start','failure')}
    np.savez_compressed(out/'PLANNER_TRACES.npz',trace=np.asarray(traces,float).reshape(-1,8),columns=np.array(['trial','tick','sourceX','sourceY','footHeight','sourceYaw','forward','yawDelta']))
    report=dict(attempts=len(rows),uniqueFrozenPairs=20,repeats=5,outcomes=counts,
        motionEpisodes=sum(r['distanceMetres']>0 for r in rows),totalMovementMetres=sum(r['distanceMetres']for r in rows),
        physicalCollisionOutcome=None,physicalArrivalOutcome=None,referenceNotReadByPlanner=True,
        nativeBuildError=engine_error,rows=rows,wallSeconds=time.monotonic()-begun,
        warning='Admission and phone-model outcomes; no physical success or zero-collision claim without separate reference scoring.')
    dump(out/'ATTEMPT_RESULTS.json',report);print(json.dumps({k:v for k,v in report.items()if k!='rows'}),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--audit-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();main(a.audit_root.resolve(),a.out.resolve())
