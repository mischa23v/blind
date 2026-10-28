"""Corrected arm launch only; frozen numerical evaluator remains unchanged."""
from pathlib import Path
import hashlib,json
s=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
cloud=s/'zup-native-grid/occupied_ground_endpoints.ply';receipt=cloud.parent/'RESULT.txt'
assert cloud.is_file() and receipt.is_file()
x={'protocolSHA256':sha(s/'common-surface-proposal/FROZEN.json'),'clouds':{'octomap_zup_regenerated':str(cloud)},'pins':{str(f):sha(f)for f in [cloud,receipt,s/'ZUP_PRE_RUN_FREEZE.json',s/'ZUP_CORRECTION_PROTOCOL.md',s/'ZUP_RECOVERY_RECEIPT.json']},'pendingArms':[],'launchOnlyChange':'corrected world-Z-up regenerated grid arm, frozen common metric unchanged'}
p=s/'ZUP_COMMON_LAUNCH.json'
with p.open('x')as f:json.dump(x,f,indent=2);f.write('\n')
print(sha(s/'common-surface-proposal/FROZEN.json'))
