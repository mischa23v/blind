import os
os.environ['OPENBLAS_NUM_THREADS']='1';os.environ['OMP_NUM_THREADS']='1';os.environ['MPLCONFIGDIR']=os.path.join(os.path.dirname(__file__),'mpl-cache')
import pathlib,resource,time,json,hashlib
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(30,30));start=time.monotonic()
import numpy as np
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
from matplotlib.patches import Rectangle
H=pathlib.Path(__file__).resolve().parent;W=H.parent/'coffee-native-replay-prepared-002';M=W/'blind-coffee-source-readiness/selected/room_datasets/coffee_room/iphone/long_capture/polycam_mesh/textured.obj';A=W/'blind-coffee-source-readiness/ORIENTATION_AUDIT.json';R=W/'blind-coffee-native-topology/RESULT.json';T=H.parent/'coffee-semantic-coverage/selected/room_datasets/coffee_room/iphone/long_capture/polycam_mesh/textured_0_qHRMGgqy.jpg'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
pins={str(p.relative_to(H.parent)):sha(p) for p in [M,A,R,T]};vertices=[];uv=[];faces=[];ft=[]
for l in M.open():
 q=l.split()
 if not q:continue
 if q[0]=='v':vertices.append(list(map(float,q[1:4])))
 elif q[0]=='vt':uv.append(list(map(float,q[1:3])))
 elif q[0]=='f':faces.append([int(a.split('/')[0])-1 for a in q[1:]]);ft.append([int(a.split('/')[1])-1 for a in q[1:]])
v=np.asarray(vertices);f=np.asarray(faces);uv=np.asarray(uv);ft=np.asarray(ft);tri=v[f];c=tri.mean(axis=1);floor=json.loads(A.read_text())['candidateFloor']['weightedCentroidOBJ'][1];height=c[:,1]-floor;cross=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);mag=np.linalg.norm(cross,axis=1);area=mag/2;horizontal=np.abs(cross[:,1])/np.maximum(mag,1e-30)>=np.cos(np.pi/12)
im=np.asarray(Image.open(T).convert('RGB'));tc=uv[ft].mean(axis=1);px=np.clip((tc[:,0]*(im.shape[1]-1)).astype(int),0,im.shape[1]-1);py=np.clip(((1-tc[:,1])*(im.shape[0]-1)).astype(int),0,im.shape[0]-1);colors=im[py,px]/255.;del im
regions={'south-small-patches':[-.8,.9,-1.8,-.7],'north-small-patches':[-.8,.9,1.4,2.5]};stats={}
for name,(xmin,xmax,zmin,zmax) in regions.items():
 # Use any XZ bbox overlap, not only centroid, to avoid hiding large top triangles.
 overlap=(tri[:,:,0].max(axis=1)>=xmin)&(tri[:,:,0].min(axis=1)<=xmax)&(tri[:,:,2].max(axis=1)>=zmin)&(tri[:,:,2].min(axis=1)<=zmax)
 anyheight=(tri[:,:,1].max(axis=1)>=floor+.45)&(tri[:,:,1].min(axis=1)<=floor+1.1);sel=overlap&anyheight
 hh=sel&horizontal
 stats[name]={'sourceXZWindow':[xmin,xmax,zmin,zmax],'windowMeaning':'debugpatch neighborhood, not independentlyregistered physicaltable footprint','allBBoxOverlapTriangles':int(overlap.sum()),'anyTriangleHeightOverlapAboveFloor045to110':int(sel.sum()),'nearHorizontalTrianglesInHeightOverlap':int(hh.sum()),'nearHorizontalWholeTriangleAreaInHeightOverlap':float(area[hh].sum()),'elevatedTriangleOriginalIDs':np.flatnonzero(sel).tolist(),'maxVertexHeightAboveFloorAmongOverlappingTriangles':float(tri[overlap,:,1].max()-floor),'minVertexHeightAboveFloorAmongOverlappingTriangles':float(tri[overlap,:,1].min()-floor)}
fig,axs=plt.subplots(1,2,figsize=(13,8));sel=(height>=.05)&(height<=1.6);order=np.argsort(c[sel,1]);selected=np.flatnonzero(sel)[order]
axs[0].add_collection(PolyCollection(tri[selected][:,:,[0,2]],facecolors=colors[selected],edgecolor='none'));axs[0].set_title('Source texture on elevated triangles\n(original UV, mean-sample colors; not camera registration)')
sel2=(height>=.45)&(height<=1.1);axs[1].add_collection(PolyCollection(tri[sel2][:,:,[0,2]],array=height[sel2],cmap='viridis',edgecolor='none'));axs[1].set_title('All source triangles: centroid height0.45–1.10m\nDisplay filter only; not a semantic tabletop classifier')
r=json.loads(R.read_text());q=max((q for q in r['queries'] if q['acceptedNativeProposal']),key=lambda q:q['pathLengthMetres']);p=np.asarray(q['native']['points'])
for ax in axs:
 ax.plot(p[:,0],p[:,2],color='#0077ff',lw=2,label='Actual longest route0→8')
 for name,(xmin,xmax,zmin,zmax) in regions.items():ax.add_patch(Rectangle((xmin,zmin),xmax-xmin,zmax-zmin,fill=False,edgecolor='red',linestyle='--'));ax.text(xmin,zmin,name,fontsize=8,color='red')
 ax.set_xlim(v[:,0].min()-.1,v[:,0].max()+.1);ax.set_ylim(v[:,2].min()-.1,v[:,2].max()+.1);ax.set_aspect('equal');ax.grid(alpha=.2);ax.set_xlabel('Source X');ax.set_ylabel('Source Z');ax.legend(fontsize=8)
fig.suptitle('Targeted representation check: source triangles, not inferred table geometry');fig.tight_layout();out=H/'coffee-table-representation-debug.png';fig.savefig(out,dpi=130);plt.close(fig)
hist=[]
for lo in np.arange(0,1.6,.1):
 s=(height>=lo)&(height<lo+.1)&horizontal;hist.append({'aboveFloorBand':[round(float(lo),2),round(float(lo+.1),2)],'triangleCount':int(s.sum()),'wholeTriangleArea':float(area[s].sum())})
result={'inputSHA256':pins,'analysisSourceSHA256':sha(pathlib.Path(__file__)),'figureSHA256':sha(out),'floorCandidateY':floor,'regions':stats,'globalNearHorizontalCentroidHeightBands':hist,'geometryModified':False,'nativeRerun':False,'cameraRegistrationEstablished':False,'trianglesChecked':len(f),'inputsUnchanged':all(sha(H.parent/n)==h for n,h in pins.items()),'wallSeconds':time.monotonic()-start,'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss};(H/'TABLE_REPRESENTATION_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ['globalNearHorizontalCentroidHeightBands','inputSHA256']},indent=2))
