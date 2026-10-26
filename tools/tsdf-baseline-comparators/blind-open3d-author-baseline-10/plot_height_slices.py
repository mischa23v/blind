#!/usr/bin/env python3
"""Display-only fixed absolute-height slices; never a floor/support classifier."""
import os
os.environ.setdefault('MPLCONFIGDIR','/tmp/koivu-tsdf-mpl')
os.environ.setdefault('OPENBLAS_NUM_THREADS','1')
import hashlib,json,pathlib,time,resource,shutil
resource.setrlimit(resource.RLIMIT_CPU,(60,65))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import vtk
from vtk.util.numpy_support import vtk_to_numpy
S=pathlib.Path(__file__).resolve().parent; O=S/'height-slices'; O.mkdir(exist_ok=False)
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1<<20),b''):h.update(b)
 return h.hexdigest()
t=time.monotonic();p=S/'koivu/unfiltered-tsdf-mesh.ply';expected='5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e'
assert sha(p)==expected and shutil.disk_usage(S).free>768*1024**2+8*1024**2
reader=vtk.vtkPLYReader();reader.SetFileName(str(p));reader.Update();mesh=reader.GetOutput();xyz=vtk_to_numpy(mesh.GetPoints().GetData())
assert xyz.shape==(242293,3) and mesh.GetNumberOfCells()==461256
bins=np.arange(-1.5,2.01,.5);counts=[];fig,axes=plt.subplots(2,4,figsize=(16,8.8),constrained_layout=True)
for ax,lo,hi in zip(axes.flat,bins[:-1],bins[1:]):
 mask=(xyz[:,2]>=lo)&(xyz[:,2]<hi);counts.append(int(mask.sum()))
 ax.scatter(xyz[mask,0],xyz[mask,1],s=.3,color='#315f8d',rasterized=True)
 ax.set(title=f'{lo:g} ≤ Z < {hi:g} m\n{counts[-1]:,} vertices',xlabel='Exported X (m)',ylabel='Exported Y (m)',xlim=(-5.5,6.5),ylim=(-5.8,5.8));ax.set_aspect('equal');ax.grid(alpha=.2)
axes.flat[-1].axis('off');axes.flat[-1].text(.02,.95,'All mesh vertices appear in exactly\none fixed absolute-height slice.\n\nThese are display bins, not\nfloor/obstacle classifications.\n\nNo surface filtering, filling,\nclearance or route computation.\n\nWhite pixels are unplotted areas,\nNOT known-free space.\n\nProjection hides depth and does\nnot establish physical accuracy.',va='top',fontsize=11)
assert sum(counts)==len(xyz)
fig.suptitle('Koivu phone-derived TSDF: fixed 0.5 m display slices\n265 author-training frames; unchanged 4 cm / 20 cm / 4 m author configuration',fontsize=14)
fig.savefig(O/'fixed-height-slices.png',dpi=140);plt.close(fig)
assert sha(p)==expected
r={'inputMeshSHA256':expected,'displayOnly':True,'notFloorClassification':True,'bandsHalfOpenMetres':[[float(a),float(b)]for a,b in zip(bins[:-1],bins[1:])],'vertexCounts':counts,'totalVertices':len(xyz),'allVerticesAccountedFor':sum(counts)==len(xyz),'VTKReadbackCoordinateType':mesh.GetPoints().GetData().GetDataTypeAsString(),'originalMeshUnchanged':True,'sourceSHA256':sha(pathlib.Path(__file__)),'plotSHA256':sha(O/'fixed-height-slices.png'),'wallSeconds':time.monotonic()-t,'maxRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024,'freeAfterBytes':shutil.disk_usage(S).free,'physicalAuthority':False}
(O/'RECEIPT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
