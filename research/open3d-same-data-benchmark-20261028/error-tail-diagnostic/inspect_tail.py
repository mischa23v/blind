from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy.ndimage import label
R=Path(__file__).resolve().parent;F=R.parent/'fresh-run';B=F/'inputs/room_datasets/koivu/iphone/long_capture'
def stats(a):
 a=a[np.isfinite(a)]
 return {'count':int(a.size),'median':float(np.median(a)) if len(a)else None,'p95':float(np.quantile(a,.95))if len(a)else None,'mean':float(np.mean(a))if len(a)else None}
results=[]
for name in ['frame_00228','frame_00197','frame_00031']:
 with np.load(F/'evaluation/tsdf'/(name+'.npz'))as x:row=x['row'].copy();col=x['column'].copy();td=x['axialMetres'].copy()
 with np.load(F/'evaluation/faro'/(name+'.npz'))as x:assert np.array_equal(row,x['row'])and np.array_equal(col,x['column']);fd=x['axialMetres'].copy()
 image=np.asarray(Image.open(R/'local-rgb'/(name+'.jpg')));sensor=np.asarray(Image.open(B/'depth'/(name+'.png')))[row,col]/1000
 assert image.shape[:2]==(994,738)
 paired=np.isfinite(td)&np.isfinite(fd);delta=td-fd;large=paired&(abs(delta)>.5);shape=(249,185)
 rec={'frame':name,'paired':int(paired.sum()),'largeOver50cm':int(large.sum()),'largeEarlier':int((large&(delta<0)).sum()),'largeLater':int((large&(delta>0)).sum()),'overallAbsolute':stats(abs(delta[paired])),'grid3x3':[],'largestComponents':[]}
 for y in range(3):
  for x in range(3):
   m=(row>=y*994/3)&(row<(y+1)*994/3)&(col>=x*738/3)&(col<(x+1)*738/3);q=m&paired;l=m&large
   rec['grid3x3'].append({'rowThird':y,'columnThird':x,'paired':int(q.sum()),'large':int(l.sum()),'absolute':stats(abs(delta[q])),'signed':stats(delta[q])})
 lab,n=label(large.reshape(shape));counts=np.bincount(lab.ravel());counts[0]=0
 for idx in np.argsort(counts)[-8:][::-1]:
  if counts[idx]==0:continue
  m=lab.ravel()==idx;sm=m&(sensor>0);rec['largestComponents'].append({'sampleCount':int(m.sum()),'pixelBounds':[int(col[m].min()),int(row[m].min()),int(col[m].max()),int(row[m].max())],'tsdfAxial':stats(td[m]),'faroAxial':stats(fd[m]),'sensorAxial':stats(sensor[sm]),'signed':stats(delta[m]),'absTsdfSensor':stats(abs(td[sm]-sensor[sm])),'absFaroSensor':stats(abs(fd[sm]-sensor[sm]))})
 plt.rcParams.update({'font.size':9}); fig,axs=plt.subplots(1,5,figsize=(18,7),constrained_layout=True)
 axs[0].imshow(image);axs[0].set_title('Original public RGB')
 for ax,data,title in zip(axs[1:4],[sensor,td,fd],['Recorded sensor depth','Open3D first hit','FARO first hit']):
  im=ax.imshow(np.where(data>0,data,np.nan).reshape(shape),extent=(0,738,994,0),vmin=0,vmax=6,cmap='viridis');ax.set_title(title+' (m)')
 im=axs[4].imshow(delta.reshape(shape),extent=(0,738,994,0),vmin=-1,vmax=1,cmap='coolwarm');axs[4].set_title('Open3D − FARO (m)\ncolour clipped ±1\nwhite=no paired hit')
 for ax in axs:ax.set_xlim(0,738);ax.set_ylim(994,0);ax.set_xticks([0,246,492,738]);ax.set_yticks([0,331,663,994]);ax.grid(alpha=.2)
 fig.suptitle(name+' — post-hoc diagnostic; same pixel grid; no rescaling, fitting or filtering of main score')
 fig.colorbar(im,ax=axs[4],shrink=.55,pad=.02); fig.savefig(R/'local-figures'/(name+'.png'),dpi=110);plt.close(fig);results.append(rec)
(R/'REGIONAL_RESULTS.json').write_text(json.dumps({'postHoc':True,'physicalHazardLabels':False,'frames':results},indent=2)+'\n')
print(json.dumps(results,indent=2))
