"""Exact saved-array association only; no mesh, new scoring, routing or map edit."""
from pathlib import Path
import json,hashlib,time,resource
import numpy as np
HERE=Path(__file__).resolve().parent;GAME=HERE.parent;WS=GAME.parent
AUDIT=WS/'blind-opus-reference-scoring-audit-02'
PATHS={
'oldPhoneArtifact':AUDIT/'artifacts/koivu_v1_pipeline_out.npz',
'currentFrameMetadata':GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz',
'currentPhoneMask':GAME/'inputs/koivu_5cm_occthres_split0.7.npz',
'fixedDepthCells':GAME/'body-margin-variants-07/diagnosis/west-depth-run-01/result/RESULT.json',
'savedTriangles':AUDIT/'run-01/result/TRIANGLE_BANDS.npz',
'savedVertices':AUDIT/'run-01/result/REFERENCE_VERTEX_BANDS.npz',
'savedSummary':AUDIT/'run-01/result/SUMMARY.json'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def nullable(x):return float(x)if np.isfinite(x)else None

def main():
 start=time.monotonic();pins={k:{'path':str(p.relative_to(WS)),'sha256':sha(p)}for k,p in PATHS.items()}
 source=json.loads(PATHS['fixedDepthCells'].read_text());summary=json.loads(PATHS['savedSummary'].read_text())
 with np.load(PATHS['oldPhoneArtifact'],allow_pickle=False)as old,np.load(PATHS['currentFrameMetadata'],allow_pickle=False)as new,np.load(PATHS['currentPhoneMask'],allow_pickle=False)as current:
  matches={k:bool(np.array_equal(old[k],new[k]))for k in ('R','t','lo')}
  if not all(matches.values()):raise ValueError('reference frame association differs; no join allowed')
  shape=old['walk'].shape
  if current['walk'].shape!=shape:raise ValueError('grid shape mismatch')
  for row in source['cells']:
   i,j=row['sourceIJ'];expected=(np.array([i,j])+new['lo'][:2]+.5)*.05
   if not np.allclose(expected,row['sourceCellCentreXY'],atol=1e-12,rtol=0):raise ValueError('fixed cell centre association mismatch')
   if any(bool(current[k][i,j])!=value for k,value in row['flags'].items()):raise ValueError('phone flag mismatch')
 with np.load(PATHS['savedTriangles'],allow_pickle=False)as t,np.load(PATHS['savedVertices'],allow_pickle=False)as v:
  lookup={tuple(c):k for k,c in enumerate(t['columns'])}
  if len(lookup)!=len(t['columns']):raise ValueError('duplicate saved triangle columns')
  rows=[]
  for src in source['cells']:
   i,j=src['sourceIJ'];index=lookup.get((i,j));row={'sourceIJ':[i,j],'sourceCellCentreXY':src['sourceCellCentreXY'],'phoneFlags':src['flags'],'cameraFrameRecords':src['cameraFrameRecords'],
    'anyReferenceVertexCount':int(v['anyVertexCount'][i,j]),'referenceBandVertexCounts':v['bandVertexCounts'][:,i,j].tolist(),
    'referenceFloorBandVertexCount':int(v['floorBandVertexCount'][i,j]),'referenceFloorBandMeanHeight':nullable(v['floorBandMeanHeight'][i,j]),
    'savedTriangleColumnAvailable':index is not None,'savedTriangleContacts':None,'savedFloorProbeHits':None,'savedFloorProbeHeights':None}
   if index is not None:row.update(savedTriangleContacts=t['contacts'][index].tolist(),savedFloorProbeHits=int(t['floorProbeHits'][index]),savedFloorProbeHeights=[nullable(x)for x in t['floorProbeHeights'][index]])
   rows.append(row)
 counts={}
 for label,predicate in [('blocked',lambda r:not r['phoneFlags']['walk']),('walkableControls',lambda r:r['phoneFlags']['walk']),('low1Blocked',lambda r:not r['phoneFlags']['walk']and r['phoneFlags']['low1']),('missingSupportBlocked',lambda r:not r['phoneFlags']['walk']and not r['phoneFlags']['support'])]:
  selected=[r for r in rows if predicate(r)]
  counts[label]={'cells':len(selected),'savedTriangleColumns':sum(r['savedTriangleColumnAvailable']for r in selected),'vertexOnlyColumns':sum(not r['savedTriangleColumnAvailable']for r in selected),'anyVertexColumns':sum(r['anyReferenceVertexCount']>0 for r in selected),'floorBandVertexColumns':sum(r['referenceFloorBandVertexCount']>0 for r in selected),'bandPositiveVertexColumns':np.sum([np.array(r['referenceBandVertexCounts'])>0 for r in selected],axis=0,dtype=int).tolist()if selected else[0]*6}
 result={'scope':'Exact same-frame saved-reference association for all fixed western phone cells, not new reference queries','inputPins':pins,'frameExactMatch':matches,'gridShape':list(shape),'gridResolutionMetres':.05,'bandNames':summary['bandNames'],'bandsMetres':summary['bandsMetres'],'vertexBandsHalfOpen':True,'triangleBandsClosed':True,'floorVertexBandOpenMetres':[-.06,.06],'uniqueCells':len(rows),'groups':counts,'rows':rows,'noVertexIsNotFree':True,'savedTriangleAbsenceIsNotNoContact':True,'referenceMeasuredSupportMaskAvailable':False,'nearFloorPositiveGeometryMayBeRegisteredFloorNotObstacle':True,'referenceCleanedCompletedAndDifferentCaptureTime':True,'referenceQueries':0,'mapEdits':0,'newRoutes':0,'physicalAuthority':False,'schemaProbeNote':'Initial exploratory print requested walk from metadata-only current archive and raised KeyError after confirming R/t/lo; this join reads walk from the separate pinned mask. No prior scoring or data was changed.','wallSeconds':time.monotonic()-start,'peakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024}
 if any(sha(PATHS[k])!=v['sha256']for k,v in pins.items()):raise ValueError('input changed during join')
 (HERE/'RESULT.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n');print(json.dumps({'frameExactMatch':matches,'groups':counts,'wallSeconds':result['wallSeconds'],'peakRSSBytes':result['peakRSSBytes']}))
if __name__=='__main__':main()
