import os
for k in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS'): os.environ[k]='1'
os.environ['MPLCONFIGDIR']='/tmp/geometry-figure-mpl'
from pathlib import Path
import json, hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
BASE=Path(__file__).resolve().parents[1]
SRC=BASE/'fresh-run/common-surface-reader-fixed'; OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
names=[('reference','FARO: 29-view reference samples'),('open3d','Open3D TSDF / 4 m'),('fixed','RTAB-Map / fixed poses'),('graph','RTAB-Map / graph poses')]
points={}; provenance={}
for key,title in names:
 p=SRC/('reference_samples_faro_metres.npy' if key=='reference' else key+'.npz')
 a=np.load(p) if key=='reference' else np.load(p)['pointsFaroMetres']
 assert a.ndim==2 and a.shape[1]==3 and np.isfinite(a).all()
 points[key]=a
 provenance[key]={'source':str(p),'sha256':sha(p),'array':'NPY' if key=='reference' else 'pointsFaroMetres','total':len(a),'displayed':len(a[::4]),'omittedForDisplayOnly':len(a)-len(a[::4]),'bounds':[a.min(0).tolist(),a.max(0).tolist()]}
lo=np.floor(np.min([p.min(0) for p in points.values()],axis=0)*2)/2
hi=np.ceil(np.max([p.max(0) for p in points.values()],axis=0)*2)/2
fig,axs=plt.subplots(3,4,figsize=(16,9),layout='constrained',gridspec_kw={'height_ratios':[13,4.5,4.5]})
norm=Normalize(lo[2],hi[2]); projections=[(0,1),(0,2),(1,2)]; labels='XYZ'
for col,(key,title) in enumerate(names):
 a=points[key][::4]
 for row,(x,y) in enumerate(projections):
  ax=axs[row,col]
  s=ax.scatter(a[:,x],a[:,y],c=a[:,2],cmap='viridis',norm=norm,s=.28,alpha=.55,linewidths=0,rasterized=True)
  ax.set(xlim=(lo[x],hi[x]),ylim=(lo[y],hi[y]),xlabel=f'FARO {labels[x]} (m)',ylabel=f'FARO {labels[y]} (m)')
  ax.set_aspect('equal',adjustable='box');ax.grid(alpha=.18);ax.tick_params(labelsize=8)
  if row==0:ax.set_title(title+'\n'+f"{len(a):,} displayed / {len(points[key]):,} samples",fontsize=11)
fig.suptitle('Koivu — same-data geometry diagnostic, NOT a route or clearance map\nFixed FARO-coordinate projections; identical bounds and metre scale in each row',fontsize=15)
cb=fig.colorbar(plt.cm.ScalarMappable(norm=norm,cmap='viridis'),ax=axs,shrink=.65,pad=.015)
cb.set_label('FARO Z coordinate (m); NOT independently verified gravity height')
fig.supxlabel('All surfaces retained before display subsampling; overlapping dots ≠ occupied/free space. No floor band, cleaning, alignment or fitted scale.\nReference covers 29 views only. Every fourth stored sample shown (75% omitted); different upstream representations and sample counts.',fontsize=10)
fig.savefig(OUT/'geometry-comparison.png',dpi=150,facecolor='white')
receipt={'sources':provenance,'boundsMetres':[lo.tolist(),hi.tolist()],'projections':projections,'frame':'unchanged saved FARO metric coordinates','translation':[0,0,0],'additionalTransform':'none','gravityKnown':False,'subsampling':'array[::4], same rule each input, display only','pointSizePointsSquared':.28,'alpha':.55,'cmap':'viridis','colorCoordinate':'FARO Z','colorBoundsMetres':[float(lo[2]),float(hi[2])],'figureInches':[16,9],'dpi':150,'numpy':np.__version__,'matplotlib':matplotlib.__version__,'scriptSHA256':sha(Path(__file__)),'figureSHA256':sha(OUT/'geometry-comparison.png')}
(OUT/'RENDER_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'bounds':receipt['boundsMetres'],'counts':{k:[v['total'],v['displayed'],v['omittedForDisplayOnly']] for k,v in provenance.items()},'png':str(OUT/'geometry-comparison.png')}))
