"""Declared loader derivative of DN-Splatter recorded-iPhone TSDF integration (Apache-2.0).
The underlying fusion/projection/mesh extraction is unmodified Open3D.
"""
from pathlib import Path
import hashlib,json,os,sys,time,signal,importlib
import acquire_environment as guard

ROOT=Path(__file__).resolve().parent
if sys.flags.optimize:raise RuntimeError('assertion checks require non-optimized Python')

def worker(frozen_path,outpath,expected_frozen_sha):
    # Restrict this worker, not the orchestrator, to one allowed logical CPU.
    allowed=sorted(os.sched_getaffinity(0));os.sched_setaffinity(0,{allowed[0]})
    import random
    import numpy as np
    import open3d as o3d
    from open3d.cpu import pybind
    import numpy._core._multiarray_umath as multi
    import numpy.linalg._umath_linalg as linalg
    random.seed(0);np.random.seed(0)
    assert guard.digest(frozen_path)==expected_frozen_sha
    out=Path(outpath);frozen=json.loads(Path(frozen_path).read_text())
    assert o3d.__version__=='0.19.0' and not o3d._build_config['BUILD_CUDA_MODULE']
    assert Path(o3d.__file__).resolve().is_relative_to(ROOT/'environment/target')
    modules={}
    for name,module in [('open3d',o3d),('open3d.cpu.pybind',pybind),('numpy',np),('numpy._core._multiarray_umath',multi),('numpy.linalg._umath_linalg',linalg)]:
        path=Path(module.__file__).resolve();modules[name]={'path':str(path),'sha256':guard.digest(path),'bytes':path.stat().st_size}
    poses=json.loads(Path(frozen['posePath']).read_text())['frames'];rows=frozen['trainingFrames']
    split=Path(frozen['splitPath']).read_text().splitlines()
    assert len(split)==29 and len(set(split))==29 and split==frozen['excludedTestIDs']
    pose_names=[Path(f['file_path']).stem for f in poses]
    assert len(poses)==294 and len(set(pose_names))==294 and set(split)<=set(pose_names)
    expected_indices=[i for i,name in enumerate(pose_names) if name not in set(split)]
    assert len(rows)==265 and [r['poseIndex'] for r in rows]==expected_indices
    required_paths=[frozen['posePath'],frozen['splitPath']]+[r[k] for r in rows for k in ('rgbPath','depthPath')]
    assert all(str(Path(p).resolve()) in frozen['pins'] for p in required_paths)
    flip=np.diag([1,-1,-1,1])
    # Analytical coordinate convention, independent of the recorded results.
    probe_pose=np.eye(4);probe_pose[:3,3]=[3,4,5]
    camera_cv=np.array([.2,.3,2,1]);camera_gl=np.array([.2,-.3,-2,1])
    assert np.array_equal((probe_pose@flip)@camera_cv,probe_pose@camera_gl)
    assert np.allclose(np.linalg.inv(probe_pose@flip)@(probe_pose@camera_gl),camera_cv,rtol=0,atol=1e-14)
    volume=o3d.pipelines.integration.ScalableTSDFVolume(voxel_length=.04,sdf_trunc=.2,color_type=o3d.pipelines.integration.TSDFVolumeColorType.RGB8)
    samples_per_frame=(1000000+len(rows))//len(rows);points_list=[];colors_list=[];frames=[];started=time.monotonic()
    with (out/'FRAMES.jsonl').open('x') as log:
        for k,row in enumerate(rows):
            frame=poses[row['poseIndex']];name=Path(frame['file_path']).stem
            assert name==row['frameID'] and name not in frozen['excludedTestIDs'] and Path(frame['depth_file_path']).stem==name
            H,W=int(frame['h']),int(frame['w']);assert (H,W)==(994,738)
            coeff=np.array([frame[x] for x in ('fl_x','fl_y','cx','cy')],dtype=np.float64)
            assert np.isfinite(coeff).all() and (coeff[:2]>0).all()
            intrinsic=o3d.camera.PinholeCameraIntrinsic(W,H,*coeff.tolist())
            color=o3d.io.read_image(row['rgbPath']);depth=o3d.io.read_image(row['depthPath'])
            c=np.asarray(color);d=np.asarray(depth)
            assert c.shape==(H,W,3) and d.shape==(H,W) and c.dtype==np.uint8 and d.dtype==np.uint16
            # No cv2.resize substitute: mismatch is a failure, not resampling.
            rgbd=o3d.geometry.RGBDImage.create_from_color_and_depth(color,depth,depth_scale=1000.0,depth_trunc=4.0,convert_rgb_to_intensity=False)
            actual=np.asarray(rgbd.depth);assert actual.shape==d.shape and np.isfinite(actual).all()
            clipped=int(((d>0)&(actual==0)).sum())
            assert int((d==0).sum())+clipped==int((actual==0).sum())
            pose=np.asarray(frame['transform_matrix'],dtype=np.float64)
            assert pose.shape==(4,4) and np.isfinite(pose).all() and np.array_equal(pose[3],[0,0,0,1])
            pose=pose@flip;extrinsic=np.linalg.inv(pose);assert np.isfinite(extrinsic).all()
            volume.integrate(rgbd,intrinsic,extrinsic)
            # Preserve author algorithm: cumulative cloud and evolving sample cap.
            pcd=volume.extract_point_cloud();samples_per_frame=min(samples_per_frame,len(pcd.points))
            mask=np.asarray(random.sample(range(len(pcd.points)),samples_per_frame),dtype=np.int64)
            points_list.append(np.asarray(pcd.points)[mask]);colors_list.append(np.asarray(pcd.colors)[mask])
            frame_result={'trainingIndex':k,'poseIndex':row['poseIndex'],'frameID':name,'exportedRasterPixels':int(d.size),'rawZeroPixels':int((d==0).sum()),'rawDepthMinMaxM':[float(d.min())*.001,float(d.max())*.001],'nativeConvertedPositiveDepthPixels':int((actual>0).sum()),'nativeConvertedZeroDepthPixels':int((actual==0).sum()),'nativeFactoryClippedNonzeroDepthPixels':clipped,'cumulativeSurfacePointCount':len(pcd.points),'authorSamplesThisFrame':len(mask),'elapsedWallSeconds':time.monotonic()-started,'elapsedCPUSeconds':time.process_time()}
            frames.append(frame_result);log.write(json.dumps(frame_result,sort_keys=True)+'\n');log.flush()
    points=np.vstack(points_list);colors=np.vstack(colors_list)
    if points.shape[0]>1000000:
        indices=np.random.choice(points.shape[0],size=1000000,replace=False);points=points[indices];colors=colors[indices]
    assert len(points)>0 and points.shape==colors.shape and np.isfinite(points).all() and np.isfinite(colors).all()
    cloud=o3d.geometry.PointCloud();cloud.points=o3d.utility.Vector3dVector(points);cloud.colors=o3d.utility.Vector3dVector(colors)
    assert o3d.io.write_point_cloud(str(out/'author-style-initialization-cloud.ply'),cloud,write_ascii=False)
    # Declared extension: native final TSDF mesh, no filtering/cleanup/decimation.
    mesh=volume.extract_triangle_mesh();vertices=np.asarray(mesh.vertices);triangles=np.asarray(mesh.triangles)
    assert len(vertices)>0 and vertices.shape[1]==3 and np.isfinite(vertices).all()
    assert len(triangles)>0 and triangles.shape[1]==3 and triangles.min()>=0 and triangles.max()<len(vertices)
    assert o3d.io.write_triangle_mesh(str(out/'unfiltered-tsdf-mesh.ply'),mesh,write_ascii=False)
    for row in modules.values():assert guard.digest(row['path'])==row['sha256']
    assert guard.digest(frozen_path)==expected_frozen_sha
    result={'scope':'Author-configured observed-depth Koivu provided-pose fusion; not SLAM, accuracy or navigation','integratedFrameCount':len(frames),'excludedTestFrameCount':len(frozen['excludedTestIDs']),'vertices':len(vertices),'triangles':len(triangles),'authorStyleCloudPoints':len(points),'boundsMin':vertices.min(axis=0).tolist(),'boundsMax':vertices.max(axis=0).tolist(),'exportedRasterPixels':sum(r['exportedRasterPixels'] for r in frames),'nativeConvertedPositiveDepthPixels':sum(r['nativeConvertedPositiveDepthPixels'] for r in frames),'nativeConvertedZeroDepthPixels':sum(r['nativeConvertedZeroDepthPixels'] for r in frames),'nativeFactoryClippedNonzeroDepthPixels':sum(r['nativeFactoryClippedNonzeroDepthPixels'] for r in frames),'rasterCountsAreIndependentSensorMeasurements':False,'originalConfidence':'unavailable','originalTracking':'unavailable','modules':modules,'moduleHashesReverifiedAfter':True,'workerCPUAffinity':sorted(os.sched_getaffinity(0)),'randomSeeds':{'python':0,'numpyLegacy':0},'poseConventionProbesPassed':2,'parameters':{'voxelLength':.04,'sdfTrunc':.2,'depthTrunc':4.0,'depthScale':1000.0,'color':'RGB8'},'loaderDifferences':['Open3D PNG/JPEG IO rather than OpenCV','dimension mismatch fails; no resize','fixed random seeds rather than unspecified seeds','additional unfiltered final native mesh export'],'fullTSDFWeightCoverageExported':False,'missingMeshImpliesFree':False,'FAROUsed':False,'physicalAuthority':False,'outputSHA256':{p.name:guard.digest(p) for p in out.glob('*.ply')}}
    print(json.dumps(result,indent=2))

def main():
    if len(sys.argv)!=3 or sys.argv[1]!='--frozen-sha':raise ValueError('expected immutable frozen SHA argument required')
    expected_frozen_sha=sys.argv[2]
    frozen_path=ROOT/'KOIVU_FROZEN.json'
    if guard.digest(frozen_path)!=expected_frozen_sha:raise ValueError('frozen launch SHA mismatch')
    frozen=json.loads(frozen_path.read_text());out=ROOT/'koivu'
    if out.exists():raise RuntimeError('refuse historical Koivu result overwrite')
    for path,h in frozen['pins'].items():
        if guard.digest(path)!=h:raise ValueError('frozen source/input changed: '+path)
    out.mkdir();cache=out/'cache';cache.mkdir();home=out/'home';home.mkdir()
    guard.CPU=600.;guard.WALL=900.;guard.RSS=2*1024**3
    class Bounds(guard.Bounds):
        def check(self):
            super().check()
            if guard.size(out)>128*1024**2:raise RuntimeError('Koivu output cap')
    b=Bounds(cache)
    env=dict(os.environ)
    for k in list(env):
        if k.startswith('PIP_') or k in ('PYTHONHOME','PYTHONPATH','PYTHONUSERBASE','PYTHONPYCACHEPREFIX','LD_PRELOAD','LD_AUDIT','LD_LIBRARY_PATH'):env.pop(k,None)
    env.update(PYTHONOPTIMIZE='0',PYTHONPATH=str(ROOT/'environment/target'),PYTHONDONTWRITEBYTECODE='1',PYTHONNOUSERSITE='1',HOME=str(home),XDG_CONFIG_HOME=str(home/'config'),XDG_DATA_HOME=str(home/'data'),XDG_STATE_HOME=str(home/'state'),XDG_CACHE_HOME=str(cache),MPLCONFIGDIR=str(cache/'mpl'),IPYTHONDIR=str(home/'ipython'),JUPYTER_CONFIG_DIR=str(home/'jupyter'),JUPYTER_DATA_DIR=str(home/'jupyter-data'),JUPYTER_RUNTIME_DIR=str(home/'jupyter-runtime'),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',OPEN3D_DISABLE_WEB_VISUALIZER='true',TMPDIR=str(cache))
    try:
        b.run([sys.executable,str(Path(__file__).resolve()),'--worker',str(frozen_path),str(out),expected_frozen_sha],out/'RESULT.json',out/'stderr.log',env)
        result=json.loads((out/'RESULT.json').read_text());assert result['integratedFrameCount']==265
        for path,h in frozen['pins'].items():
            if guard.digest(path)!=h:raise ValueError('frozen source/input changed during fusion')
        if guard.digest(frozen_path)!=expected_frozen_sha:raise ValueError('frozen manifest changed during run')
        b.check();receipt={'status':'completed','scope':result['scope'],'frozenSHA256':guard.digest(frozen_path),'resultSHA256':guard.digest(out/'RESULT.json'),'wallSeconds':time.monotonic()-b.started,'cpuSeconds':guard.cpu()-b.cpu_start,'sampledPeakProcessTreeRSSBytes':b.peak_rss,'reconstructionOutputAllocatedBytes':guard.size(out),'totalStageAllocatedBytesPlusMetadataReservation':b.new_bytes(),'freeAfterBytes':guard.shutil.disk_usage(ROOT).free,'phases':b.phases,'pinsReverifiedAfter':True,'vertices':result['vertices'],'triangles':result['triangles']}
        guard.dump(out/'RECEIPT.json',receipt);b.check();print(json.dumps(receipt,indent=2))
    except BaseException as exc:
        guard.dump(out/'FAILURE.json',{'status':'failed','error':repr(exc),'phases':b.phases});raise

if __name__=='__main__':
    if len(sys.argv)==5 and sys.argv[1]=='--worker':worker(sys.argv[2],sys.argv[3],sys.argv[4])
    else:main()
