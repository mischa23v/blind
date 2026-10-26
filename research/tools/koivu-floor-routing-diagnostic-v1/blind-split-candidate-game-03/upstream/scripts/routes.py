import sys,json,math,numpy as np
sys.path.insert(0,__import__('os').environ['RECAST_ADAPTER_DIR'])
from detour_engine import Engine,Config
from scipy import ndimage
def quads(mask,origin_xz,res):
  idx=np.argwhere(mask);V=[];T=[]
  for n,(i,j) in enumerate(idx):
    x=origin_xz[0]+i*res;z=origin_xz[1]+j*res;b=4*n
    V+= [(x,0,z),(x,0,z+res),(x+res,0,z+res),(x+res,0,z)];T+=[(b,b+1,b+2),(b,b+2,b+3)]
  return np.asarray(V,np.float32),np.asarray(T,np.int32)
def trial(mask,origin,res,radius,cs,label,npts=40,seed=7):
  V,T=quads(mask,origin,res)
  try: eng=Engine(V,T,Config(radius=radius,height=1.75,cell_size=cs,max_climb=0.),mode='known-provided-map')
  except Exception as e: print(f'{label}: build failed: {e}');return
  # candidate endpoints: column centres whose Euclidean clearance >= radius (independent of Recast)
  d=ndimage.distance_transform_edt(mask)*res-res*math.sqrt(2)/2
  cand=np.argwhere(d>=radius)
  if len(cand)<2: print(f'{label}: build ok; independent full-body centres {len(cand)}; no pairs');eng.close();return
  rng=np.random.default_rng(seed);pick=cand[rng.choice(len(cand),min(npts,len(cand)),replace=False)]
  pts=[(origin[0]+(i+.5)*res,0.,origin[1]+(j+.5)*res) for i,j in pick]
  comp=0;tot=0;lens=[];straight=[]
  for a in range(len(pts)):
    for b in range(len(pts)):
      if a==b:continue
      tot+=1;r=eng.route(pts[a],pts[b])
      pa=np.array(r.projected_start);pb=np.array(r.projected_goal)
      ok=r.complete and np.all(np.isfinite(pa)) and np.linalg.norm((pa-pts[a])[[0,2]])<=.1 and np.linalg.norm((pb-pts[b])[[0,2]])<=.1
      if ok:
        comp+=1;P=np.array(r.points);lens.append(np.sum(np.linalg.norm(np.diff(P[:,[0,2]],axis=0),axis=1)));straight.append(np.linalg.norm(np.subtract(pts[a],pts[b])[[0,2]]))
  eng.close()
  s=f'{label}: centres {len(cand)}, ordered pairs {tot}, complete associated routes {comp}'
  if lens:s+=f', path length median {np.median(lens):.2f} m max {np.max(lens):.2f} m, straight-line max {np.max(straight):.2f} m'
  print(s)
if __name__=='__main__':
  # v2 published surface (10 cm cells)
  sj=json.load(open(__import__('os').environ['BLIND_REPO']+'/research/koivu-octomap-v2/workspaces/blind-koivu-game-07/map-v2/run-01/map/SURFACE.json'))
  W,Dd=sj['width'],sj['depth'];el=np.array([c['floor'] is not None and c['clearance'] is not None and not c['blocked'] and c['clearance']>=1.75 for c in sj['cells']]).reshape(Dd,W).T
  print('v2 eligible cells',int(el.sum()))
  for rad,cs in ((.5324,.1),(.4204,.05),(.3704,.05),(.2704,.05)):trial(el,(sj['origin']['x'],sj['origin']['z']),.1,rad,cs,f'v2 SURFACE r={rad} cs={cs}')
  m=np.load('policyD.npz');lo=m['lo']
  for rad,cs in ((.5324,.1),(.5324,.05),(.4204,.05),(.3704,.05),(.2704,.05)):trial(m['walk'],(lo[0]*.05,lo[1]*.05),.05,rad,cs,f'policy D1 r={rad} cs={cs}')
