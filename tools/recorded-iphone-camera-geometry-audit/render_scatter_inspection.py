"""Presentation-only frame-0 scatter: existing returned points, no re-projection."""
from pathlib import Path
import hashlib,json,os,resource,time
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'inspection-label-fix'
if OUT.exists():raise RuntimeError('refuse overwrite of presentation output')
OUT.mkdir()
os.environ['MPLCONFIGDIR']=str(OUT/'cache');os.environ['XDG_CACHE_HOME']=str(OUT/'cache');os.environ['OPENBLAS_NUM_THREADS']='1'
resource.setrlimit(resource.RLIMIT_CPU,(10,10))
start=time.monotonic()
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
source=ROOT/'run/frame-0-camera-points.csv'
receipt_path=ROOT/'run/GEOMETRY_RECEIPT.json'
receipt_sha='54423440e787d89b0402cc657a118af74a9934fa300536fe17e2f80a08507bed'
if hashlib.sha256(receipt_path.read_bytes()).hexdigest()!=receipt_sha:raise ValueError('reviewed geometry receipt changed')
receipt=json.loads(receipt_path.read_text())
expected=next(f['sha256'] for f in receipt['artifacts'] if f['path']==source.name)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if sha(source)!=expected:raise ValueError('returned point CSV changed')
a=np.genfromtxt(source,delimiter=',',names=True)
if len(a)!=4278 or not np.all(a['frame']==0):raise ValueError('unexpected returned point selection')
fig=plt.figure(figsize=(9,8));ax=fig.add_axes([.10,.18,.76,.66],projection='3d')
x,y,z=a['x_camera_m'],a['y_camera_m'],a['z_camera_m']
ax.scatter(x,y,z,s=1.6,c='#3675ba',alpha=.65,rasterized=True)
ax.scatter([0],[0],[0],c='#222222',s=30);ax.quiver(0,0,0,0,0,-.15,color='#222222',arrow_length_ratio=.2)
lo=np.minimum(np.array([x.min(),y.min(),z.min()]),0);hi=np.maximum(np.array([x.max(),y.max(),z.max()]),0);padding=np.maximum((hi-lo)*.05,.02)
ax.set(xlabel='X [m]',ylabel='Y [m]',zlabel='Z [m]',xlim=(lo[0]-padding[0],hi[0]+padding[0]),ylim=(lo[1]-padding[1],hi[1]+padding[1]),zlim=(lo[2]-padding[2],hi[2]+padding[2]))
ax.set_box_aspect(hi-lo+2*padding);ax.view_init(elev=23,azim=135)
fig.text(.5,.94,'Analytical camera-point scatter — recorded frame 0',ha='center',fontsize=14)
fig.text(.5,.90,'4,278 existing shared-projection points; no geometry rerun or filled holes',ha='center',fontsize=10)
fig.text(.5,.105,'Camera X points right; camera Y points up (not gravity).',ha='center',fontsize=11)
fig.text(.5,.075,'Forward is negative camera Z; black marker/arrow indicates the camera origin/forward.',ha='center',fontsize=10)
fig.text(.5,.04,'Camera-relative diagnostic only — not physical accuracy, hazard recall or clearance.',ha='center',fontsize=10)
image=OUT/'frame-0-camera-point-scatter-readable.png';fig.savefig(image,dpi=120,bbox_inches='tight',pad_inches=.2);plt.close(fig)
if sha(source)!=expected:raise ValueError('returned points changed during presentation')
result={'scope':'Presentation-only label repair; original outputs retained, no numeric or production geometry rerun','geometryReceiptSHA256':receipt_sha,'inputPointSHA256':expected,'pointCount':len(a),
        'scriptSHA256':sha(Path(__file__)),'imageSHA256':sha(image),'imageBytes':image.stat().st_size,'wallSeconds':time.monotonic()-start,
        'cpuSeconds':resource.getrusage(resource.RUSAGE_SELF).ru_utime+resource.getrusage(resource.RUSAGE_SELF).ru_stime,'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
(OUT/'PRESENTATION_RECEIPT.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
