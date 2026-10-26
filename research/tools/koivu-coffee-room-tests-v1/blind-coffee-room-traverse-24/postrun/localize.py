from pathlib import Path
import importlib.util,json,hashlib,math
import numpy as np
from scipy import ndimage,sparse
from scipy.sparse.csgraph import shortest_path
ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('coffee_localize',ROOT/'coffee_routes.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
flags,meta=m.phone_inputs();mask=flags['walk'];origin=meta['lo'][:2]*.05
end=json.loads((ROOT/'ENDPOINTS.json').read_text());ij=np.asarray([p['sourceIJ']for p in end['endpoints']]);xy=np.asarray([p['levelXYMetres']for p in end['endpoints']])
d=ndimage.distance_transform_edt(np.pad(mask,1))[1:-1,1:-1]*.05-.05*np.sqrt(2)/2
reports=[]
for conn in (1,2):
 st=ndimage.generate_binary_structure(2,conn)
 for radius in (0.,.15,.225,.275):
  a,n=ndimage.label(mask&(d>=radius),st);reports.append({'connectivity':4 if conn==1 else 8,'clearanceLowerBoundThresholdMetres':radius,'componentCount':int(n),'endpointComponentIDs':a[ij[:,0],ij[:,1]].tolist()})
 levels=np.unique(d[mask]);left=0;right=len(levels)-1
 def connected(q):
  a,_=ndimage.label(mask&(d>=q),st);return a[tuple(ij[0])]>0 and a[tuple(ij[0])]==a[tuple(ij[2])]
 while left<right:
  mid=(left+right+1)//2
  if connected(levels[mid]):left=mid
  else:right=mid-1
 reports.append({'connectivity':4 if conn==1 else 8,'pointGridEndpointPair':[0,2],'maximumRetainedClearanceThresholdMetres':float(levels[left]),'nextThresholdMetres':float(levels[left+1]) if left+1<len(levels)else None})
 if conn==1:critical=float(levels[left])
allowed=mask&(d>=critical);cells=np.argwhere(allowed);index=np.full(mask.shape,-1,int);index[allowed]=np.arange(len(cells));rows=[];cols=[]
for a,b in ((1,0),(0,1)):
 q=cells+np.array([a,b]);inside=(q[:,0]<mask.shape[0])&(q[:,1]<mask.shape[1]);p=cells[inside];q=q[inside];use=allowed[q[:,0],q[:,1]];rows.extend(index[p[use,0],p[use,1]].tolist());cols.extend(index[q[use,0],q[use,1]].tolist())
r=np.asarray(rows+cols);c=np.asarray(cols+rows);g=sparse.csr_matrix((np.ones(len(r)),(r,c)),shape=(len(cells),len(cells)))
start=index[tuple(ij[0])];goal=index[tuple(ij[2])];dist,pred=shortest_path(g,indices=int(start),unweighted=True,return_predecessors=True,directed=False)
path=[int(goal)]
while path[-1]!=start:
 p=int(pred[path[-1]])
 if p<0:raise ValueError('no witness')
 path.append(p)
path=cells[path[::-1]];critical_cells=path[np.isclose(d[path[:,0],path[:,1]],critical,rtol=0,atol=1e-12)]
near=np.zeros(mask.shape,bool)
for i,j in critical_cells:near[max(0,i-3):i+4,max(0,j-3):j+4]=True
blocked=near&~mask;count={k:int((blocked&v).sum())for k,v in flags.items()};count['missingSupport']=int((blocked&~flags['support']).sum());accounted=(~flags['support'])|flags['deepBelow']|flags['nearDip']|flags['low1']|flags['highObstacle']|flags['highUnknown'];count['blockedWithNoExportedBlockingFlag']=int((blocked&~accounted).sum())
routes={p.name:json.loads(p.read_text()) for p in (ROOT/'run-01/result').glob('*Profile.json')}
allprofiles=[]
for p in (ROOT/'run-01/result').glob('*.json'):
 z=json.loads(p.read_text())
 if 'routes'not in z:continue
 inc=[r for r in z['routes'] if r['nativeAndOriginalRectangleResult']['reason']=='incomplete'];allprofiles.append({'profile':z['summary']['profile'],'incompletePairs':[[r['startEndpointID'],r['goalEndpointID']]for r in inc],'maximumIncompletePairHorizontalAssociationMetres':max(r[a]['horizontalDisplacementMetres']for r in inc for a in ['startAssociation','goalAssociation']),'allIncompleteNativeStatus':sorted(set(r['nativeAndOriginalRectangleResult']['nativeStatus']for r in inc)),'verticalProjectionMetres':sorted(set(r[a]['verticalDisplacementMetres']for r in inc for a in ['startAssociation','goalAssociation']))})
result={'phoneOnlyPostrunDiagnostic':True,'routePolicyChanged':False,'movementEpisodesExecuted':0,'semanticDoorwayOrObjectIdentified':False,'orientationAwareAlternativePlannerRun':False,'allIncompleteCrossGroups':[[0,1,5,6],[2,3,4]],'profiles':allprofiles,'componentDiagnostics':reports,'criticalClearanceLowerBoundMetres':critical,'pointWitnessSourceIJ':path.tolist(),'minimumClearanceWitnessCellsSourceIJ':critical_cells.tolist(),'minimumClearanceWitnessCellsLevelXYMetres':(origin+(critical_cells+.5)*.05).tolist(),'criticalWitnessCellFlags':[{k:bool(v[i,j])for k,v in flags.items()}for i,j in critical_cells],'criticalWitness15cmSquareNeighborhood':{'allCells':int(near.sum()),'walkCells':int((near&mask).sum()),'blockedCells':int(blocked.sum()),'overlappingBlockedFlagCounts':count,'lowUnresolvedWalkCells':int((near&flags['lowUnresolvedFlag']).sum())},'limit':'Conservative grid-centre clearance topology only; not native polygon enumeration, exact physical passage width, rectangular fit impossibility, continuous body route or collision validation. The point witness does not replace any rejected native route.'}
(ROOT/'postrun/LOCALIZATION.json').write_text(json.dumps(result,indent=2)+'\n')
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
fig,axs=plt.subplots(1,2,figsize=(13,7),constrained_layout=True);ext=[origin[0],origin[0]+mask.shape[0]*.05,origin[1],origin[1]+mask.shape[1]*.05]
# Hierarchical display only; JSON preserves overlapping blocker flags.
state=np.zeros(mask.shape,int);state[flags['support']]=1;state[flags['highObstacle']]=2;state[mask]=3;state[flags['lowUnresolvedFlag']]=4
axs[0].imshow(state.T,origin='lower',extent=ext,interpolation='nearest',cmap=ListedColormap(['#d6d9dc','#8b95a1','#384b5e','#f8fafc','#ffdb8a']),vmin=0,vmax=4)
p=origin+(path+.5)*.05;cr=origin+(critical_cells+.5)*.05
axs[0].plot(p[:,0],p[:,1],color='#c13ec8',lw=1.3,label='Point-grid witness, NOT a body route');axs[0].scatter(cr[:,0],cr[:,1],s=45,c='#d6154d',marker='s',label='Minimum-clearance witness cells')
axs[0].set_title('Coffee: raw phone mask and point connectivity\nOrange = retained low-unresolved walk cells')
comp,n=ndimage.label(mask&(d>=.15),ndimage.generate_binary_structure(2,1));display=np.zeros(mask.shape,int);display[mask]=1;display[comp==comp[tuple(ij[0])]]=2;display[comp==comp[tuple(ij[2])]]=3
axs[1].imshow(display.T,origin='lower',extent=ext,interpolation='nearest',cmap=ListedColormap(['#d6d9dc','#f8fafc','#78b7eb','#87c7a2']),vmin=0,vmax=3)
axs[1].set_title('0.15 m EDT centre-clearance diagnostic\nEven abstract-profile endpoints separate into two groups')
for ax in axs:
 for n,(x,y)in enumerate(xy):
  ax.scatter([x],[y],s=30,c='#18212b',zorder=5);delta=.10 if n!=6 else -.22;ax.text(x+.07,y+delta,str(n),fontsize=10,fontweight='bold',color='#18212b',bbox={'facecolor':'white','edgecolor':'none','pad':1,'alpha':.8})
 ax.set_xlabel('Level X (m)');ax.set_ylabel('Level Y (m)');ax.set_aspect('equal')
axs[0].legend(loc='lower left',fontsize=8)
fig.suptitle('Frozen coffee endpoints: local routes exist, broad cross-group routes are incomplete\nStatic supplied phone map only — zero movement or FARO triangle-scored episodes',fontsize=13)
fig.savefig(ROOT/'postrun/COFFEE_FAILURE_LOCALIZATION.png',dpi=140);plt.close(fig)
print(json.dumps({k:v for k,v in result.items() if k not in ('pointWitnessSourceIJ','profiles','criticalWitnessCellFlags')},indent=2))
