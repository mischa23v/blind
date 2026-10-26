"""Orientation-aware feasibility: Recast/Detour corridor with a disc equal to the person's
lateral half-width + unchanged 0.15 m margin, then an evaluator-side swept-RECTANGLE check of
the actual path (0.45 x 0.30 person, +0.15 m margin on every side, turning sampled at 5 deg).
No body dimension or margin is reduced. Path queries only; not movement episodes."""
import sys,math,json,numpy as np
sys.path.insert(0,__import__('os').environ['RECAST_ADAPTER_DIR'])
from detour_engine import Engine,Config
from scipy import ndimage
from routes import quads
RES=.05;LAT=.225+.15;FORE=.15+.15;DISC=LAT
# rectangle sample points (body frame: x forward, y lateral), 2.5 cm grid incl. edges
gx=np.arange(-FORE,FORE+1e-9,.025);gy=np.arange(-LAT,LAT+1e-9,.025);RX,RY=np.meshgrid(gx,gy,indexing='ij');RB=np.c_[RX.ravel(),RY.ravel()]
def rect_ok(mask,origin,cx,cz,theta):
  c,s=math.cos(theta),math.sin(theta);pts=np.c_[cx+RB[:,0]*c-RB[:,1]*s, cz+RB[:,0]*s+RB[:,1]*c]
  i=np.floor((pts[:,0]-origin[0])/RES).astype(int);j=np.floor((pts[:,1]-origin[1])/RES).astype(int)
  ok=(i>=0)&(i<mask.shape[0])&(j>=0)&(j<mask.shape[1])
  return ok.all() and mask[i,j].all()
def sweep_ok(mask,origin,P):
  P=np.asarray(P)[:,[0,2]];th_prev=None
  for a,b in zip(P[:-1],P[1:]):
    d=b-a;L=np.hypot(*d)
    if L<1e-6:continue
    th=math.atan2(d[1],d[0])
    if th_prev is not None:  # turn in place at the corner
      dth=(th-th_prev+math.pi)%(2*math.pi)-math.pi
      for k in range(int(abs(dth)/math.radians(5))+2):
        if not rect_ok(mask,origin,a[0],a[1],th_prev+dth*min(1,k*math.radians(5)/max(abs(dth),1e-9))):return 'turn'
    for t in np.arange(0,L+1e-9,.025):
      if not rect_ok(mask,origin,a[0]+d[0]*t/L,a[1]+d[1]*t/L,th):return 'segment'
    th_prev=th
  return 'ok'
def run(mask,label,npts=60,seed=11):
  lo=np.load('policyD.npz')['lo'];origin=(lo[0]*RES,lo[1]*RES)
  V,T=quads(mask,origin,RES)
  try:eng=Engine(V,T,Config(radius=DISC,height=1.75,cell_size=.05,max_climb=0.),mode='known-provided-map')
  except Exception as e:print(label,'build failed',e);return
  d=ndimage.distance_transform_edt(mask)*RES-RES*math.sqrt(2)/2
  cand=np.argwhere(d>=DISC)
  if len(cand)<2:print(label,'no disc-fit centres');eng.close();return
  rng=np.random.default_rng(seed);pick=cand[rng.choice(len(cand),min(npts,len(cand)),replace=False)]
  pts=[(origin[0]+(i+.5)*RES,0.,origin[1]+(j+.5)*RES) for i,j in pick]
  # start/goal must also fit the rectangle at SOME heading (turn-in-place allowed): check 72 headings
  fit=[any(rect_ok(mask,origin,p[0],p[2],math.radians(k*5)) for k in range(72)) for p in pts]
  pts=[p for p,f in zip(pts,fit) if f]
  stats=dict(label=label,discCentres=int(len(cand)),endpoints=len(pts),pairs=0,complete=0,len2to6=0,rectOK=0,failTurn=0,failSeg=0,lengthsOK=[])
  for a in range(len(pts)):
    for b in range(a+1,len(pts)):
      stats['pairs']+=1;r=eng.route(pts[a],pts[b]);pa=np.array(r.projected_start);pb=np.array(r.projected_goal)
      if not(r.complete and np.isfinite(pa).all() and np.linalg.norm((pa-pts[a])[[0,2]])<=.1 and np.linalg.norm((pb-pts[b])[[0,2]])<=.1):continue
      stats['complete']+=1;P=[pts[a]]+[tuple(p) for p in r.points[1:]];L=float(np.sum(np.linalg.norm(np.diff(np.asarray(P)[:,[0,2]],axis=0),axis=1)))
      if not(2.0<=L<=6.0):continue
      stats['len2to6']+=1;res=sweep_ok(mask,origin,P)
      if res=='ok':stats['rectOK']+=1;stats['lengthsOK'].append(round(L,2))
      elif res=='turn':stats['failTurn']+=1
      else:stats['failSeg']+=1
  eng.close();L=stats.pop('lengthsOK')
  print(json.dumps(stats),'| rect-OK lengths: n=%d median %.2f max %.2f'%(len(L),np.median(L) if L else 0,max(L) if L else 0))
if __name__=='__main__':
  D=np.load('policyD.npz')
  run(D['walk'],'D1 permissive (flagged allowed)')
  run(D['walk']&~D['lowUnresolvedFlag'],'D1 strict (near-only low band)')
  run(np.load('walk_statclear.npy'),'statistical clear only')
  run(np.load('walk_statperm.npy'),'statistical object-blocked only')
