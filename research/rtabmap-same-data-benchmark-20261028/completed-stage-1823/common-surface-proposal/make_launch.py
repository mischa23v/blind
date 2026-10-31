"""Hash completed outputs only. This performs no geometric comparison."""
from pathlib import Path
import argparse,hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--labels',default='open3d,fixed,graph');a=p.parse_args();out=Path(a.out)
if out.exists():raise RuntimeError('fresh launch manifest required')
paths={'open3d':ROOT/'research/open3d-same-data-benchmark-20261028/fresh-run/fusion/author-style-initialization-cloud.ply', 'fixed':HERE.parent/'fresh-run/fixed/cloud.ply','graph':HERE.parent/'fresh-run/graph/cloud.ply'}
labels=a.labels.split(',')
if len(labels)!=len(set(labels)) or not set(labels)<=set(paths) or 'open3d' not in labels:raise RuntimeError('invalid labels')
clouds={label:str(paths[label]) for label in labels}
pins={path:sha(path) for path in clouds.values()}
for label in labels:
 if label!='open3d':
  receipt=HERE.parent/'fresh-run'/label/'ENGINE_RESULT.txt'
  pins[str(receipt)]=sha(receipt)
x={'protocolSHA256':sha(HERE/'FROZEN.json'),'clouds':clouds,'pins':pins,'pendingArms':[l for l in paths if l not in labels]}
with out.open('x') as f:json.dump(x,f,indent=2,sort_keys=True);f.write('\n')
print(out)
