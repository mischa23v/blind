"""Private depth-only replay helpers; inferred units, never sensor authority."""
from pathlib import Path
import csv, hashlib, json, math
import numpy as np

INDICES = list(range(60))
VOXEL = .04
SDF_TRUNC = .2
DEPTH_TRUNC = 4.
DEPTH_SCALE = 1000.


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(2**20), b''):
            h.update(block)
    return h.hexdigest()


def save(path, value):
    with Path(path).open('x') as f:
        json.dump(value, f, indent=2)


def rotation(q):
    q = np.asarray(q, dtype=float)
    norm = np.linalg.norm(q)
    if not np.isfinite(q).all() or not np.isfinite(norm) or abs(norm-1) > .001:
        raise ValueError('Invalid quaternion/norm deviation >.001')
    q /= norm
    x,y,z,w = q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                     [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                     [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]), abs(norm-1)


def read_metadata(freeze):
    paths = freeze['input_paths']
    with open(paths['K']) as f:
        rawK = np.asarray([[float(x) for x in row] for row in csv.reader(f)])
    if rawK.shape != (3,3) or not np.isfinite(rawK).all() or not np.array_equal(rawK[2], [0,0,1]):
        raise ValueError('Invalid K')
    K = rawK.copy(); K[0] *= 256/1920; K[1] *= 192/1440
    if K[0,0] <= 0 or K[1,1] <= 0 or K[0,1] != 0 or K[1,0] != 0:
        raise ValueError('Unsupported intrinsic form')
    poses = {}; times = {}; norms = []
    with open(paths['poses']) as f:
        for row in csv.DictReader(f, skipinitialspace=True):
            i = int(row['frame'])
            if i in poses:
                raise ValueError('Duplicate pose index')
            R, residual = rotation([float(row[k]) for k in ('qx','qy','qz','qw')])
            T = np.eye(4); T[:3,:3] = R
            T[:3,3] = [float(row[k]) for k in ('x','y','z')]
            timestamp = float(row['timestamp'])
            if not np.isfinite(T).all() or not math.isfinite(timestamp):
                raise ValueError('Nonfinite pose')
            if not np.allclose(R.T @ R, np.eye(3), atol=1e-12) or not math.isclose(np.linalg.det(R),1,abs_tol=1e-12):
                raise ValueError('Invalid rigid pose')
            poses[i] = T; times[i] = timestamp; norms.append(residual)
    if not all(i in poses for i in INDICES) or any(times[b] <= times[a] for a,b in zip(INDICES, INDICES[1:])):
        raise ValueError('Missing prefix pose/nonmonotonic time')
    return K, poses, times, {'max_deviation':max(norms), 'rule':'fixed unit normalization; reject deviation>.001, not pose fitting'}


def mask_depth(depth, confidence):
    if depth.shape != (192,256) or depth.dtype != np.uint16 or confidence.shape != depth.shape or confidence.dtype != np.uint8:
        raise ValueError('Unexpected image dimensions/dtypes')
    reason = np.zeros(depth.shape, np.uint8)
    reason[depth == 0] |= 1
    reason[depth == 65535] |= 2
    reason[confidence == 0] |= 4
    reason[confidence == 1] |= 8
    reason[~np.isin(confidence, (0,1,2))] |= 16
    # Strict 4m factory truncation, separate from unknown/missing numeric data.
    reason[(depth >= 4000) & (depth < 65535)] |= 32
    masked = depth.copy(); masked[reason != 0] = 0
    stats = {'raster_pixels':int(depth.size), 'zero_depth':int((depth==0).sum()),
             'code65535_depth':int((depth==65535).sum()), 'confidence_0_not_selected':int((confidence==0).sum()),
             'confidence_1_not_selected':int((confidence==1).sum()), 'confidence_2':int((confidence==2).sum()),
             'unrecognized_confidence_codes':int(((reason & 16)!=0).sum()),
             'numeric_high_confidence_before_range_clip':int(((depth>0)&(depth<65535)&(confidence==2)).sum()),
             'high_confidence_4m_clipped':int(((depth>=4000)&(depth<65535)&(confidence==2)).sum()),
             'accepted_endpoint_pixels':int((masked>0).sum()), 'zero_after_mask':int((masked==0).sum())}
    return masked, reason, stats


def make_rgbd(o3d, depth):
    # No actual RGB: the required color argument is an all-zero placeholder.
    return o3d.geometry.RGBDImage.create_from_color_and_depth(
        o3d.geometry.Image(np.zeros((*depth.shape,3), np.uint8)),
        o3d.geometry.Image(np.ascontiguousarray(depth)), depth_scale=DEPTH_SCALE,
        depth_trunc=DEPTH_TRUNC, convert_rgb_to_intensity=False)


def make_volume(o3d):
    return o3d.pipelines.integration.ScalableTSDFVolume(
        voxel_length=VOXEL, sdf_trunc=SDF_TRUNC,
        color_type=o3d.pipelines.integration.TSDFVolumeColorType.NoColor,
        volume_unit_resolution=16, depth_sampling_stride=4)


def verify_backend(o3d, freeze):
    from open3d.cpu import pybind
    import numpy._core._multiarray_umath as multi
    import numpy.linalg._umath_linalg as linalg
    if o3d.__version__ != '0.19.0' or o3d._build_config['BUILD_CUDA_MODULE']:
        raise RuntimeError('Expected existing CPU-only Open3D0.19.0')
    paths = {name:Path(module.__file__).resolve() for name,module in
             [('open3d',o3d),('open3d.cpu.pybind',pybind),('numpy',np),
              ('numpy._core._multiarray_umath',multi),('numpy.linalg._umath_linalg',linalg)]}
    expected = freeze['backend_modules']
    for name,path in paths.items():
        if str(path) != expected[name]['path'] or digest(path) != expected[name]['sha256']:
            raise RuntimeError('Backend module identity changed: '+name)
    return {name:{'path':str(path),'sha256':digest(path)} for name,path in paths.items()}
