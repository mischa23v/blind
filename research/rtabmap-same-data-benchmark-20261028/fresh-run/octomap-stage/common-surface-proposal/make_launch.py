"""Pin the completed OctoMap export after the separately frozen protocol."""
from pathlib import Path
import argparse,hashlib,json
HERE=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--out',required=True);a=p.parse_args()
cloud=HERE.parent/'native-grid/occupied_ground_endpoints.ply';receipt=cloud.parent/'RESULT.txt'
assert cloud.is_file() and receipt.is_file()
x={'protocolSHA256':sha(HERE/'FROZEN.json'),'clouds':{'octomap_fixed_native_grid':str(cloud)},'pins':{str(f):sha(f) for f in (cloud,receipt)},'pendingArms':[]}
with Path(a.out).open('x') as f:json.dump(x,f,indent=2,sort_keys=True);f.write('\n')
print(a.out)
