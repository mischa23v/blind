"""Saved phone-mask and actor trace visualization; no reference geometry read."""
from pathlib import Path
import hashlib,importlib.util,json,sys,math
import numpy as np
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from matplotlib.collections import PolyCollection
from matplotlib.patches import Polygon,Patch
from matplotlib.lines import Line2D
HERE=Path(__file__).resolve().parent;STAGE=HERE.parent;WS=STAGE.parent
PAIR=WS/'blind-corrected-mask-route-comparison-18/paired_adapter.py'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
if sha(PAIR)!='86d4510a3f801a2f5dd303fe184c8fe0f3fb1d1c90b9057ab1665352939d7c04':raise ValueError('frame adapter pin')
s=importlib.util.spec_from_file_location('coverage_pair',PAIR);ad=importlib.util.module_from_spec(s);sys.modules[s.name]=ad;s.loader.exec_module(ad)
old=ad.metadata('old');new=ad.metadata('new');inputs=[PAIR,ad.INPUTS['new']['mask']]
with np.load(ad.INPUTS['new']['mask'],allow_pickle=False)as z:mask=z['walk'];low=z['lowUnresolvedFlag'];obs=z['highObstacle'];support=z['support'];unknown=z['highUnknown']
grid=np.zeros(mask.shape,np.uint8);grid[support]=1;grid[mask]=2;grid[mask&low]=3;grid[obs]=4;grid[unknown]=0
origin=new['lo'][:2]*.05;extent=[origin[0],origin[0]+.05*mask.shape[0],origin[1],origin[1]+.05*mask.shape[1]]
fig,ax=plt.subplots(figsize=(11.5,10));ax.imshow(grid.T,origin='lower',extent=extent,interpolation='nearest',cmap=ListedColormap(['#d4d8dd','#ece6df','#edf3ec','#f4dda6','#b59196']),vmin=0,vmax=4)
# Historical ROI is drawn by full original-to-corrected transform, not guessed rotation.
roi_old=np.array([[-6.5,0,-1],[-3,0,-1],[-3,0,-3.5],[-6.5,0,-3.5]])
roi,_=ad.map_objective(roi_old,old,new);ax.add_patch(Polygon(np.c_[roi[:,0],-roi[:,2]],facecolor='#dc5b6a',alpha=.23,edgecolor='#9d2943',hatch='///',lw=1.5,zorder=3))
ax.text(-4.6,2.1,'EXCLUDED\nwestern ROI',color='#7a1730',fontsize=10,weight='bold',zorder=8)

def draw_trace(base,color,label,z):
 resultpath=base/'RESULT.json';tracepath=base/'ACTOR_TRACE.npz';r=json.loads(resultpath.read_text());inputs.append(resultpath)
 if not tracepath.exists():return r
 inputs.append(tracepath)
 with np.load(tracepath,allow_pickle=False)as data:trace=data['trace'];cols=list(data['columns'])
 states=np.vstack((r['settledStart'],trace[:,[cols.index('x'),cols.index('y'),cols.index('z')]]));yaws=np.r_[json.loads((STAGE/'SELECTED_PLAN.json').read_text())['initialYawRadians'] if base==STAGE/'run-01/result' else trace[0,cols.index('yaw')],trace[:,cols.index('yaw')]]
 # First footprint yaw is transformed via frozen adapter for the new episode.
 if base==STAGE/'run-01/result':
  spec=importlib.util.spec_from_file_location('coverage_gm',STAGE/'goal_region_map.py');gm=importlib.util.module_from_spec(spec);sys.modules[spec.name]=gm;spec.loader.exec_module(gm);yaws[0]=gm.load_plan()['initialYawRadians']
 g=r['geometry'];halfF=g['depth']/2+g['margin'];halfL=g['width']/2+g['margin'];local=np.array([[-halfF,-halfL],[halfF,-halfL],[halfF,halfL],[-halfF,halfL]])
 polygons=[]
 for p,yaw in zip(states,yaws):
  c,ss=math.cos(yaw),math.sin(yaw);xz=np.c_[p[0]+local[:,0]*c-local[:,1]*ss,p[2]+local[:,0]*ss+local[:,1]*c]
  corners=np.c_[xz[:,0],np.full(4,p[1]),xz[:,1]];q,_=ad.map_objective(corners,old,new);polygons.append(np.c_[q[:,0],-q[:,2]])
 ax.add_collection(PolyCollection(polygons,facecolors=color,edgecolors='none',alpha=.10,zorder=z))
 q,_=ad.map_objective(states,old,new);ax.plot(q[:,0],-q[:,2],color=color,lw=2.6,label=label,zorder=z+1)
 if base==STAGE/'run-01/result':ax.scatter(q[0,0],-q[0,2],color=color,marker='o',s=65,zorder=9);ax.scatter(q[-1,0],-q[-1,2],color=color,marker='s',s=65,zorder=9)
 return r
north=draw_trace(WS/'blind-north-goal-region-executor-21/run-01/result','#6a59a6','Prior north: abstract 28 cm, 2.19 m',4)
south=draw_trace(WS/'blind-split-candidate-game-03/camera-approach-executor-14/run-01/result/body45cmMargin0-southSide','#6a59a6','Prior south: nominal 45 cm, ~1.8 m',4)
actual=draw_trace(STAGE/'run-01/result','#087a8b','New actual partial trace (45cm body)',6)
mainpath=WS/'blind-remaining-room-traverse-23/planning-01/result/body45cmMargin0.json';main=json.loads(mainpath.read_text());inputs.append(mainpath)
anchors=np.array([main['startOriginalGameXYZ'],*[a['originalGameXYZ']for a in main['targetAnchors']]]);a,_=ad.map_objective(anchors,old,new);axy=np.c_[a[:,0],-a[:,2]]
ax.plot(axy[1:3,0],axy[1:3,1],':',color='#c56323',lw=2.3,zorder=7,label='Failed task link—not a traversed path')
ax.plot(axy[2:,0],axy[2:,1],':',color='#56616c',lw=1.5,zorder=5,label='Later task links not reached by planning')
for i,label in enumerate(['start92','south120','east200','east220','north20']):
 ax.scatter(*axy[i],s=42,marker='x',color='#333d45',zorder=8);ax.annotate(label,axy[i],xytext=(6,7),textcoords='offset points',fontsize=8,zorder=9)
ax.annotate('South→east: 0/32 centres admitted\nfor each of the 3 profiles',axy[1:3].mean(0),xytext=(-2.2,-4.7),arrowprops={'arrowstyle':'-','color':'#a45724'},color='#8e431b',fontsize=9,bbox={'facecolor':'white','edgecolor':'none','alpha':.9},zorder=10)
smallpath=WS/'blind-small-room-entry-return-24/planning-01/result/body45cmMargin0.json';small=json.loads(smallpath.read_text());inputs.append(smallpath)
p=np.array([small['startOriginalGameXYZ'],small['targetAnchors'][0]['originalGameXYZ']]);q,_=ad.map_objective(p,old,new);xy=np.c_[q[:,0],-q[:,2]];ax.plot(xy[:,0],xy[:,1],':',color='#c56323',lw=2.3,zorder=7)
ax.scatter(*xy.T,marker='x',color='#333d45',s=50,zorder=9);ax.annotate('VARPU inside 160\nentry not admitted; return untested',xy[1],xytext=(2.5,.75),arrowprops={'arrowstyle':'-','color':'#a45724'},fontsize=9,color='#8e431b',bbox={'facecolor':'white','edgecolor':'none','alpha':.9},zorder=10)
ax.annotate('outside 130',xy[0],xytext=(8,-12),textcoords='offset points',fontsize=8,zorder=9)
# Photo/depth threshold line is an association only, not measured clear width.
gate_old=np.array([[2.3258475,-.002443,2.3319689],[2.020146,.0100094,1.6124814]]);gate,_=ad.map_objective(gate_old,old,new);ax.plot(gate[:,0],-gate[:,2],color='#333',lw=3,zorder=8);ax.text(2.4,-2.13,'doorway',fontsize=8,color='#333',zorder=10)
ax.set(xlim=(-4.9,5.7),ylim=(-5.15,4.8),xlabel='Corrected phone level X (nominal metres)',ylabel='Corrected phone level Y (nominal metres)',title='Koivu coverage: a new partial trace, not a room traversal\nPhone-only planning failures and excluded western region remain visible');ax.set_aspect('equal');ax.grid(alpha=.2)
handles,labels=ax.get_legend_handles_labels();handles+=[Patch(facecolor='#f4dda6',label='Unresolved-low phone cells (not cleared)'),Patch(facecolor='#b59196',label='Phone obstacle cells'),Patch(facecolor='#d4d8dd',label='Unknown/unavailable cells')];labels+=[h.get_label()for h in handles[-3:]]
ax.legend(handles,labels,loc='upper right',fontsize=7.4,framealpha=.96)
fig.text(.10,.035,f"New episode: arrived in offline model · {actual['actualDistanceMetres']:.3f} m · body/margin contacts {actual['actualBodyContactEvents']}/{actual['marginContactEvents']} · unresolved-low ticks {actual['ticksWithSampledLowUnresolvedExposure']}/{actual['ticks']}\nFootprint shading shows sampled visited envelopes only. No all-floor-area coverage or physical safety claim. FARO is not drawn.",fontsize=9)
fig.subplots_adjust(bottom=.12,top=.91,left=.09,right=.97);dest=HERE/'room-coverage.png';fig.savefig(dest,dpi=160);plt.close(fig)
(HERE/'PLOT_RECEIPT.json').write_text(json.dumps({'scope':'Saved-data plot only','inputs':{str(p.relative_to(WS)):sha(p)for p in inputs},'imageSHA256':sha(dest),'sourceSHA256':sha(Path(__file__)),'referenceGeometryRead':False,'newNavigationQueries':False,'footprintsSampledNotAreaCoverage':True},indent=2)+'\n');print(dest)
