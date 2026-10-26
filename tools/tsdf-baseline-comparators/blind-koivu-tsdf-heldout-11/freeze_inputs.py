"""Freeze already prepared held-out inputs and source; no geometry execution."""
from pathlib import Path
import argparse, hashlib, json, os, stat

ROOT = Path(__file__).resolve().parent
WORKSPACE = ROOT.parent
BASE = WORKSPACE / 'blind-open3d-author-baseline-10'
LIMITS = dict(cpuSeconds=300, wallSeconds=450, treeRSSBytes=1610612736,
              outputBytes=67108864, freeReserveBytes=805306368,
              combinedStageBytes=943718400)
PROTOCOL_SHA = '909353833c2d117b75ac0669159c0a318ffb9b49281163bc4f2747c3ea10984c'
MESH_SHA = '5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e'
TRAIN_SHA = '89e4f8add800d85b772a5314f88c45dbecb1dd5536c0b61c9f5f533727f942d4'
HELPER = WORKSPACE / 'blind-koivu-reference-comparison-06/reference_geometry.py'
HELPER_SHA = '266026051a781f122a59187f599688e8c5eb38807984b7e607401e7b4356386d'

def pin(path, role, expected=None):
    path = Path(path).absolute()
    if path.is_symlink(): raise ValueError('symlink pin rejected')
    with path.open('rb') as f:
        before = os.fstat(f.fileno())
        if not stat.S_ISREG(before.st_mode): raise ValueError('pin is not regular')
        h = hashlib.sha256()
        for b in iter(lambda: f.read(1048576), b''): h.update(b)
        after = os.fstat(f.fileno())
    identity = lambda s: (s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
    if identity(before) != identity(after) or identity(before) != identity(path.stat()):
        raise ValueError('input changed while hashing')
    if expected and h.hexdigest() != expected: raise ValueError('expected pin mismatch: '+str(path))
    return dict(role=role,path=str(path),bytes=before.st_size,sha256=h.hexdigest())

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,default=ROOT/'FROZEN.json')
    ap.add_argument('--source',type=Path,action='append',default=[]);args=ap.parse_args()
    training_path=BASE/'KOIVU_FROZEN.json';protocol=BASE/'HELDOUT_PROPOSAL.md'
    training_pin=pin(training_path,'trainingFreeze',TRAIN_SHA)
    training=json.loads(training_path.read_text());ids=training['excludedTestIDs']
    trained={r['frameID'] for r in training['trainingFrames']}
    if len(ids)!=29 or len(set(ids))!=29 or len(trained)!=265 or set(ids)&trained:
        raise ValueError('author train/test partition mismatch')
    pose=Path(training['posePath']);pose_expected=training['pins'][str(pose)]
    split=Path(training['splitPath']);split_expected=training['pins'][str(split)]
    if split.read_text().splitlines()!=ids: raise ValueError('test split mismatch')
    depth_dir=WORKSPACE/'blind-koivu-game-07/map/depths'
    dm=depth_dir/'DEPTH_INPUT_MANIFEST.json';depths=json.loads(dm.read_text())
    by_name={Path(r['file']).stem:r for r in depths['files']}
    frames=json.loads(pose.read_text())['frames']
    names=[Path(f['file_path']).stem for f in frames]
    if len(set(names))!=294 or any(n not in names or n not in by_name for n in ids):
        raise ValueError('held-out input association mismatch')
    if depths['poseSHA256']!=pose_expected: raise ValueError('depth manifest pose mismatch')
    paths=dict(mesh=str(BASE/'koivu/unfiltered-tsdf-mesh.ply'),pose=str(pose),
        depthDirectory=str(depth_dir),evaluator=str(ROOT/'evaluate.py'),protocol=str(protocol),
        trainingFreeze=str(training_path),testSplit=str(split),baselineStage=str(BASE),heldoutStage=str(ROOT))
    pins=[training_pin,pin(protocol,'protocol',PROTOCOL_SHA),pin(paths['mesh'],'mesh',MESH_SHA),
          pin(pose,'pose',pose_expected),pin(split,'testSplit',split_expected),pin(dm,'depthManifest',
          '8795ad2625e49336031a6a826e8247b6cbcc8bb3867f7c27a640a89ee049c82c')]
    sources=[ROOT/'evaluate.py',ROOT/'run_bounded.py',Path(__file__).resolve(),HELPER]+args.source
    for p in dict.fromkeys(sources):
        pins.append(pin(p,'source',HELPER_SHA if p.resolve()==HELPER.resolve() else None))
    for name in ids: pins.append(pin(depth_dir/(name+'.png'),'heldoutDepth',by_name[name]['sha256']))
    if len({p['path'] for p in pins})!=len(pins): raise ValueError('duplicate manifest pin')
    result=dict(schemaVersion=1,paths=paths,frameIDs=ids,pins=pins,limits=LIMITS,
        expectedMesh=dict(vertices=242293,triangles=461256),
        schedule=dict(stride=4,pixelOffset=0.0,width=738,height=994,raysPerFrame=46065,totalRays=1335885),
        dataEvaluationExecuted=False,privateRuntimePaths='absolute local paths; normalize publication copies only')
    b=(json.dumps(result,indent=2,sort_keys=True)+'\n').encode()
    with args.output.open('xb') as f:f.write(b)
    print(json.dumps(dict(status='frozen',path=str(args.output),sha256=hashlib.sha256(b).hexdigest(),pins=len(pins))))

if __name__=='__main__': main()
