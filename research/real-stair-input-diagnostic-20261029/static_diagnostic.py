"""Local noncommercial research adapter checks; not a stair detector or calibration test."""
import os, resource, time, json, hashlib
from pathlib import Path
resource.setrlimit(resource.RLIMIT_AS, (256*1024**2, 256*1024**2))
resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
for key in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS','NUMEXPR_NUM_THREADS'):
    os.environ[key] = '1'
start = time.monotonic()
import numpy as np
from PIL import Image, ImageDraw
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
manifest = json.loads((ROOT/'MANIFEST.json').read_text())
expected = {x['file']: x['sha256'] for x in manifest['files']}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
report = {
 'scope':'Executed four-frame static adapter diagnostic; not independent calibration, true geometry, pose accuracy, or stair detection accuracy',
 'source':'https://www.microsoft.com/en-us/research/project/rgb-d-dataset-7-scenes/',
 'licence':{'file':'7scenes-license.rtf','sha256':sha(ROOT/'7scenes-license.rtf'),'restriction':'Noncommercial research/personal experimentation; production reuse not authorized'},
 'configuration':{'depth_metres_per_raw_unit':0.001,'default_uncalibrated_K':{'fx':585,'fy':585,'cx':320,'cy':240},'invalid_depth_raw':[0,65535], 'adapter_tolerances_not_author_parameters':{'homogeneous_row_max_abs':1e-8,'rotation_orthogonality_max_abs':1e-5,'rotation_determinant_abs_error':1e-5,'roundtrip_max_abs_metres':1e-10,'pixel_roundtrip_max_abs':1e-9}, 'preview':'Point-only camera-coordinate projections, every 16th valid point; no surfaces or hole filling. RGB not used as aligned labels.'},
 'unknown_prerequisites':['capture timestamps/cadence','measured gravity','mesh floor classification','device/ray calibration including FloorDetector angle','independent hazard/feet/warning labels','measured intrinsics and RGB-depth alignment'],
 'frames':[]}
for i in range(4):
    stem=f'7scenes-frame-{i:06d}'
    hashes={}
    for ext in ('color.png','depth.png','pose.txt'):
        p=ROOT/f'{stem}.{ext}'; h=sha(p)
        assert h==expected[p.name], f'Input changed: {p.name}'
        hashes[p.name]=h
    with Image.open(ROOT/f'{stem}.color.png') as rgb: assert rgb.size==(640,480)
    with Image.open(ROOT/f'{stem}.depth.png') as im:
        assert im.size==(640,480) and im.mode=='I;16'
        d=np.array(im)
    assert d.dtype==np.uint16
    valid=(d>0)&(d<65535)
    v,u=np.nonzero(valid)
    raw=d[v,u]
    z=raw.astype(np.float64)/1000
    xyz=np.column_stack(((u-320)*z/585,(v-240)*z/585,z))
    assert len(xyz)==int(valid.sum()) and np.isfinite(xyz).all()
    assert np.all(raw>0) and np.all(raw<65535)
    # (u,v,raw,frame index) remain associated with each point in these arrays.
    pixel_error=max(float(np.max(np.abs(585*xyz[:,0]/z+320-u))),float(np.max(np.abs(585*xyz[:,1]/z+240-v))))
    pose=np.loadtxt(ROOT/f'{stem}.pose.txt')
    assert pose.shape==(4,4) and np.isfinite(pose).all()
    R=pose[:3,:3]; inv=np.linalg.inv(pose)
    last=float(np.max(np.abs(pose[3]-[0,0,0,1])))
    ortho=float(np.max(np.abs(R.T@R-np.eye(3))))
    det=float(np.linalg.det(R))
    world=xyz@R.T+pose[:3,3]
    restored=world@inv[:3,:3].T+inv[:3,3]
    err=float(np.max(np.abs(restored-xyz)))
    checks={"homogeneous_row":last<=1e-8,"rotation_orthogonality":ortho<=1e-5,"rotation_determinant":abs(det-1)<=1e-5,"inverse_roundtrip":err<=1e-10,"pixel_roundtrip":pixel_error<=1e-9}
    # Local-only point preview: camera X/Y and X/Z. Blank pixels are no plotted sample, never clearance.
    canvas=Image.new('RGB',(1000,540),'#111111'); draw=ImageDraw.Draw(canvas)
    draw.text((10,5),f'Frame {i}: camera X/Y (Y down) | camera X/Z (Z forward); sampled points, NO floor/gravity labels',fill='white')
    sample=xyz[::16]
    for panel,axes in enumerate(((0,1),(0,2))):
        pts=sample[:,axes]; lo=xyz[:,axes].min(0); hi=xyz[:,axes].max(0)
        pix=((pts-lo)/(hi-lo)*[470,470]).astype(int)
        for j,(px,py) in enumerate(pix):
            shade=int(40+215*(sample[j,2]-z.min())/(z.max()-z.min()))
            draw.point((panel*500+15+int(px),40+int(py)),fill=(shade,255-shade,180))
    preview=HERE/f'LOCAL_ONLY_geometry_{i:06d}.png'; canvas.save(preview)
    report['frames'].append({'frame_index':i,'input_sha256':hashes,'depth_encoding':'uint16,640x480','valid_points':len(xyz),'zero_unknown':int((d==0).sum()),'sentinel_unknown':int((d==65535).sum()),'invalid_points_admitted':0,'valid_depth_range_m':[float(z.min()),float(z.max())], 'camera_xyz_min':xyz.min(0).tolist(),'camera_xyz_max':xyz.max(0).tolist(),'pose':{'homogeneous_row_max_abs':last,'orthogonality_max_abs':ortho,'determinant':det,'inverse_roundtrip_max_abs_m':err},'pixel_algebraic_roundtrip_max_abs':pixel_error,'preview_sha256':sha(preview),'checks':checks,'checks_passed':all(checks.values())})
    del xyz,world,restored,d,raw,z,u,v,valid,sample
report['execution']={'cpu_affinity':sorted(os.sched_getaffinity(0)),'max_address_space_bytes':256*1024**2,'cpu_limit_seconds':30,'external_wall_limit_seconds':30,'elapsed_seconds':time.monotonic()-start,'peak_rss_kib':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'numpy':np.__version__}
report['result']='Static diagnostic completed. Check failures retained without pose correction or tolerance tuning. No detector executed.'
report['initial_attempt']='First execution stopped at predeclared numerical checks; second execution retains per-check failures for all frames instead of aborting. No tolerances changed.'
(HERE/'STATIC_DIAGNOSTIC.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'result':report['result'],'execution':report['execution'],'valid_points':[f['valid_points'] for f in report['frames']]}))
