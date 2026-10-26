"""Plot saved phone map/route/physics trace; no geometry query or route edits."""
import os
os.environ.setdefault('MPLCONFIGDIR','/tmp/koivu-game-matplotlib')
from pathlib import Path
import json,sys,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from matplotlib.patches import Patch,Polygon
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'source'))
from candidate_map import CandidateMap

def main(result_path,output_path):
 result_path=Path(result_path);output_path=Path(output_path)
 result=json.loads(result_path.read_text());route=json.loads((ROOT/'FIRST_ROUTE.json').read_text())
 with np.load(result_path.parent/'ACTOR_TRACE.npz',allow_pickle=False)as a:
  trace=a['trace'];columns=list(a['columns']);x=trace[:,columns.index('x')];z=trace[:,columns.index('z')]
 # This accessor reads only pinned phone masks and pose-frame metadata.
 model=CandidateMap();mask=model.mask;flag=model.flags['lowUnresolvedFlag']
 image=np.zeros(mask.shape,dtype=np.uint8);image[mask]=2;image[mask&flag]=3
 # Non-walkable cells cannot all be called obstacles; retain general blocked/unknown.
 image[~mask]=0
 blockers=model.flags['highObstacle']|model.flags['low1']|model.flags['deepBelow']|model.flags['nearDip']
 image[blockers&~mask]=1
 points=np.vstack((route['start'],route['nativeInitialRoute']['points'],route['goal']))
 lo=model.origin;res=.05;extent=[lo[0],lo[0]+mask.shape[0]*res,-(lo[1]+mask.shape[1]*res),-lo[1]]
 fig,axes=plt.subplots(1,2,figsize=(13,7),constrained_layout=False)
 fig.subplots_adjust(left=.07,right=.99,bottom=.15,top=.84,wspace=.22)
 colors=['#c5c9cf','#98645d','#c4dbca','#f1d777']
 for ax in axes:
  ax.imshow(image.T[::-1],origin='lower',extent=extent,cmap=ListedColormap(colors),vmin=0,vmax=3,interpolation='nearest')
  ax.plot(points[:,0],points[:,2],'--',color='#1565a7',lw=2,label='Native phone-only planned route')
  ax.plot(np.r_[route['start'][0],x],np.r_[route['start'][2],z],color='#cf6500',lw=2.5,label='Actual actor trace')
  ax.scatter(route['start'][0],route['start'][2],s=70,color='#1565a7',label='A: same frozen start')
  ax.scatter(route['goal'][0],route['goal'][2],marker='*',s=140,color='#1565a7',label='B: same frozen goal')
  ax.scatter(x[-1],z[-1],marker='x',s=90,lw=2,color='#be2222',label='Terminal actor position')
  ax.set_aspect('equal');ax.set_xlabel('Game X — nominal phone metres');ax.set_ylabel('Game Z — nominal phone metres')
 axes[0].legend(handles=[Patch(facecolor=colors[0],label='Unsupported/unknown'),Patch(facecolor=colors[1],label='Phone-model blocker'),Patch(facecolor=colors[2],label='Permissive, low flag absent'),Patch(facecolor=colors[3],label='Permissive, low unresolved')],loc='lower right',fontsize=8)
 axes[0].set_title('Provided phone map — permissive diagnostic')
 axes[1].set_xlim(points[:,0].min()-.7,points[:,0].max()+.7);axes[1].set_ylim(points[:,2].min()-.7,points[:,2].max()+.7)
 axes[1].legend(loc='lower right',fontsize=8);axes[1].set_title(f"Actual body {result['actualBodyContactEvents']} hits; margin {result['marginContactEvents']} contacts")
 fig.suptitle(f"Same-route A→B: {result['actualDistanceMetres']:.3f} m moved; {result['status']}",fontsize=14)
 fig.text(.5,.035,'Offline provided-map simulation; unresolved flags are not clearance. Reference world never selects or steers the route.',ha='center',fontsize=9)
 fig.savefig(output_path,dpi=140);plt.close(fig);model.close()
 receipt={'path':output_path.name,'sha256':hashlib.sha256(output_path.read_bytes()).hexdigest(),'resultSHA256':hashlib.sha256(result_path.read_bytes()).hexdigest(),'referenceOverlay':False,'newGeometryEvaluation':False}
 output_path.with_suffix('.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
if __name__=='__main__':main(*sys.argv[1:])
