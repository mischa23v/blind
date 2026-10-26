"""Simulation-only pinned phone-mask adapter. No reference fields or truth geometry.

Released Detour owns search; unchanged audit functions own sampled rectangular fit.
This permissive supplied map is not verified physical clearance or live sensing.
"""
from pathlib import Path
import hashlib,importlib,math,os,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
NATIVE=ROOT.parent/'blind-authored-navigation-pilot/native'
UPSTREAM=ROOT/'upstream/scripts'
RES=.05;DISC=.375;FORE=.30;LAT=.375
SPLIT_SHA='b294d92cfd9136d00de510239c2b85a9d68d878dcf7dac1a64b144d8880cb076'
META_SHA='a2fc5c13f86bf7033131347fd9b6d61db23ab716d12d668a3d969b9e87dbf48d'
SOURCE_PINS={NATIVE/'detour_engine.py':'8ab51b8fe7ac2585cfbe797615dd9ac78956e6cb14277deb092aca19df38787d',NATIVE/'libblind_detour.so':'560567438e5c88aaa8e20d3ac92ce4db6fe8803018f537b82819b47ed7cc05b8',UPSTREAM/'routes_rect.py':'c96f1cb4e87e1f283645f4dbe7e8ee76f51b1d701ddf6a0965be4e1a1bd5c980',UPSTREAM/'routes.py':'20723183941e16968eaacfd227972448385255dc5f3ff86bc39c7de8edb1f2d8'}
PHONE_KEYS=('support','deepBelow','nearDip','low1','lowUnresolvedFlag','highObstacle','highUnknown','walk')

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def modules():
 for p,h in SOURCE_PINS.items():
  if sha(p)!=h:raise ValueError('pinned upstream/native source mismatch: '+str(p))
 os.environ['RECAST_ADAPTER_DIR']=str(NATIVE)
 sys.path.insert(0,str(NATIVE));sys.path.insert(0,str(UPSTREAM))
 rr=importlib.import_module('routes_rect');de=importlib.import_module('detour_engine');routes=importlib.import_module('routes')
 if Path(routes.__file__).resolve()!=UPSTREAM/'routes.py' or rr.quads is not routes.quads:raise ValueError('unexpected quads module source')
 if Path(rr.__file__).resolve()!=UPSTREAM/'routes_rect.py' or Path(de.__file__).resolve()!=NATIVE/'detour_engine.py':raise ValueError('unexpected module source')
 return rr,de

def source_to_game(p):
 a=np.asarray(p,float)
 if a.shape[-1]!=3 or not np.isfinite(a).all():raise ValueError('invalid coordinates')
 # Source levels are [levelX,levelY,height]. This is a proper rotation.
 return np.stack((a[...,0],a[...,2],-a[...,1]),axis=-1)
def game_to_source(p):
 a=np.asarray(p,float)
 if a.shape[-1]!=3 or not np.isfinite(a).all():raise ValueError('invalid coordinates')
 return np.stack((a[...,0],-a[...,2],a[...,1]),axis=-1)
def source_route(points):
 a=np.asarray(points,float)
 # Upstream sampled checker expects [levelX,unusedHeight,levelY].
 return np.stack((a[...,0],a[...,1],-a[...,2]),axis=-1)

class CandidateMap:
 @classmethod
 def load(cls,split_path=None,metadata_path=None):return cls(split_path,metadata_path)
 def __init__(self,split_path=None,metadata_path=None):
  self.engine=None;self.rr,self.de=modules()
  split_path=Path(split_path or ROOT/'inputs/koivu_5cm_occthres_split0.7.npz');metadata_path=Path(metadata_path or ROOT/'inputs/koivu_5cm_v2_pipeline2_out.npz')
  if sha(split_path)!=SPLIT_SHA or sha(metadata_path)!=META_SHA:raise ValueError('candidate input hash mismatch')
  with np.load(split_path,allow_pickle=False)as z:
   if set(z.files)!=set(PHONE_KEYS):raise ValueError('unexpected split-mask schema')
   self.flags={k:z[k].copy()for k in PHONE_KEYS};self.mask=self.flags['walk']
  # Explicit allowlist: never materialize ref_*, refWalk or statistical state.
  with np.load(metadata_path,allow_pickle=False)as z:
   self.lo=z['lo'].copy();self.R=z['R'].copy();self.t=z['t'].copy();res=float(z['res'])
  if res!=RES or self.lo.shape!=(3,) or self.R.shape!=(3,3) or self.t.shape!=(3,) or self.mask.shape!=(241,250):raise ValueError('metadata shape/resolution mismatch')
  if not all(v.dtype==np.bool_ and v.shape==self.mask.shape for v in self.flags.values()):raise ValueError('mask dtype/shape')
  if not np.isfinite(self.R).all() or not np.isfinite(self.t).all() or not np.allclose(self.R@self.R.T,np.eye(3),rtol=0,atol=1e-8) or abs(np.linalg.det(self.R)-1)>1e-8:raise ValueError('invalid phone-derived rigid level transform')
  self.origin=(float(self.lo[0])*RES,float(self.lo[1])*RES)
  self.revision=hashlib.sha256(('split07:'+SPLIT_SHA+':'+META_SHA+':properGameYUp-v1').encode()).hexdigest()
  for a in [self.lo,self.R,self.t,*self.flags.values()]:a.setflags(write=False)
  v,tris=self.rr.quads(self.mask,self.origin,RES)
  # The upstream quads use [levelX,0,+levelY]. Reflect z and reverse winding,
  # yielding +Y normals in proper [levelX,height,-levelY] game coordinates.
  v[:,2]*=-1;tris=tris[:,[0,2,1]].copy()
  self.engine=self.de.Engine(v,tris,self.de.Config(radius=DISC,height=1.75,cell_size=RES,max_climb=0.),mode='known-provided-map')
 def close(self):
  if self.engine is not None:self.engine.close();self.engine=None
 def __enter__(self):return self
 def __exit__(self,*_):self.close()
 def route(self,start,goal):
  if self.engine is None:raise RuntimeError('closed map')
  a=np.asarray(start,float);b=np.asarray(goal,float)
  if a.shape!=(3,) or b.shape!=(3,) or not np.isfinite(a).all() or not np.isfinite(b).all():raise ValueError('bad request coordinates')
  r=self.engine.route(a,b)
  pa=np.asarray(r.projected_start);pb=np.asarray(r.projected_goal)
  associated=bool(np.isfinite(pa).all() and np.isfinite(pb).all() and np.linalg.norm((pa-a)[[0,2]])<=.1 and np.linalg.norm((pb-b)[[0,2]])<=.1)
  reason='ok' if r.complete and associated and len(r.points)>=2 else (r.error or ('query_association'if not associated else'incomplete'))
  points=[list(p)for p in r.points[1:]]
  sampled=None
  if reason=='ok':
   sampled=self.rr.sweep_ok(self.mask,self.origin,source_route([a.tolist()]+points))
   if sampled!='ok':reason='sampled_'+sampled
  return {'complete':reason=='ok','points':points,'reason':reason,'nativeComplete':r.complete,'nativeStatus':r.status,'nativeError':r.error,'projectedStart':list(r.projected_start),'projectedGoal':list(r.projected_goal),'sampledRectangleResult':sampled,'mapRevision':self.revision,'physicalAuthority':False,'actorSnapped':False}
 def sampled_fit(self,point,yaw):
  p=np.asarray(point,float)
  if p.shape!=(3,) or not np.isfinite(p).all() or not math.isfinite(yaw):return False
  return bool(self.rr.rect_ok(self.mask,self.origin,float(p[0]),float(-p[2]),-float(yaw)))
 def flag_receipt(self,point,yaw):
  p=np.asarray(point,float)
  if p.shape!=(3,) or not np.isfinite(p).all() or not math.isfinite(yaw):return {'sampledFit':False,'reason':'invalid_pose','physicalAuthority':False}
  # Exact same sampled rectangle lattice as upstream; not a continuous-volume proof.
  th=-float(yaw);c,s=math.cos(th),math.sin(th);rb=self.rr.RB
  x=p[0]+rb[:,0]*c-rb[:,1]*s;y=-p[2]+rb[:,0]*s+rb[:,1]*c
  ii=np.floor((x-self.origin[0])/RES).astype(int);jj=np.floor((y-self.origin[1])/RES).astype(int)
  inside=(ii>=0)&(ii<self.mask.shape[0])&(jj>=0)&(jj<self.mask.shape[1]);keys=np.unique(np.column_stack((ii[inside],jj[inside])),axis=0)
  low=int(self.flags['lowUnresolvedFlag'][keys[:,0],keys[:,1]].sum()) if len(keys) else 0
  return {'sampledFit':self.sampled_fit(p,yaw),'sampleCount':len(rb),'insideSampleCount':int(inside.sum()),'uniqueMaskCells':len(keys),'lowUnresolvedCells':low,'farOnlyDipFlag':'unavailable in supplied split artifact','physicalAuthority':False,'sampleSpacingMetres':.025,'mapRevision':self.revision}
