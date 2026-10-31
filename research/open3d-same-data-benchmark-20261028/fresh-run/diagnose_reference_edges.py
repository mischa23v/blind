"""Post-hoc descriptive strata, not a revised score or acceptance filter."""
from pathlib import Path
import json,sys,importlib.util,numpy as np
R=Path(__file__).resolve().parent;sys.path.insert(0,str(R/'source'));s=importlib.util.spec_from_file_location('held',R/'source/blind-koivu-tsdf-heldout-11-evaluate.py');h=importlib.util.module_from_spec(s);s.loader.exec_module(h)
refs=[];preds=[];edges=[]
for name in json.loads((R/'EVALUATOR_FROZEN.json').read_text())['frameIDs']:
 with np.load(R/'evaluation/faro'/(name+'.npz'),allow_pickle=False)as a,np.load(R/'evaluation/tsdf'/(name+'.npz'),allow_pickle=False)as b:
  ref=a['axialMetres'];pred=b['axialMetres'];refs.append(ref.copy());preds.append(pred.copy());edges.append(h.edges(ref.reshape(249,185)).ravel())
ref=np.concatenate(refs);pred=np.concatenate(preds);edge=np.concatenate(edges);pair=np.isfinite(ref)&np.isfinite(pred);error=pred-ref;rows=[]
for code,label in h.EDGES.items():
 mask=edge==code;p=mask&pair;rows.append({'code':code,'label':label,'scheduled':int(mask.sum()),'paired':int(p.sum()),'statistics':h.stats(error[p]),'absoluteDifferenceAbove10cm':int((np.abs(error[p])>.1).sum()),'absoluteDifferenceAbove50cm':int((np.abs(error[p])>.5).sum())})
assert sum(x['scheduled']for x in rows)==1335885;assert sum(x['paired']for x in rows)==1187988
h.dump(R/'EXPLORATORY_EDGE_STRATA.json',{'postHocDiagnostic':True,'usedForFilteringOrRetuning':False,'edgeDefinition':'existing 4-neighbour difference on stride4 reference-depth raster; excludes no rays from main score','rows':rows,'cannotDistinguishRealChangePoseRegistrationOrReconstructionCauses':True})
print(json.dumps(rows,indent=2))
