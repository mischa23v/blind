"""Read-only plot of frozen phone masks and saved approach traces; no native queries."""
import os
os.environ.setdefault('MPLCONFIGDIR','/tmp/koivu-approach-mpl')
from pathlib import Path
import hashlib,json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from matplotlib.patches import Patch,Rectangle,Circle
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
STAGE=HERE.parent
PROFILES=['body45cmMargin0','body45cmMargin5cm','abstract28cmProfile']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 pins={}; split=ROOT/'inputs/koivu_5cm_occthres_split0.7.npz';meta=ROOT/'inputs/koivu_5cm_v2_pipeline2_out.npz'
 assert sha(split)=='b294d92cfd9136d00de510239c2b85a9d68d878dcf7dac1a64b144d8880cb076'
 assert sha(meta)=='a2fc5c13f86bf7033131347fd9b6d61db23ab716d12d668a3d969b9e87dbf48d'
 pins[str(split.relative_to(ROOT))]=sha(split);pins[str(meta.relative_to(ROOT))]=sha(meta)
 with np.load(split,allow_pickle=False) as a:
  walk=a['walk'];low=a['lowUnresolvedFlag'];block=a['highObstacle']|a['low1']|a['deepBelow']|a['nearDip']
 # Metadata allowlist only; no reference arrays or statistical labels.
 with np.load(meta,allow_pickle=False) as a:lo=a['lo'][:2]*float(a['res']);res=float(a['res'])
 data=[]
 for profile in PROFILES:
  base=STAGE/'run-01/result'/f'{profile}-southSide';rp=base/'RESULT.json';tp=base/'ACTOR_TRACE.npz'
  result=json.loads(rp.read_text())
  with np.load(tp,allow_pickle=False) as a:
   columns=list(a['columns']);trace=a['trace'].copy()
  pins[str(rp.relative_to(ROOT))]=sha(rp);pins[str(tp.relative_to(ROOT))]=sha(tp)
  data.append((result,trace,columns))
 assert all(np.array_equal(data[0][1][:,[2,4,5]],d[1][:,[2,4,5]]) for d in data[1:])
 selected=ROOT/'two-approach-selection-11/run-01/result/body45cmMargin0-southSide.json'
 north=ROOT/'two-approach-selection-11/run-01/result/body45cmMargin0-northSide.json'
 route=json.loads(selected.read_text());n=json.loads(north.read_text())
 pins[str(selected.relative_to(ROOT))]=sha(selected);pins[str(north.relative_to(ROOT))]=sha(north)
 r,tr,cols=data[0];start=np.asarray(route['start']);goal=np.asarray(route['goal'])
 points=np.vstack([start,*route['nativeInitialRoute']['points'],goal]);xy=points[:,[0,2]];xy[:,1]*=-1
 actual=np.vstack([start,tr[:,[cols.index('x'),cols.index('y'),cols.index('z')]]]);actual=actual[:,[0,2]];actual[:,1]*=-1
 image=np.zeros(walk.shape,dtype=np.uint8);image[~walk&block]=1;image[walk]=2;image[walk&low]=3
 colors=['#d1d4d8','#92655f','#c9ddcd','#f5d584']
 extent=[lo[0],lo[0]+walk.shape[0]*res,lo[1],lo[1]+walk.shape[1]*res]
 fig,axes=plt.subplots(1,2,figsize=(13.4,8.4));fig.subplots_adjust(left=.06,right=.99,bottom=.22,top=.87,wspace=.22)
 for ax in axes:
  ax.imshow(image.T,origin='lower',extent=extent,cmap=ListedColormap(colors),vmin=0,vmax=3,interpolation='nearest')
  ax.add_patch(Rectangle((extent[0],1),-3-extent[0],2.5,fill=False,ls=':',ec='#8159a1',lw=1.8))
  ax.plot(xy[:,0],xy[:,1],'--',color='#2268ad',lw=2,label='Fixed phone-only planned path')
  ax.plot(actual[:,0],actual[:,1],color='#e26510',lw=2.7,label='Actual trace (all 3 identical)')
  ax.scatter(actual[0,0],actual[0,1],s=65,color='#2268ad',label='A: fixed camera-anchored start')
  ax.scatter(goal[0],-goal[2],s=140,marker='*',color='#2268ad',label='B: fixed south-side goal')
  ax.add_patch(Circle((goal[0],-goal[2]),.35,fill=False,ec='#2268ad',ls=':',lw=1.2))
  ax.scatter(actual[-1,0],actual[-1,1],s=70,marker='x',lw=2,color='#ba2626',label='Actual stopped position')
  ax.set_aspect('equal');ax.set_xlabel('Level X — nominal phone metres');ax.set_ylabel('Level Y — nominal phone metres')
 # Raw north anchor is shown as a failed selector target, never a simulated route.
 ng=np.asarray(n['sourceAnchors']['goal']['requestedGamePoint'])
 axes[0].scatter(ng[0],-ng[2],marker='X',s=75,color='#8a1679')
 axes[0].annotate('North goal: not executed\nphone association rejected',(ng[0],-ng[2]),xytext=(-.6,4.7),arrowprops={'arrowstyle':'-','color':'#8a1679'},fontsize=8,color='#6d155e')
 axes[0].set_title('Unchanged supplied phone map; dotted box = disputed ROI')
 axes[0].legend(handles=[Patch(facecolor=colors[0],label='Blocked / unsupported / unknown'),Patch(facecolor=colors[1],label='Phone-model blocker'),Patch(facecolor=colors[2],label='Permissive; low flag absent'),Patch(facecolor=colors[3],label='Permissive; low unresolved')],loc='lower right',fontsize=8)
 axes[1].set_xlim(xy[:,0].min()-.85,xy[:,0].max()+.85);axes[1].set_ylim(xy[:,1].min()-.7,xy[:,1].max()+.8)
 axes[1].set_title('South approach: 1.800 m moved; 0 body / margin contacts')
 axes[1].legend(loc='lower left',fontsize=8)
 fig.suptitle('Three profile checks of the same route — all reached the fixed 0.35 m goal tolerance',fontsize=14)
 fig.text(.5,.125,'45×30 cm raw body | same body +5 cm each side (55×40 cm envelope) | abstract 28×30 cm body; all 160 cm high',ha='center',fontsize=9)
 fig.text(.5,.085,'Each: 91 ticks at 15 Hz; final error 0.328 m. All 91 ticks exposed to low-unresolved phone cells.',ha='center',fontsize=9)
 fig.text(.5,.045,'Offline permissive-map diagnostic, shared planar reference-ground physics. No reference overlay; not a loop or live-clearance proof.',ha='center',fontsize=9)
 out=HERE/'south-approach-three-profiles.png';fig.savefig(out,dpi=145);plt.close(fig)
 receipt={'plot':out.name,'sha256':sha(out),'sourceSHA256':sha(Path(__file__)),'inputs':pins,'newGeometryQueries':False,'referenceOverlay':False,'differentRoutes':1,'executedProfiles':3,'unexecutedNorthSlots':3,'allXZAndYawTracesIdentical':True,'physicalAuthority':False}
 (HERE/'PLOT_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
if __name__=='__main__':main()
