"""Saved-array conditional frame disagreement; never reclassifies any geometry."""
from pathlib import Path
import hashlib,json
import numpy as np
ROOT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def stats(x):
 return {'n':len(x),'p05_p50_p95Metres':np.percentile(x,[5,50,95]).tolist()if len(x)else None}
def main():
 run=ROOT/'west-depth-run-01/result';a=json.loads((run/'RESULT.json').read_text())
 with np.load(run/'SELECTED_ENDPOINTS.npz',allow_pickle=False)as z:d={k:z[k]for k in z.files}
 heights=d['level'][:,2];band=(heights>=-.1)&(heights<=.1)
 lowcells=[c for c in a['cells']if c['flags']['low1']and not c['flags']['walk']]
 percell=[];selection=np.zeros(len(heights),bool)
 for c in lowcells:
  i,j=c['sourceIJ'];m=(d['i']==i)&(d['j']==j);selection|=m
  near=m&band&(d['range']<=2);far=m&band&(d['range']>2)
  percell.append({'sourceIJ':[i,j],'near':stats(heights[near]),'far':stats(heights[far]),'nearMinusFarMedianMetres':float(np.median(heights[near])-np.median(heights[far]))if near.any()and far.any()else None})
 perframe=[]
 for fi in np.unique(d['frame'][selection&band]):
  m=selection&band&(d['frame']==fi);n=m&(d['range']<=2)
  perframe.append({'poseIndex':int(fi),'allRanges':stats(heights[m]),'atMost2m':stats(heights[n]),'nearSourceCells':np.unique(np.c_[d['i'][n],d['j'][n]],axis=0).tolist()})
 # Human visual inspection uses untouched original bytes, no generated imagery.
 ws=ROOT.parents[2];images=ws/'blind-open3d-author-baseline-10/author-inputs/selected/images'
 originals=[]
 for name,pixels in [('frame_00062.jpg',[[931,3],[903,23],[871,55]]),('frame_00064.jpg',[[983,179],[955,207],[927,255]])]:
  p=images/name;originals.append({'path':str(p.relative_to(ws)),'sha256':sha(p),'pixelRowCol':pixels,'visualInspection':'Representative measured endpoint pixels are on visibly carpet-like red surface, not an apparent wheel/toy. Visual appearance is not metric floor truth or hazard clearance.'})
 result={'scope':'Derived saved-array cross-view residual diagnosis, no data rerender/fusion/route/reference','inputs':{p.name:sha(p)for p in [run/'RESULT.json',run/'SELECTED_ENDPOINTS.npz',Path(__file__)]},
 'diagnosticHeightWindowMetres':[-.1,.1],'heightWindowChangesMap':False,'allRawEndpointsRetained':True,'low1Cells':len(lowcells),'perCellConditionalComparison':percell,'perFrameConditionalComparison':perframe,'untouchedOriginalVisualInspection':originals,
 'limitations':['Conditional heights within +/-10 cm exclude all other recorded returns only for this distribution report; raw arrays and classification remain unchanged.','Same map column does not guarantee the same physical surface across views; pose/depth error, occlusion, changing foreground and real small objects remain alternatives.','Near/far view populations differ; this is not an independent sensor-error estimate or evidence to erase low objects.']}
 (ROOT/'WESTERN_CROSS_VIEW_SAVED_ARRAYS.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({'pairedNearFarCells':sum(x['nearMinusFarMedianMetres']is not None for x in percell),'perCellMedianShifts':[x['nearMinusFarMedianMetres']for x in percell],'nearFrames':[x for x in perframe if x['atMost2m']['n']]}))
if __name__=='__main__':main()
