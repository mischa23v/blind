"""Headless derivative of the pinned Open3D scalable integration notebook (MIT).
The underlying fusion/projection/mesh extraction is unmodified Open3D.
"""
from pathlib import Path
import hashlib,json,os,sys,time,signal,importlib
import acquire_environment as guard

ROOT=Path(__file__).resolve().parent

def worker(frozen_path,outpath):
    import numpy as np
    import open3d as o3d
    from open3d.cpu import pybind
    import numpy._core._multiarray_umath as multi
    import numpy.linalg._umath_linalg as linalg
    out=Path(outpath);frozen=json.loads(Path(frozen_path).read_text());data=Path(frozen['dataRoot'])
    assert o3d.__version__=='0.19.0' and not o3d._build_config['BUILD_CUDA_MODULE']
    assert Path(o3d.__file__).resolve().is_relative_to(ROOT/'environment/target')
    modules={}
    for name,module in [('open3d',o3d),('open3d.cpu.pybind',pybind),('numpy',np),('numpy._core._multiarray_umath',multi),('numpy.linalg._umath_linalg',linalg)]:
        path=Path(module.__file__).resolve();modules[name]={'path':str(path),'sha256':guard.digest(path),'bytes':path.stat().st_size}
    text=(data/'odometry.log').read_text().splitlines();poses=[];at=0
    while at<len(text):
        header=[int(x) for x in text[at].split()];at+=1
        assert len(header)==3
        pose=np.asarray([[float(x) for x in line.split()] for line in text[at:at+4]],dtype=np.float64);at+=4
        assert pose.shape==(4,4) and np.isfinite(pose).all() and np.allclose(pose[3],[0,0,0,1],rtol=0,atol=1e-12)
        poses.append(pose)
    assert len(poses)==5
    intrinsic=o3d.camera.PinholeCameraIntrinsic(o3d.camera.PinholeCameraIntrinsicParameters.PrimeSenseDefault)
    volume=o3d.pipelines.integration.ScalableTSDFVolume(voxel_length=4.0/512.0,sdf_trunc=0.04,color_type=o3d.pipelines.integration.TSDFVolumeColorType.RGB8)
    frames=[];started=time.monotonic()
    for i,pose in enumerate(poses):
        color=o3d.io.read_image(str(data/f'color/{i:05d}.jpg'));depth=o3d.io.read_image(str(data/f'depth/{i:05d}.png'))
        c=np.asarray(color);d=np.asarray(depth)
        assert c.shape==(480,640,3) and d.shape==(480,640) and c.dtype==np.uint8 and d.dtype==np.uint16
        rgbd=o3d.geometry.RGBDImage.create_from_color_and_depth(color,depth,depth_scale=1000.0,depth_trunc=4.0,convert_rgb_to_intensity=False)
        actual=np.asarray(rgbd.depth);assert actual.shape==d.shape and np.isfinite(actual).all() and (actual>0).any()
        extrinsic=np.linalg.inv(pose);assert np.isfinite(extrinsic).all()
        volume.integrate(rgbd,intrinsic,extrinsic)
        frames.append({'frameID':i,'pixels':int(d.size),'rawZeroPixels':int((d==0).sum()),'nativeConvertedPositiveDepthPixels':int((actual>0).sum()),'nativeConvertedZeroDepthPixels':int((actual==0).sum()),'nativeConvertedPositiveDepthMinMaxM':[float(actual[actual>0].min()),float(actual.max())]})
    mesh=volume.extract_triangle_mesh();mesh.compute_vertex_normals()
    points=np.asarray(mesh.vertices);triangles=np.asarray(mesh.triangles)
    assert points.ndim==2 and points.shape[1]==3 and len(points)>0 and np.isfinite(points).all()
    assert triangles.ndim==2 and triangles.shape[1]==3 and len(triangles)>0 and triangles.min()>=0 and triangles.max()<len(points)
    assert o3d.io.write_triangle_mesh(str(out/'official-five-frame-mesh.ply'),mesh,write_ascii=False)
    for row in modules.values():assert guard.digest(row['path'])==row['sha256']
    result={'scope':'Official synthetic five-frame engine smoke only; not iPhone, accuracy, detection or navigation','frames':frames,'integratedFrameCount':len(frames),'vertices':len(points),'triangles':len(triangles),'boundsMin':points.min(axis=0).tolist(),'boundsMax':points.max(axis=0).tolist(),'intrinsicWidth':intrinsic.width,'intrinsicHeight':intrinsic.height,'intrinsicMatrix':np.asarray(intrinsic.intrinsic_matrix).tolist(),'fusionAndExtractionWallSeconds':time.monotonic()-started,'modules':modules,'moduleHashesReverifiedAfter':True,'meshSHA256':guard.digest(out/'official-five-frame-mesh.ply'),'physicalAuthority':False}
    print(json.dumps(result,indent=2))

def main():
    frozen_path=ROOT/'SMOKE_FROZEN.json';frozen=json.loads(frozen_path.read_text());out=ROOT/'smoke'
    if out.exists():raise RuntimeError('refuse historical smoke overwrite')
    for path,h in frozen['pins'].items():
        if guard.digest(path)!=h:raise ValueError('frozen source/input changed: '+path)
    out.mkdir();cache=out/'cache';cache.mkdir();home=out/'home';home.mkdir()
    guard.CPU=60.;guard.WALL=90.;guard.RSS=1024**3
    class Bounds(guard.Bounds):
        def check(self):
            super().check()
            if guard.size(out)>32*1024**2:raise RuntimeError('smoke output cap')
    b=Bounds(cache)
    env=dict(os.environ)
    for k in list(env):
        if k.startswith('PIP_') or k in ('PYTHONHOME','PYTHONPATH','PYTHONUSERBASE','PYTHONPYCACHEPREFIX','LD_PRELOAD','LD_AUDIT','LD_LIBRARY_PATH'):env.pop(k,None)
    env.update(PYTHONPATH=str(ROOT/'environment/target'),PYTHONDONTWRITEBYTECODE='1',PYTHONNOUSERSITE='1',HOME=str(home),XDG_CONFIG_HOME=str(home/'config'),XDG_DATA_HOME=str(home/'data'),XDG_STATE_HOME=str(home/'state'),XDG_CACHE_HOME=str(cache),MPLCONFIGDIR=str(cache/'mpl'),IPYTHONDIR=str(home/'ipython'),JUPYTER_CONFIG_DIR=str(home/'jupyter'),JUPYTER_DATA_DIR=str(home/'jupyter-data'),JUPYTER_RUNTIME_DIR=str(home/'jupyter-runtime'),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',OPEN3D_DISABLE_WEB_VISUALIZER='true',TMPDIR=str(cache))
    try:
        b.run([sys.executable,str(Path(__file__).resolve()),'--worker',str(frozen_path),str(out)],out/'RESULT.json',out/'stderr.log',env)
        result=json.loads((out/'RESULT.json').read_text());assert result['integratedFrameCount']==5
        for path,h in frozen['pins'].items():
            if guard.digest(path)!=h:raise ValueError('frozen source/input changed during smoke')
        b.check();receipt={'status':'completed','scope':result['scope'],'frozenSHA256':guard.digest(frozen_path),'resultSHA256':guard.digest(out/'RESULT.json'),'wallSeconds':time.monotonic()-b.started,'cpuSeconds':guard.cpu()-b.cpu_start,'sampledPeakProcessTreeRSSBytes':b.peak_rss,'smokeOutputAllocatedBytes':guard.size(out),'totalStageAllocatedBytesPlusMetadataReservation':b.new_bytes(),'freeAfterBytes':guard.shutil.disk_usage(ROOT).free,'phases':b.phases,'pinsReverifiedAfter':True,'vertices':result['vertices'],'triangles':result['triangles']}
        guard.dump(out/'RECEIPT.json',receipt);b.check();print(json.dumps(receipt,indent=2))
    except BaseException as exc:
        guard.dump(out/'FAILURE.json',{'status':'failed','error':repr(exc),'phases':b.phases});raise

if __name__=='__main__':
    if len(sys.argv)==4 and sys.argv[1]=='--worker':worker(sys.argv[2],sys.argv[3])
    else:main()
