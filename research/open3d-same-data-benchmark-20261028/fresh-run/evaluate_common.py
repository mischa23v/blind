"""Frozen 29-view registered-reference comparison using existing VTK first-hit query code."""
from pathlib import Path
import sys,os,json,time,hashlib,importlib.util,gc
import numpy as np
import vtk
R=Path(__file__).resolve().parent;sys.path.insert(0,str(R/'source'))
from reference_geometry import ReferenceSurface,checked_camera,checked_similarity,serial_vtk,convention_tests
spec=importlib.util.spec_from_file_location('heldout',R/'source/blind-koivu-tsdf-heldout-11-evaluate.py');held=importlib.util.module_from_spec(spec);spec.loader.exec_module(held)
BASE=R/'inputs/room_datasets/koivu/iphone/long_capture'
def digest(p):return held.digest(p)
def dump(p,j):held.dump(p,j)
def main(mode):
 os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});runtime=serial_vtk();out=R/'evaluation'/mode;out.mkdir(parents=True,exist_ok=False)
 protocol=json.loads((R/'EVALUATOR_FROZEN.json').read_text());pins=protocol['pins'];
 for p,h in pins.items():assert digest(p)==h
 ids=protocol['frameIDs'];train=json.loads((R/'FUSION_FROZEN.json').read_text());assert ids==train['excludedTestIDs'] and len(ids)==29 and not set(ids)&{r['frameID']for r in train['trainingFrames']}
 frames=json.loads((BASE/'transformations.json').read_text())['frames'];byname={Path(x['file_path']).stem:x for x in frames};assert len(byname)==294
 tests=held.conventions();tests['referenceHelperConventions']=convention_tests();dump(out/'CONVENTIONS.json',tests)
 path=R/'fusion/unfiltered-tsdf-mesh.ply' if mode=='tsdf' else R/'inputs/room_datasets/koivu/gt_mesh.ply'
 errors=[];reader=vtk.vtkPLYReader();reader.AddObserver('ErrorEvent',lambda *a:errors.append(str(a)));reader.SetFileName(str(path));reader.Update();assert not errors
 mesh=reader.GetOutput();assert mesh.GetNumberOfPoints()>0 and mesh.GetNumberOfCells()>0
 mesh.GetPointData().Initialize();mesh.GetCellData().Initialize()
 def progress(x):print(json.dumps(x),flush=True)
 surface=ReferenceSurface(mesh,progress=progress)
 transform=np.eye(4) if mode=='tsdf' else np.asarray(json.loads((R/'inputs/room_datasets/koivu/icp_iphone.json').read_text())['gt_transformation'])
 transform,transformcheck=checked_similarity(transform)
 rr,cc=np.meshgrid(np.arange(0,994,4),np.arange(0,738,4),indexing='ij');assert rr.size==46065
 records=[]
 for i,name in enumerate(ids):
  f=byname[name];assert (f['h'],f['w'])==(994,738);pose,check=checked_camera(f['transform_matrix']);ray=held.rays(rr.ravel(),cc.ravel(),*[f[k]for k in ('fl_x','fl_y','cx','cy')])
  d,cells,q=surface.query(pose,transform,ray,label=name);assert np.array_equal(np.isfinite(d),cells>=0)
  target=out/(name+'.npz');np.savez_compressed(target,row=rr.ravel().astype(np.uint16),column=cc.ravel().astype(np.uint16),axialMetres=d,cellID=cells)
  record={'frameID':name,'index':i,'scheduled':len(d),'positiveHits':int(np.isfinite(d).sum()),'fileSHA256':digest(target),'poseCheck':check,'query':q};records.append(record);progress({'frameComplete':name,'positiveHits':record['positiveHits']})
 for p,h in pins.items():assert digest(p)==h
 dump(out/'RESULT.json',{'status':'completed','mode':mode,'views':29,'scheduledRays':29*46065,'pixelOffset':0,'sampleStride':4,'runtime':runtime,'meshSHA256':digest(path),'meshVertices':mesh.GetNumberOfPoints(),'meshCells':mesh.GetNumberOfCells(),'transformCheck':transformcheck,'records':records,'pinsReverified':True,'fittingPerformed':False,'physicalAuthority':False})
if __name__=='__main__':main(sys.argv[1])
