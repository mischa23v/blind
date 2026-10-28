from pathlib import Path
import hashlib,json
import numpy as np
H=Path(__file__).resolve().parent; shared=H.parents[1]/'open3d-same-data-benchmark-20261028'
frozen=json.loads((shared/'evidence/KOIVU_FROZEN.json').read_text());data=shared/'fresh-run/inputs/room_datasets/koivu/iphone/long_capture'
pose=data/'transformations.json';split=data/'test.txt';poses=json.loads(pose.read_text())['frames'];test=split.read_text().splitlines();assert test==frozen['excludedTestIDs'];assert len(poses)==294
pins=frozen['pins']; records=[];rows=[]
for r in frozen['trainingFrames']:
 f=poses[r['poseIndex']];id=r['frameID'];assert Path(f['file_path']).stem==id and id not in test
 files=[]
 for key,sub,suffix in [('rgbPath','images','.jpg'),('depthPath','depth','.png')]:
  p=data/sub/(id+suffix);sha=hashlib.sha256(p.read_bytes()).hexdigest();assert sha==pins[r[key]];files.append(p);records.append({'frame':id,'kind':key,'path':str(p),'sha256':sha,'bytes':p.stat().st_size})
 T=np.array(f['transform_matrix'],dtype=np.float64)@np.diag([1,-1,-1,1]);assert np.isfinite(T).all()
 vals=[id,*map(str,files),str(f['w']),str(f['h']),*[str(f[k])for k in ['fl_x','fl_y','cx','cy']],*[repr(float(x))for x in T[:3,:].ravel()]];rows.append('\t'.join(vals))
assert len(rows)==265
(H/'adapter/INPUTS.tsv').write_text('\n'.join(rows)+'\n')
for p in [pose,split]:
 expected=[v for k,v in pins.items()if Path(k).name==p.name];assert len(expected)==1 and hashlib.sha256(p.read_bytes()).hexdigest()==expected[0]
(H/'INPUT_RECEIPT.json').write_text(json.dumps({'trainingFrames':265,'excludedTestFrames':29,'all530ImageHashesMatchFrozen':True,'originalPoseAndSplitHashesMatch':True,'files':records,'tsvSHA256':hashlib.sha256((H/'adapter/INPUTS.tsv').read_bytes()).hexdigest()},indent=2)+'\n')
print('Verified265training/29holdout,530imagehashes,poseandsplit')
