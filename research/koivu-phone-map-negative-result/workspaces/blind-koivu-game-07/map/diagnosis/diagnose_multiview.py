from pathlib import Path
import hashlib,json,math,resource,shutil,signal,sys,time
import numpy as np
from scipy.ndimage import minimum_filter,maximum_filter
ROOT=Path(__file__).resolve().parent;sys.path.insert(0,str(ROOT.parent));import map_builder as m

def quant(a):return None if len(a)==0 else {str(q):float(np.quantile(a,q)) for q in (0,.05,.5,.95,1)}
def run():
 resource.setrlimit(resource.RLIMIT_CPU,(120,120));resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,)*2);signal.alarm(180);started=time.monotonic();out=ROOT/'multiview-run';out.mkdir(exist_ok=False)
 frames=json.loads(m.POSE.read_text())['frames'];manifest=json.loads((m.ROOT/'depths/DEPTH_INPUT_MANIFEST.json').read_text());frozen='d69e2c1bd61ebb61d307056e53f5c8b653e06eb9ae8189667fa425500461b350';m.verify_frozen(frozen)
 pins={p.name:m.sha(p) for p in (Path(__file__),ROOT/'DIAGNOSTIC_PROTOCOL.md')};camera_z=np.array([f['transform_matrix'][2][3] for f in frames]);floorlow=float(np.median(camera_z)-2.5);floorhigh=float(np.median(camera_z)-.5)
 source=[];patches=[]
 for i,(frame,entry) in enumerate(zip(frames,manifest['files'])):
  d=m.depth_read(entry,frame);c,k=m.checked_camera(frame);rr,cc=np.mgrid[0:d.shape[0]:8,0:d.shape[1]:8];ds=d[rr,cc];q=np.stack(((cc+.5-k[2])/k[0],-(rr+.5-k[3])/k[1],-np.ones(rr.shape)),axis=-1);p=(q*ds[...,None])@c[:3,:3].T+c[:3,3];good=np.isfinite(ds)&(ds>0);source.append((p.reshape(-1,3),good.ravel()))
  ex=p[:-1,1:]-p[:-1,:-1];ey=p[1:,:-1]-p[:-1,:-1];n=np.cross(ex,ey);length=np.linalg.norm(n,axis=-1);normalz=np.divide(np.abs(n[:,:,2]),length,out=np.zeros_like(length),where=length>0)
  pc=p[:-1,:-1];ok=good[:-1,:-1]&good[:-1,1:]&good[1:,:-1]&(np.linalg.norm(ex,axis=-1)<=.25)&(np.linalg.norm(ey,axis=-1)<=.25)&(normalz>=math.cos(math.radians(15)))&(pc[:,:,2]>=floorlow)&(pc[:,:,2]<=floorhigh)
  z=pc[:,:,2][ok];mode=None
  if len(z):values,counts=np.unique(np.floor(z/.01).astype(int),return_counts=True);mode=float((values[np.argmax(counts)]+.5)*.01)
  patches.append({'index':i,'file':entry['file'],'candidatePatchPoints':len(z),'rawPhoneZQuantiles':quant(z),'oneCentimetreModalBinCentre':mode})
  if i%50==0:print(json.dumps({'phase':'patches','frame':i,'seconds':time.monotonic()-started}),flush=True)
 pairs=[];pool={1:[],30:[]}
 for lag in (1,30):
  for i in range(len(frames)-lag):
   j=i+lag;frame=frames[j];depth=m.depth_read(manifest['files'][j],frame);c,k=m.checked_camera(frame);inv=np.linalg.inv(c);p,valid=source[i];cam=p@inv[:3,:3].T+inv[:3,3];z=-cam[:,2]
   with np.errstate(divide='ignore',invalid='ignore'):u=k[0]*cam[:,0]/z+k[2]-.5;v=-k[1]*cam[:,1]/z+k[3]-.5
   proj=valid&np.isfinite(u)&np.isfinite(v)&(z>0);cc=np.zeros(len(p),int);rr=np.zeros(len(p),int);cc[proj]=np.floor(u[proj]+.5).astype(int);rr[proj]=np.floor(v[proj]+.5).astype(int);proj&=(rr>=1)&(cc>=1)&(rr<depth.shape[0]-1)&(cc<depth.shape[1]-1)
   ids=np.flatnonzero(proj);mn=minimum_filter(depth,size=3,mode='constant',cval=0)[rr[ids],cc[ids]];mx=maximum_filter(depth,size=3,mode='constant',cval=0)[rr[ids],cc[ids]];centre=depth[rr[ids],cc[ids]];available=np.isfinite(mn)&(mn>0);a=ids[available];mn=mn[available];mx=mx[available];centre=centre[available];residual=centre-z[a]
   contradiction=mn>z[a]+.1;occluded=mx<z[a]-.1;agreement=(~contradiction)&(~occluded)&(np.abs(residual)<=.1);other=~(contradiction|occluded|agreement)
   counts={'scheduled':len(p),'missingSource':int((~valid).sum()),'projectionUnavailable':int((valid&~proj).sum()),'targetNeighbourhoodUnavailable':int((~available).sum()),'observedFreeContradiction':int(contradiction.sum()),'fullyOccluded':int(occluded.sum()),'centralAgreement':int(agreement.sum()),'edgeOrOther':int(other.sum())}
   assert counts['scheduled']==sum(v for key,v in counts.items() if key!='scheduled')
   body=(p[a,2]+1.275>.03)&(p[a,2]+1.275<1.75)
   pairs.append({'source':i,'target':j,'lag':lag,'counts':counts,'targetMinusSourceAxialQuantiles':quant(residual),'absoluteResidualQuantiles':quant(np.abs(residual)),'bodyBandAvailable':int(body.sum()),'bodyBandObservedFreeContradictions':int((body&contradiction).sum())});pool[lag].append(residual)
   if i%50==0:print(json.dumps({'phase':'pairs','lag':lag,'source':i,'seconds':time.monotonic()-started}),flush=True)
 summary={}
 for lag in (1,30):
  rows=[x for x in pairs if x['lag']==lag];r=np.concatenate(pool[lag]);summary[str(lag)]={'pairs':len(rows),'counts':{k:sum(x['counts'][k] for x in rows) for k in rows[0]['counts']},'signedResidualQuantiles':quant(r),'absoluteResidualQuantiles':quant(np.abs(r)),'bodyBandAvailable':sum(x['bodyBandAvailable']for x in rows),'bodyBandObservedFreeContradictions':sum(x['bodyBandObservedFreeContradictions']for x in rows)}
 m.verify_frozen(frozen)
 for p in (Path(__file__),ROOT/'DIAGNOSTIC_PROTOCOL.md'):
  assert m.sha(p)==pins[p.name]
 for entry in manifest['files']:assert m.sha(m.ROOT/'depths'/entry['file'])==entry['sha256']
 result={'status':'phone-only consistency diagnosis; no map changes or navigation','summary':summary,'perFramePatchHeight':patches,'pairs':pairs,'sourceProtocolHashes':pins,'inputFrozenSHA256':frozen,'wallSeconds':time.monotonic()-started,'CPUSeconds':time.process_time(),'peakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024,'FAROUsed':False,'accuracyOrNavigationPass':False}
 if result['peakRSSBytes']>1024**3 or shutil.disk_usage(ROOT).free<768*1024**2:raise ValueError('resource budget')
 data=json.dumps(result,indent=2)+'\n';assert len(data.encode())<4*1024**2
 (out/'RESULTS.json').write_text(data);print(json.dumps({k:v for k,v in result.items() if k not in ('perFramePatchHeight','pairs')}),flush=True)
if __name__=='__main__':run()
