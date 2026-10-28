"""Released Open3D PLY decoder; format conversion only, no geometric processing."""
import os,sys,json,hashlib,struct,re
from pathlib import Path
for k in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS'):os.environ[k]='1'
ROOT=Path(__file__).resolve().parents[5]
FRESH=ROOT/'research/open3d-same-data-benchmark-20261028/fresh-run'
sys.path.insert(0,str(FRESH/'environment/target'))
import numpy as np
import open3d as o3d

def sha(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
source,target=map(Path,sys.argv[1:]);assert not target.exists()
modules=json.loads((FRESH/'fusion/RESULT.json').read_text())['modules']
for name in ('open3d','open3d.cpu.pybind'):
 rec=modules[name];assert sha(rec['path'])==rec['sha256']
# PCL-compatible zero-face + camera-element fixture before any actual cloud/FARO load.
fixture=target.with_suffix('.decoder_fixture.ply')
fields=['view_px','view_py','view_pz','x_axisx','x_axisy','x_axisz','y_axisx','y_axisy','y_axisz','z_axisx','z_axisy','z_axisz','focal','scalex','scaley','centerx','centery']
header='ply\nformat binary_little_endian 1.0\ncomment PCL-compatible decoder fixture\nelement vertex 3\nproperty float x\nproperty float y\nproperty float z\nproperty uchar red\nproperty uchar green\nproperty uchar blue\nelement face 0\nelement camera 1\n'+''.join('property float '+f+'\n'for f in fields)+'property int viewportx\nproperty int viewporty\nproperty float k1\nproperty float k2\nend_header\n'
expected=np.array([[.125,-2.5,3.75],[-1.,0.,.5],[8.,16.,-32.]],dtype=np.float64)
with fixture.open('xb')as f:
 f.write(header.encode())
 for q in expected:f.write(struct.pack('<fffBBB',*q,13,27,91))
 f.write(struct.pack('<17f2i2f',*([0.]*17),738,994,0.,0.))
trial=o3d.io.read_point_cloud(str(fixture),remove_nan_points=False,remove_infinite_points=False,print_progress=False)
assert np.array_equal(np.asarray(trial.points),expected),'zero-face decoder fixture failed'
cloud=o3d.io.read_point_cloud(str(source),remove_nan_points=False,remove_infinite_points=False,print_progress=False)
p=np.asarray(cloud.points)
assert p.ndim==2 and p.shape[1]==3 and len(p)>0 and np.isfinite(p).all()
receipt_path=source.parent/'RESULT.txt'
receipt_text=receipt_path.read_text()
match=re.search(r'^endpointCloudPoints=(\d+)$',receipt_text,re.M)
assert match is not None,'missing native endpoint count'
expected_count=int(match.group(1))
assert len(p)==expected_count,'native output point count mismatch'
np.save(target,p)
receipt={'nativeReceiptSHA256':sha(receipt_path),'reader':'Open3D '+o3d.__version__+' io.read_point_cloud','sourceSHA256':sha(source),'points':len(p),'outputSHA256':sha(target),'geometryOperations':[],'zeroFaceCameraElementFixtureExact':True,'nativeReceiptPointCountVerified':expected_count,'removeNaNPoints':False,'removeInfinitePoints':False}
Path(str(target)+'.json').write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n')
