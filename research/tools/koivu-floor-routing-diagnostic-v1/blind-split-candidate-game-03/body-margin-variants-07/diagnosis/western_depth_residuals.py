"""Read-only original processed-depth evidence at preselected western camera cells.

Reuses the released pipeline's +0.5 pixel and Float32 phone-point sequence.
This is endpoint evidence, not a re-run of probabilistic OctoMap fusion or truth.
"""
from pathlib import Path
from io import BytesIO
import hashlib,json,sys
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
GAME=HERE.parents[1]
WS=GAME.parent
POSE=WS/'blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json'
DEPTH=WS/'blind-koivu-game-07/map/depths'
META=GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz'
MASK=GAME/'inputs/koivu_5cm_occthres_split0.7.npz'
ROI=GAME/'room-scale-readonly-audit/WESTERN_PASSAGE_CAMERA_CELLS.json'
SOURCE=WS/'blind-opus-reference-scoring-audit-02/upstream/scripts/pipeline.py'
P2=GAME/'upstream/scripts/pipeline2.py'
OCC=GAME/'upstream/scripts/occthres.py'
KEYS=('support','deepBelow','nearDip','low1','lowUnresolvedFlag','highObstacle','highUnknown','walk')

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def summary(a):
 a=np.asarray(a)
 return {'n':int(a.size),'min':float(a.min())if a.size else None,'p05_p50_p95':np.percentile(a,[5,50,95]).tolist()if a.size else None,'max':float(a.max())if a.size else None}

def project(depth,f):
 rs=np.flatnonzero((np.arange(depth.shape[0])+15)%4==2)
 cs=np.flatnonzero((np.arange(depth.shape[1])+15)%4==2)
 rr,cc=np.meshgrid(rs,cs,indexing='ij')
 dd=depth[np.ix_(rs,cs)].astype(np.float64)*.001
 pad=np.pad(dd,1,mode='edge')
 jump=np.max(np.stack([abs(dd-pad[:-2,1:-1]),abs(dd-pad[2:,1:-1]),abs(dd-pad[1:-1,:-2]),abs(dd-pad[1:-1,2:])]),0)>.3
 rays=np.stack(((cc+.5-f['cx'])/f['fl_x'],-(rr+.5-f['cy'])/f['fl_y'],-np.ones_like(rr)),axis=-1)
 T=np.asarray(f['transform_matrix'])
 p=((rays*dd[...,None]).reshape(-1,3)@T[:3,:3].T+T[:3,3]).astype(np.float32)
 valid=dd.ravel()>0
 return p[valid],rr.ravel()[valid],cc.ravel()[valid],depth[np.ix_(rs,cs)].ravel()[valid],jump.ravel()[valid]

def verify_roi(rows,frames,R,t,lo,res,flags):
 if len(rows)!=71:raise ValueError('fixed ROI count changed')
 H,W=flags['walk'].shape
 for r in rows:
  fi=r['frameIndex1Based']-1
  if not 0<=fi<len(frames):raise ValueError('ROI frame index')
  xy=(np.asarray(frames[fi]['transform_matrix'])[:3,3]@R.T+t)[:2]
  ij=np.floor(xy/res).astype(np.int64)-lo[:2]
  if np.max(abs(xy-np.asarray(r['sourceXY'])))>1e-10 or ij.tolist()!=r['sourceIJ']:raise ValueError('ROI pose/cell association')
  i,j=ij
  if not(0<=i<H and 0<=j<W)or not(xy[0]<-3 and 1<xy[1]<3.5):raise ValueError('ROI bounds')
  if any(bool(flags[k][i,j])!=r[k]for k in ('walk','support','low1')):raise ValueError('ROI source mask association')

def run(out,expected):
 frozen=HERE/'WEST_DEPTH_FROZEN.json'
 if sha(frozen)!=expected:raise ValueError('freeze changed')
 pins=json.loads(frozen.read_text())['files']
 def check():
  for p,h in pins.items():
   if sha(WS/p)!=h:raise ValueError('source/input changed: '+p)
 check();out=Path(out);out.mkdir(exist_ok=False)
 frames=json.loads(POSE.read_text())['frames'];manifest=json.loads((DEPTH/'DEPTH_INPUT_MANIFEST.json').read_text())
 roi=json.loads(ROI.read_text());rows=roi['rows']
 with np.load(META,allow_pickle=False)as z:R=z['R'];t=z['t'];lo=z['lo'];res=float(z['res'])
 with np.load(MASK,allow_pickle=False)as z:flags={k:z[k]for k in KEYS}
 assert len(frames)==len(manifest['files'])==294 and res==.05
 verify_roi(rows,frames,R,t,lo,res,flags)
 # All fixed ROI records, including walkable controls; no outcome-driven selection.
 cells=np.unique(np.asarray([r['sourceIJ']for r in rows],dtype=np.int64),axis=0)
 H,W=flags['walk'].shape;wanted=np.zeros(H*W,bool);wanted[cells[:,0]*W+cells[:,1]]=True
 chunks=[];counts=[];roundtrip_changes=0
 for fi,(f,e)in enumerate(zip(frames,manifest['files'])):
  raw=(DEPTH/e['file']).read_bytes()
  if hashlib.sha256(raw).hexdigest()!=e['sha256']or e['poseIndex']!=fi or Path(f['depth_file_path']).name!=e['file']:raise ValueError('depth association/hash')
  with Image.open(BytesIO(raw))as image:dep=np.asarray(image)
  if dep.shape!=(994,738)or dep.dtype!=np.uint16:raise ValueError('raster contract')
  p,rr,cc,mm,jump=project(dep,f)
  level=p@R.T+t
  ij=np.floor(level[:,:2]/res).astype(np.int64)-lo[:2]
  # Native float endpoint quantization is disclosed separately; no key-status inference.
  native_xy=(level[:,:2].astype(np.float32).astype(np.float64))
  ij32=np.floor(native_xy/res).astype(np.int64)-lo[:2]
  roundtrip_changes+=int(np.any(ij!=ij32,axis=1).sum())
  inside=(ij[:,0]>=0)&(ij[:,0]<H)&(ij[:,1]>=0)&(ij[:,1]<W)
  chosen=np.zeros(len(p),bool);chosen[inside]=wanted[ij[inside,0]*W+ij[inside,1]]
  q=np.flatnonzero(chosen);cam=np.asarray(f['transform_matrix'])[:3,3]
  ranges=np.linalg.norm(p.astype(np.float64)-cam,axis=1)
  chunks.append({'frame':np.full(len(q),fi,np.uint16),'row':rr[q].astype(np.uint16),'col':cc[q].astype(np.uint16),'depthMM':mm[q],
   'i':ij[q,0].astype(np.int16),'j':ij[q,1].astype(np.int16),'level':level[q],'range':ranges[q],'jump':jump[q]})
  counts.append({'poseIndex':fi,'validSourceSamples':len(p),'selectedColumnEndpoints':len(q)})
 allpts={k:np.concatenate([a[k]for a in chunks])for k in chunks[0]};del chunks
 h=allpts['level'][:,2];cellrows=[]
 for i,j in cells:
  use=(allpts['i']==i)&(allpts['j']==j);near=use&(allpts['range']<=2.)
  def heights(mask):
   v=h[mask]
   return {'heightMetres':summary(v),'frames':int(np.unique(allpts['frame'][mask]).size),'rangeMetres':summary(allpts['range'][mask]),
    'belowMinus2p5cm':int((v<-.025).sum()),'floorBandInclusive':int((abs(v)<=.025).sum()),'lowBand2p5To7p5cm':int(((v>.025)&(v<=.075)).sum()),'above7p5cm':int((v>.075).sum()),'discontinuitySamples':int(allpts['jump'][mask].sum())}
  frame_stats=[]
  for fi in np.unique(allpts['frame'][use]):
   m=use&(allpts['frame']==fi);frame_stats.append({'poseIndex':int(fi),'frameID':Path(frames[fi]['depth_file_path']).stem,**heights(m)})
  # Exemplars are measured endpoints, ranked by range with distinct frame IDs.
  exemplars=[]
  for category,m in [('lowBand',use&(h>.025)&(h<=.075)),('floorBand',use&(abs(h)<=.025)),('otherHeight',use&((h<-.025)|(h>.075)))]:
   seen=set()
   for q in np.flatnonzero(m)[np.argsort(allpts['range'][m],kind='stable')]:
    fi=int(allpts['frame'][q])
    if fi in seen:continue
    seen.add(fi);f=frames[fi]
    exemplars.append({'category':category,'poseIndex':fi,'frameID':Path(f['depth_file_path']).stem,'originalRGBBasename':Path(f['file_path']).name,'originalDepthBasename':Path(f['depth_file_path']).name,
     'pixelRowCol':[int(allpts['row'][q]),int(allpts['col'][q])],'depthMM':int(allpts['depthMM'][q]),'levelXYZMetres':allpts['level'][q].tolist(),'cameraRangeMetres':float(allpts['range'][q]),'depthDiscontinuity':bool(allpts['jump'][q])})
    if len(seen)==3:break
  cellrows.append({'sourceIJ':[int(i),int(j)],'sourceCellCentreXY':((np.array([i,j])+lo[:2]+.5)*res).tolist(),
   'flags':{k:bool(flags[k][i,j])for k in KEYS},'cameraFrameRecords':[r['frameIndex1Based']for r in rows if r['sourceIJ']==[int(i),int(j)]],
   'allViews':heights(use),'nearViewsAtMost2m':heights(near),'perFrame':frame_stats,'measuredEndpointExemplars':exemplars})
 np.savez_compressed(out/'SELECTED_ENDPOINTS.npz',**allpts)
 groups={}
 for name,pred in [('low1Blocked',lambda c:c['flags']['low1']and not c['flags']['walk']),('missingSupportBlocked',lambda c:not c['flags']['support']and not c['flags']['walk']),('walkableControls',lambda c:c['flags']['walk'])]:
  group=[c for c in cellrows if pred(c)];groups[name]={'uniqueCells':len(group),'cameraFrameRecords':sum(len(c['cameraFrameRecords'])for c in group),
   'sourceEndpointCount':sum(c['allViews']['heightMetres']['n']for c in group),'cellsWithNearEndpoint':sum(c['nearViewsAtMost2m']['heightMetres']['n']>0 for c in group),
   'cellsWithNearLowBandEndpoints':sum(c['nearViewsAtMost2m']['lowBand2p5To7p5cm']>0 for c in group),'cellsWithNearFloorEndpoints':sum(c['nearViewsAtMost2m']['floorBandInclusive']>0 for c in group)}
 result={'scope':'Read-only endpoint residuals at fixed western camera-column records; no fusion/map edits/reference/route calls','cameraFrameRecords':len(rows),'uniqueCells':len(cells),'all294SourceSamples':sum(c['validSourceSamples']for c in counts),'selectedEndpointCount':len(h),'float32XYEndpointKeyChangesAllSamples':roundtrip_changes,'groups':groups,'cells':cellrows,'frames':counts,
  'projection':'Exact pipeline.py lidar_samples: source row/col pattern, pixel+0.5, positive mm depth, OpenGL camera-to-phone, Float32 phone points; supplied R/t in Float64 as occthres.py. Raw column binning before OctoMap fusion.',
  'globalFloorOnly':True,'localFloorSurfaceUsedBySplitWalk':False,'originalConfidence':'unavailable','tracking':'unavailable','physicalAuthority':False,'groupCategoriesMayOverlap':True,
  'limitations':['Raw endpoints are not native occupied/free probabilities; supplied split artifact does not contain per-voxel post-threshold states.','Near<=2m uses the original Float32 phone point and original camera position; it is a range diagnostic, not reproduction of the native Float32 fusion cutoff/status.','Low residuals do not distinguish real small objects from floor/depth/registration variation without independent geometry.','Camera centre passing a column is not a swept-body clearance proof.','No rejected endpoint was removed or relabelled as safe.']}
 check();(out/'RESULT.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
 print(json.dumps({k:result[k]for k in ['cameraFrameRecords','uniqueCells','all294SourceSamples','selectedEndpointCount','float32XYEndpointKeyChangesAllSamples','groups']}))

if __name__=='__main__':run(sys.argv[1],sys.argv[2])
