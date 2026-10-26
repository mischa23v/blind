"""Frozen TSDF versus unchanged saved reference rays; no full FARO mesh is opened."""
from pathlib import Path
import argparse,json,os,resource,sys,time
import numpy as np
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'blind-koivu-tsdf-heldout-11'))
from evaluate import stats, masks, validate_mesh, dump, digest, RANGES, EDGES
from reference_geometry import ReferenceSurface, checked_camera, camera_rays, convention_tests, serial_vtk
# The import above resolves this file's sibling-stage module as 'evaluate'; this file
# is invoked as __main__. Neither imported module runs its main() on import.

def summarize(reference,predicted,edge):
 reference=np.asarray(reference,float);predicted=np.asarray(predicted,float);edge=np.asarray(edge)
 rv=np.isfinite(reference)&(reference>0);pv=np.isfinite(predicted)&(predicted>0);paired=rv&pv;error=predicted-reference
 counts={'scheduled':int(reference.size),'paired':int(paired.sum()),'referenceOnly':int((rv&~pv).sum()),'TSDFOnly':int((~rv&pv).sum()),'neither':int((~rv&~pv).sum())}
 assert sum(counts[k]for k in ['paired','referenceOnly','TSDFOnly','neither'])==reference.size
 assert np.isin(edge,list(EDGES)).all() and np.array_equal(edge==-1,~rv)
 def subset(m):
  return {'scheduled':int(m.sum()),'referenceValid':int((m&rv).sum()),'TSDFHit':int((m&pv).sum()),'statistics':stats(error[m&paired])}
 ranges=[{'label':label,**subset(m)}for label,m in zip(RANGES,masks(reference))]
 assert sum(x['referenceValid']for x in ranges)==int(rv.sum())
 edge_rows=[{'label':label,'code':code,**subset(edge==code)}for code,label in EDGES.items()]
 assert sum(x['scheduled']for x in edge_rows)==reference.size
 return {'availability':counts,'allPairedStatistics':stats(error[paired]),'referenceBelow4Statistics':stats(error[paired&(reference<4)]),'reference4AndAboveStatistics':stats(error[paired&(reference>=4)]),'byReferenceDepth':ranges,'bySavedReferenceEdge':edge_rows}

def conventions():
 result=convention_tests()
 r=np.array([1.,2.,np.nan,np.nan]);p=np.array([4.,np.nan,3.,np.nan]);edge=np.array([2,2,-1,-1])
 a=summarize(r,p,edge)
 assert a['availability']=={'scheduled':4,'paired':1,'referenceOnly':1,'TSDFOnly':1,'neither':1}
 assert a['allPairedStatistics']['meanSigned']==3 and a['referenceBelow4Statistics']['count']==1
 result['tests'].append({'name':'saved_reference_four_way_availability_and_mesh_minus_reference_sign','passed':True})
 result['scope']='analytic fixtures only; no recorded reference or TSDF read';return result

def main():
 if sys.flags.optimize:raise RuntimeError('assertions must remain active')
 ap=argparse.ArgumentParser();ap.add_argument('--mode',choices=['conventions','evaluate'],required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--frozen',type=Path,required=True);ap.add_argument('--frozen-sha',required=True);args=ap.parse_args()
 assert len(args.frozen_sha)==64 and digest(args.frozen)==args.frozen_sha
 spec=json.loads(args.frozen.read_text());paths=spec['paths'];out=args.output;out.mkdir(exist_ok=False)
 allowed=sorted(os.sched_getaffinity(0));os.sched_setaffinity(0,{allowed[0]})
 if args.mode=='conventions':dump(out/'result.json',conventions());return
 runtime=serial_vtk();runtime.update(numpyVersion=np.__version__,pythonVersion=sys.version);started=time.monotonic()
 def emit(item):print(json.dumps(dict(item,wallSeconds=time.monotonic()-started,CPUSeconds=time.process_time(),peakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024)),flush=True)
 ids=spec['frameIDs'];expected=[f'frame_{i:05d}'for i in (1,5,9,13,17,21,25,29)];assert ids==expected
 original=json.loads(Path(paths['pose']).read_text());by_name={Path(f['file_path']).stem:f for f in original['frames']};assert len(by_name)==294
 previous=json.loads(Path(paths['referenceResult']).read_text());association=json.loads(Path(paths['associationReport']).read_text());receipt=json.loads(Path(paths['referenceReceipt']).read_text())
 assert previous['fixedIndices']==[0,4,8,12,16,20,24,28] and previous['pixelOffset']==.5 and previous['totals']['scheduled']==368520
 assert receipt['sourceAndInputHashesVerifiedBeforeAndAfter']
 associated={f['basename']:f for f in association['frames']};assert set(associated)==set(ids)
 assert all(f['originalVsAssociatedPoseMaxDifference']==0 and f['originalVsAssociatedCalibrationMaxDifference']==0 for f in associated.values())
 training=json.loads(Path(paths['trainingFreeze']).read_text());trained={f['frameID']for f in training['trainingFrames']}
 assert [f for f in ids if f not in trained]==['frame_00021']
 mesh,mesh_report=validate_mesh(paths['mesh']);dump(out/'MESH_READER_REPORT.json',mesh_report)
 surface=ReferenceSurface(mesh,progress=emit)
 rr,cc=np.meshgrid(np.arange(0,994,4),np.arange(0,738,4),indexing='ij');assert rr.shape==(249,185) and rr.size==46065
 refs=[];preds=[];edges=[];rows=[];artifacts=[]
 for i,name in enumerate(ids):
  path=Path(paths['savedReferenceDirectory'])/(name+'-scheduled-rays.npz')
  with np.load(path,allow_pickle=False)as z:
   assert np.array_equal(z['row'],rr) and np.array_equal(z['column'],cc)
   reference=z['referenceAxialRegisteredNominalMetres'].copy();edge=z['referenceEdgeCategory'].copy();ref_cells=z['referenceCellID'].copy()
  assert reference.shape==rr.shape and reference.dtype==np.float64 and edge.shape==rr.shape and ref_cells.shape==rr.shape
  rv=np.isfinite(reference);assert np.all(reference[rv]>0) and np.array_equal(rv,ref_cells>=0) and (ref_cells[~rv]==-1).all()
  f=by_name[name];assert(f['h'],f['w'])==(994,738)
  pose,pose_check=checked_camera(f['transform_matrix']);ray=camera_rays(rr.ravel(),cc.ravel(),*[f[k]for k in ('fl_x','fl_y','cx','cy')])
  predicted,cells,query=surface.query(pose,np.eye(4),ray,label=name);predicted=predicted.reshape(rr.shape);cells=cells.reshape(rr.shape)
  assert np.array_equal(np.isfinite(predicted),cells>=0) and np.all(predicted[np.isfinite(predicted)]>0)
  query={k.replace('Faro','PhoneMap'):v for k,v in query.items()};query['rayTransform']='identity @ original camera_to_phone';query['FAROScaleAppliedAgain']=False
  metric=summarize(reference,predicted,edge)
  row={'frameID':name,'index':i,'usedByTSDFIntegration':name in trained,'poseCheck':pose_check,'query':query,**metric};rows.append(row);dump(out/(name+'-metrics.json'),row)
  p=out/(name+'-rays.npz');np.savez_compressed(p,row=rr.astype(np.uint16),column=cc.astype(np.uint16),savedReferenceAxialMetres=reference,predictedTSDFLocalAxialMetres=predicted,TSDFCellID=cells,referenceCellID=ref_cells,savedReferenceEdgeCode=edge)
  artifacts.append({'path':p.name,'bytes':p.stat().st_size,'sha256':digest(p)})
  refs.append(reference.ravel());preds.append(predicted.ravel());edges.append(edge.ravel());emit({'phase':'frame_complete','frameID':name,**metric['availability'],'statistics':metric['allPairedStatistics']})
 pooled=summarize(np.concatenate(refs),np.concatenate(preds),np.concatenate(edges));assert pooled['availability']['scheduled']==368520
 result={'scope':'Frozen phone-derived TSDF versus saved author-processed FARO-mesh rays; mostly integrated views; not absolute accuracy, clearance or navigation','frameIDs':ids,'frameCount':8,'integratedViewCount':7,'excludedViewCount':1,'sampleStride':4,'pixelOffset':.5,'residualSign':'TSDF axial depth minus saved reference axial depth','runtime':runtime,'mesh':mesh_report,'pooledRayWeighted':pooled,'frames':rows,'artifacts':artifacts,'fullFAROMeshOpened':False,'referenceRaysRecomputed':False,'referenceScaleAppliedAgain':False,'meshChanged':False,'fittingPerformed':False,'savedSensorDepthUsedToSelectRays':False,'missingGeometryImpliesFree':False,'referenceMeasuredVersusEditedMaskAvailable':False,'originalConfidence':'unavailable and not fabricated','originalTracking':'unavailable and not fabricated','physicalAuthority':False,'navigationCalled':False}
 dump(out/'result.json',result);emit({'phase':'complete',**pooled['availability'],'statistics':pooled['allPairedStatistics']})
if __name__=='__main__':main()
