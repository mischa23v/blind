"""Offline model adapter over real Recast and actual Swift NavigationSurface.

No reference mesh, native confidence/tracking, physical lease, raycaster or new
search algorithm. Exporting declared eligible square cells as two triangles is
only an interchange adapter for the existing native planner.
"""
import hashlib,json,math,os,selectors,subprocess,sys
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'blind-authored-navigation-pilot/native'))
from detour_engine import Engine,Config

MODE='offline-known-phone-map-game-v1'
HALF_EXTENT=math.hypot(.45,.30)/2
BODY_RADIUS=math.sqrt(2)*HALF_EXTENT
HEIGHT=1.6
MARGIN=.15


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def point(p):return dict(zip(('x','y','z'),map(float,p)))


def surface_triangles(surface):
    width,depth=surface['width'],surface['depth'];r=float(surface['resolution'])
    if r!=.1:raise ValueError('frozen model requires10cm surface cells')
    if width*depth!=len(surface['cells']) or width*depth>250000:raise ValueError('surface size')
    origin=surface['origin'];vertices=[];triangles=[];eligible=[]
    for index,c in enumerate(surface['cells']):
        if c.get('floor') is None or c.get('clearance') is None or c['blocked'] or c['clearance']<HEIGHT+MARGIN:continue
        if c['floor']!=0 or c.get('floorUncertainty') is not None:raise ValueError('not declared level unknown-error model')
        x=origin['x']+(index%width)*r;z=origin['z']+(index//width)*r
        base=len(vertices)
        vertices.extend(((x,0,z),(x,0,z+r),(x+r,0,z+r),(x+r,0,z)))
        triangles.extend(((base,base+1,base+2),(base,base+2,base+3)))
        eligible.append(index)
    if len(vertices)>250000 or len(triangles)>500000:raise ValueError('native bounded mesh cap')
    return np.asarray(vertices,np.float32).reshape(-1,3),np.asarray(triangles,np.int32).reshape(-1,3),eligible


class SurfaceClient:
    def __init__(self,surface):
        env=os.environ.copy();env['LD_LIBRARY_PATH']=str(HERE.parent/'blind-navigation-recorded/build-06')
        self.stderr=sys.stderr
        self.process=subprocess.Popen([str(HERE/'build/surface-worker')],stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,stderr=self.stderr,text=True,bufsize=1,env=env)
        self.selector=selectors.DefaultSelector();self.selector.register(self.process.stdout,selectors.EVENT_READ)
        try:self.ask({'command':'initialize','surface':surface,'body':{'radius':BODY_RADIUS,'height':HEIGHT,'margin':MARGIN}})
        except Exception:self.close();raise
    def ask(self,request):
        self.process.stdin.write(json.dumps({'mode':MODE,**request},separators=(',',':'),allow_nan=False)+'\n');self.process.stdin.flush()
        if not self.selector.select(timeout=10):raise RuntimeError('native surface worker timeout')
        line=self.process.stdout.readline()
        if not line:raise RuntimeError('native surface worker ended')
        row=json.loads(line)
        if row['physicalAuthority'] or row['physicalOwnerHasLocalizationEvidence'] or row['physicalOwnerHasCurrentPose']:
            raise RuntimeError('offline model unexpectedly has physical authority')
        return row
    def permits(self,legs):
        return self.ask({'command':'validateLegs','legs':[{'from':point(a),'to':point(b)} for a,b in legs]})['permits']
    def close(self):
        if not self.process.stdin.closed:self.process.stdin.close()
        if self.process.poll() is None:
            try:self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:self.process.kill();self.process.wait()
        self.selector.close()
        self.process.stdout.close()


class PhoneModel:
    def __init__(self,path,expected_sha):
        raw=Path(path).read_bytes()
        if hashlib.sha256(raw).hexdigest()!=expected_sha:raise ValueError('phone model hash mismatch')
        self.path=Path(path);self.revision=expected_sha;self.surface=json.loads(raw)
        self.native=SurfaceClient(self.surface);self.engine=None;self.build_error=None
        try:self.vertices,self.triangles,self.eligible=surface_triangles(self.surface)
        except Exception:self.native.close();raise
        try:
            self.engine=Engine(self.vertices,self.triangles,
                Config(radius=BODY_RADIUS+MARGIN,height=HEIGHT+MARGIN,max_climb=0),mode='known-provided-map')
        except ValueError as e:self.build_error=str(e)
    def route(self,start,goal):
        if self.engine is None:return {'complete':False,'reason':'noNativeWalkableMap','error':self.build_error,'points':[]}
        result=self.engine.route(start,goal)
        pa=np.asarray(result.projected_start);pb=np.asarray(result.projected_goal)
        if (not result.complete or len(result.points)<2 or not np.isfinite(pa).all() or not np.isfinite(pb).all()
            or np.linalg.norm((pa-np.asarray(start))[[0,2]])>.1
            or np.linalg.norm((pb-np.asarray(goal))[[0,2]])>.1
            or abs(pa[1])>.05 or abs(pb[1])>.05):
            return {'complete':False,'reason':'noAssociatedCompleteRoute','error':result.error,
                    'projectedStart':result.projected_start if np.isfinite(pa).all() else None,
                    'projectedGoal':result.projected_goal if np.isfinite(pb).all() else None,'points':[]}
        # The declared level model is Y=0. Recast's raster-height offset is not a
        # new measured floor or actor relocation. Only XZ corners are imported,
        # within the fixed ±two-cell-height association above; raw Ys are logged.
        if not np.isfinite(np.asarray(result.points)).all() or any(abs(p[1])>.05 for p in result.points):
            return {'complete':False,'reason':'navmeshHeightUnassociated','points':[]}
        points=[(float(p[0]),0.,float(p[2])) for p in result.points[1:]]
        return {'complete':True,'reason':'nativeCandidateOnly','points':points,
                'rawPoints':result.points,'projectedStart':result.projected_start,'projectedGoal':result.projected_goal,
                'status':result.status,'error':result.error}
    def close(self):
        if self.engine:self.engine.close()
        self.native.close()


def follow_candidate(position,yaw,points):
    """Same bounded point-follower arithmetic as the prior simulator actuator.

    It consumes native candidate corners, not a hand-authored route. The body
    pose here is the delivered simulated pose; this function never moves truth.
    """
    p=np.asarray(position,dtype=float)
    target=next((np.asarray(q) for q in points if np.linalg.norm((np.asarray(q)-p)[[0,2]])>.01),None)
    if target is None:return 0.,0.,'noDistinctCandidatePoint'
    delta=target-p;target_yaw=math.atan2(delta[2],delta[0])
    error=math.atan2(math.sin(target_yaw-yaw),math.cos(target_yaw-yaw))
    turn=max(-math.radians(1),min(math.radians(1),error))
    distance=min(.02,float(np.linalg.norm(delta[[0,2]]))) if abs(error)<=math.radians(5) else 0.
    return distance,turn,'boundedNativeCandidate'
