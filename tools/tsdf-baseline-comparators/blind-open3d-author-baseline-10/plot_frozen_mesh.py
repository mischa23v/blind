#!/usr/bin/env python3
"""Read-only analytical projections of the frozen TSDF mesh; no reconstruction."""
import os
os.environ.setdefault('MPLCONFIGDIR','/tmp/koivu-tsdf-mpl')
os.environ.setdefault('OPENBLAS_NUM_THREADS','1')
import hashlib, json, pathlib, resource, time, shutil
resource.setrlimit(resource.RLIMIT_CPU,(60,65))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import vtk
from vtk.util.numpy_support import vtk_to_numpy
S=pathlib.Path(__file__).resolve().parent; O=S/'mesh-inspection'; O.mkdir(exist_ok=False)
t=time.monotonic(); src=S/'koivu/unfiltered-tsdf-mesh.ply'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1<<20),b''): h.update(b)
 return h.hexdigest()
assert shutil.disk_usage(S).free > 768*1024**2+8*1024**2
expected='5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e'
assert sha(src)==expected
r=vtk.vtkPLYReader();r.SetFileName(str(src));r.Update(); mesh=r.GetOutput()
p=vtk_to_numpy(mesh.GetPoints().GetData())
assert p.shape==(242293,3) and mesh.GetNumberOfCells()==461256 and np.isfinite(p).all()
fig,axs=plt.subplots(2,2,figsize=(12,10),constrained_layout=True)
for ax,(a,b) in zip(axs.flat,[(0,1),(0,2),(1,2)]):
 sc=ax.scatter(p[:,a],p[:,b],c=p[:,2],s=.15,cmap='viridis',vmin=p[:,2].min(),vmax=p[:,2].max(),rasterized=True)
 ax.set(xlabel=f"Exported {'XYZ'[a]} (m)",ylabel=f"Exported {'XYZ'[b]} (m)",title=f"{'XYZ'[a]}–{'XYZ'[b]} projection: all mesh vertices")
 ax.set_aspect('equal');ax.grid(alpha=.2)
fig.colorbar(sc,ax=list(axs.flat)[:3],label='Exported Z (m)',shrink=.75)
axs[1,1].hist(p[:,2],bins=np.arange(np.floor(p[:,2].min()/.04)*.04,np.ceil(p[:,2].max()/.04)*.04+.04,.04),color='#356b91')
axs[1,1].set(xlabel='Exported Z (m)',ylabel='Mesh vertices',title='Vertex-height distribution (4 cm display bins)')
fig.suptitle('Koivu: released Open3D TSDF with DN-Splatter author parameters\n265 provided-pose training frames; no FARO, filtering or floor classification',fontsize=13)
fig.text(.5,-.02,'Surface projections can overlap. Unmeshed regions are UNKNOWN, not free. This is not a route or clearance test.',ha='center',fontsize=10)
fig.savefig(O/'all-vertices-projections.png',dpi=140,bbox_inches='tight');plt.close(fig)
assert sha(src)==expected
receipt={'schema':1,'inputMeshSHA256':expected,'vertices':len(p),'triangles':mesh.GetNumberOfCells(),'boundsMin':p.min(0).tolist(),'boundsMax':p.max(0).tolist(),'everyVertexPlotted':True,'geometryModified':False,'FAROUsed':False,'physicalAuthority':False,'sourceSHA256':sha(pathlib.Path(__file__)),'VTK':vtk.vtkVersion.GetVTKVersion(),'numpy':np.__version__,'matplotlib':matplotlib.__version__,'wallSeconds':time.monotonic()-t,'maxRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024,'outputBytes':sum(x.stat().st_size for x in O.iterdir()),'freeAfterBytes':shutil.disk_usage(S).free,'outputSHA256':{'all-vertices-projections.png':sha(O/'all-vertices-projections.png')}}
(O/'RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
