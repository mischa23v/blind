import os
os.environ['OPENBLAS_NUM_THREADS']='1';os.environ['OMP_NUM_THREADS']='1'
import pathlib,json,hashlib,time,resource
resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(30,30));start=time.monotonic()
import numpy as np
from PIL import Image
H=pathlib.Path(__file__).resolve().parent;P=H.parent/'coffee-recovered-source/transformations.json';S=H/'PATCH_SELECTION.json';sel=json.loads(S.read_text());frames={pathlib.Path(f['file_path']).stem:f for f in json.loads(P.read_text())['frames']};rgbroot=H.parent/'coffee-semantic-coverage/selected/room_datasets/coffee_room/iphone/long_capture/images'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def stats(x):return {'count':len(x),'min':float(np.min(x)),'p05':float(np.quantile(x,.05)),'median':float(np.median(x)),'p95':float(np.quantile(x,.95)),'max':float(np.max(x))} if len(x) else {'count':0}
def cloud(depth,box,f):
 x0,y0,x1,y1=box;yy,xx=np.mgrid[y0:y1:4,x0:x1:4];d=depth[yy,xx].ravel()/1000;ray=np.c_[(xx.ravel()-f['cx'])/f['fl_x'],(yy.ravel()-f['cy'])/f['fl_y'],np.ones(d.size)];valid=(d>0)&(d<4);return ray[valid]*d[valid,None],ray[valid],d[valid]
def fit(p):
 centre=p.mean(axis=0);_,s,v=np.linalg.svd(p-centre,full_matrices=False);normal=v[-1];normal=normal if normal[1]<0 else -normal;offset=-normal@centre;return normal,offset,{'points':len(p),'singularValues':s.tolist(),'absoluteResidualMetres':stats(np.abs(p@normal+offset)),'normalCameraCV':normal.tolist(),'offset':float(offset)}
rows=[]
for selected in sel['frames']:
 frame=selected['frame'];f=frames[frame];rp=rgbroot/(frame+'.jpg');dp=H/'depth'/(frame+'.png');assert sha(rp)==selected['rgbSHA256'];im=Image.open(rp);rgbsize=im.size;orientation=im.getexif().get(274);d=np.asarray(Image.open(dp));assert rgbsize==(f['w'],f['h'])==(738,994) and d.shape==(994,738) and d.dtype==np.uint16 and orientation in (None,1)
 row={'frame':frame,'rgbSHA256':sha(rp),'depthSHA256':sha(dp),'rgbSize':list(rgbsize),'depthShape':list(d.shape),'depthDtype':str(d.dtype),'rgbEXIFOrientation':orientation,'intrinsics':{k:f[k] for k in ['fl_x','fl_y','cx','cy']},'rasterTransformApplied':'none; noresize/noimageflip/rotation','patches':{}}
 points={};rays={};depths={}
 for label,key in [('table','tableInsetXYXY'),('floor','nearbyFloorInsetXYXY')]:
  box=selected[key];x0,y0,x1,y1=box;patch=d[y0:y1,x0:x1];positive=patch[patch>0]/1000.;pc,ray,dz=cloud(d,box,f);points[label]=pc;rays[label]=ray;depths[label]=dz
  row['patches'][label]={'pixelCount':patch.size,'zeroCount':int((patch==0).sum()),'atOrBeyond4m':int((patch>=4000).sum()),'positiveDepthMetres':stats(positive),'uniquePositiveMillimetreValues':int(len(np.unique(patch[patch>0]))),'planeInput':'all positive<4m at fixed4pixelstride, nooutlier removal'}
 if all(len(p)>10 for p in points.values()):
  nt,dt,ft=fit(points['table']);nf,df,ff=fit(points['floor']);den=rays['table']@nf;pred=-df/den;valid=np.isfinite(pred)&(pred>0)&(np.abs(den)>1e-10);angle=float(np.degrees(np.arccos(np.clip(abs(nt@nf),0,1))));row['localPlaneDiagnostic']={'tableFit':ft,'floorFit':ff,'unsignedNormalAngleDegrees':angle,'tablePointsSignedDistanceToFloorPlaneMetres':stats(points['table']@nf+df),'tableDepthMinusExtrapolatedFloorAxialMetres':stats(depths['table'][valid]-pred[valid]),'floorExtrapolationValidRays':int(valid.sum()),'note':'smallRGBchosenfloorpatch plane extrapolation, no independent calibration/support/height truth; no globalposes or mesh registration used'}
 rows.append(row)
result={'patchSelectionSHA256':sha(S),'originalPosesSHA256':sha(P),'analysisSourceSHA256':sha(pathlib.Path(__file__)),'frames':rows,'contract':{'depthMetresPerUnit':.001,'pixelConvention':'integeroriginalexportpixels','cameraCoordinates':'localCVxrightydownzforward only; no globalpose transform','processedExportNotNativeSensor':True,'originalUpsamplingFilterUnknown':True,'confidenceSynchronizationAndCalibrationIncomplete':True,'physicalAuthority':False},'wallSeconds':time.monotonic()-start,'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'noSourceMutation':True};(H/'DEPTH_DIAGNOSTIC.json').write_text(json.dumps(result,indent=2)+'\n')
for r in rows:
 print(r['frame'],json.dumps({'table':r['patches']['table']['positiveDepthMetres'],'floor':r['patches']['floor']['positiveDepthMetres'],'tableZeros':r['patches']['table']['zeroCount'],'normalAngle':r.get('localPlaneDiagnostic',{}).get('unsignedNormalAngleDegrees'),'tableDistToFloor':r.get('localPlaneDiagnostic',{}).get('tablePointsSignedDistanceToFloorPlaneMetres'),'tableMinusFloorRay':r.get('localPlaneDiagnostic',{}).get('tableDepthMinusExtrapolatedFloorAxialMetres')},indent=2))
