import importlib.metadata as md,json,pathlib,sys
import open3d as o3d
m=json.loads(pathlib.Path(sys.argv[1]).read_text());target=pathlib.Path(sys.argv[2]).resolve()
assert o3d.__version__=='0.19.0'
assert pathlib.Path(o3d.__file__).resolve().is_relative_to(target)
assert not o3d._build_config['BUILD_CUDA_MODULE']
for row in m['artifacts']+m['reusedInstalled']:
 assert md.version(row['name'])==row['version'], row['name']
print(json.dumps({'version':o3d.__version__,'modulePath':str(pathlib.Path(o3d.__file__).resolve()),'buildConfig':o3d._build_config,'distributionVersions':{r['name']:md.version(r['name']) for r in m['artifacts']+m['reusedInstalled']},'reconstructionExecuted':False},indent=2))
