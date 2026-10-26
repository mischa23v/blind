"""Saved derived-mask arithmetic only; reference columns are evaluator data, not route inputs."""
from pathlib import Path
import ast,contextlib,hashlib,io,json
import numpy as np
from scipy import ndimage
ROOT=Path(__file__).resolve().parent;WS=ROOT.parent
SRC=ROOT/'upstream/scripts/openfloor.py'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):
 with np.load(p,allow_pickle=False)as z:return {k:z[k]for k in z.files}
def score(meta,mask,tag):
 o=load(meta);w=load(mask)['walk'];cov=o['ref_n']>0;res=float(o['res']);lo=o['lo']
 if w.dtype!=bool or w.shape!=cov.shape:raise ValueError('mask association')
 d=ndimage.distance_transform_edt(w)*res;m=w&cov&((o['ref_low_max']>=.025)|(o['ref_body_max']>-np.inf))
 edge=m&(d<=.15);opened=m&(d>.15);idx=np.argwhere(opened)
 # Run the unchanged upstream reporting function as a direct arithmetic cross-check.
 tree=ast.parse(SRC.read_text());func=[n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='report']
 ns=dict(np=np,ndimage=ndimage,cov=cov,low=o['ref_low_max'],body=o['ref_body_max'],lo=lo,RES=res)
 exec(compile(ast.Module(body=func,type_ignores=[]),str(SRC),'exec'),ns)
 buf=io.StringIO()
 with contextlib.redirect_stdout(buf):ns['report'](tag,w)
 # Nominal level-column centres are converted to original phone coordinates at level z=0;
 # these are column-centre correspondences, NOT observed obstacle points.
 level=np.c_[(idx+lo[:2]+.5)*res,np.zeros(len(idx))];phone=(level-o['t'])@o['R']
 rows=[]
 for k,(i,j)in enumerate(idx):rows.append({'IJ':[int(i),int(j)],'levelColumnCentreAtZ0':level[k].tolist(),'phoneColumnCentreAtLevelZ0':phone[k].tolist(),
   'referenceLowMax':float(o['ref_low_max'][i,j])if np.isfinite(o['ref_low_max'][i,j])else None,'referenceBodyMax':float(o['ref_body_max'][i,j])if np.isfinite(o['ref_body_max'][i,j])else None,'EDTMetres':float(d[i,j])})
 return {'label':tag,'metaSHA256':sha(meta),'maskSHA256':sha(mask),'shape':list(w.shape),'lo':lo.tolist(),'R':o['R'].tolist(),'t':o['t'].tolist(),'res':res,
  'walkableCells':int(w.sum()),'noReferenceCoverageWalkable':int((w&~cov).sum()),'edgeMissProxy':int(edge.sum()),'openFloorMissProxy':int(opened.sum()),'openRows':rows,
  'referenceWalkColumns':int(o['refWalk'].sum()),'referenceWalkPhoneBlocked':int((o['refWalk']&~w).sum()),'upstreamPrintedResult':buf.getvalue().strip()},opened,o
def main():
 out=ROOT/'mask-recount-01';out.mkdir(exist_ok=False)
 jobs=[('koivuOriginal',WS/'blind-split-candidate-game-03/inputs/koivu_5cm_v2_pipeline2_out.npz',WS/'blind-split-candidate-game-03/inputs/koivu_5cm_occthres_split0.7.npz'),
 ('koivuFloorfix',ROOT/'upstream/pose-consistency/runs/koivu_floorfix/pipeline2_out.npz',ROOT/'upstream/pose-consistency/runs/koivu_floorfix/occthres_split0.7.npz'),
 ('coffeeFloorfix',ROOT/'upstream/pose-consistency/runs/coffee_floorfix/pipeline2_out.npz',ROOT/'upstream/pose-consistency/runs/coffee_floorfix/occthres_split0.7.npz')]
 files=[Path(__file__),SRC]+[p for _,a,b in jobs for p in [a,b]]
 pins={str(p.relative_to(WS)):sha(p)for p in files};(out/'INPUT_PINS.json').write_text(json.dumps(pins,indent=2)+'\n')
 results=[];arrays=[];metas=[]
 for name,a,b in jobs:r,m,o=score(a,b,name);results.append(r);arrays.append(m);metas.append(o)
 old,new=metas[:2];a,b=arrays[:2];same_domain=a.shape==b.shape and np.array_equal(old['lo'],new['lo']) and old['res']==new['res']
 overlap={'sameDiscreteDomain':bool(same_domain),'sameLevelTransform':bool(np.array_equal(old['R'],new['R'])and np.array_equal(old['t'],new['t']))}
 if same_domain:
  overlap.update(sameIndexOpenMisses=int((a&b).sum()),newIndexOpenMisses=int((b&~a).sum()),removedIndexOpenMisses=int((a&~b).sum()))
  if np.array_equal(a,b):
   ap=np.asarray([r['phoneColumnCentreAtLevelZ0']for r in results[0]['openRows']]);bp=np.asarray([r['phoneColumnCentreAtLevelZ0']for r in results[1]['openRows']]);overlap['sameIndexColumnCentreShiftMetres']=np.linalg.norm(ap-bp,axis=1).tolist()
 result={'scope':'Saved-array reproduction of supplied vertex-column/EDT proxy, not physical safety, collision or route testing','cases':results,'koivuMissAssociation':overlap,
  'limitations':['Reference is a vertex-column proxy; uncovered/unsampled surfaces are not safe.','A miss within15cm of ANY blocked cell is called edge by this metric; that is not an exact body-margin collision proof.','The metric ignores lower-than2.5cm reference low geometry and does not prove toy clearance.','Coffee original arrays were not acquired in this recount; only corrected count is independently recomputed.','Global floor is refitted in each mask; equal cell indices need transformed-frame interpretation.','No raw-depth, native fusion, ICP, reference-mesh load, pose adoption or navigation was performed.']}
 for p,h in pins.items():
  if sha(WS/p)!=h:raise ValueError('input changed')
 (out/'RESULT.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
 print(json.dumps({'cases':[{k:r[k]for k in ['label','walkableCells','edgeMissProxy','openFloorMissProxy','referenceWalkPhoneBlocked']}for r in results],'koivuMissAssociation':overlap}))
if __name__=='__main__':main()
