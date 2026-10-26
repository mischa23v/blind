"""Freeze saved-reference inputs and sources only; no geometry execution."""
from pathlib import Path
import argparse, hashlib, json, os, stat

ROOT = Path(__file__).resolve().parent
WORKSPACE = ROOT.parent
BASE = WORKSPACE / 'blind-open3d-author-baseline-10'
HELDOUT = WORKSPACE / 'blind-koivu-tsdf-heldout-11'
REFERENCE = WORKSPACE / 'blind-koivu-reference-comparison-06'
LIMITS = dict(cpuSeconds=120, wallSeconds=180, treeRSSBytes=1073741824,
              outputBytes=33554432, freeReserveBytes=805306368,
              combinedStageBytes=943718400)
PROTOCOL_SHA = '88386d8d0c74852f93a589911fc7ed79937e64489ce21354cd855e050d0000b0'
MESH_SHA = '5a75ebce93a3c65928344ce486223aa17a01a2c196982fc97edff8c41dd56e2e'
TRAIN_SHA = '89e4f8add800d85b772a5314f88c45dbecb1dd5536c0b61c9f5f533727f942d4'
POSE_SHA = 'c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3'
HELPER_SHA = '266026051a781f122a59187f599688e8c5eb38807984b7e607401e7b4356386d'
HELDOUT_SOURCE_SHA = '30b7fa320f9f2d369080e75e96f5f20fcdce5f2793ade3b698b51c7560b23cf2'
HELDOUT_RECEIPT_SHA = '995e9e1dad642eb120194a7029f791b8b3169760cda68e0fe52887ebd25b9436'
HELDOUT_RECOUNT_SHA = '73e1b1d67f47b90ee8e080779d2ff70cc53d02af378f396548ab402f9a15b092'
ARRAYS = [
    ('frame_00001',432127,'a70edf131ae109854530d9a1102aa15c6aa4249ff181696c8c385211d7f93e4c'),
    ('frame_00005',465661,'f4c03bea01bcc9a2a6c73d3d3b5d397ae4624318d00ee6d249b8e9c9851dae6c'),
    ('frame_00009',504221,'3bd8c91426a601968e048b2d90b0f97e87c792b3a10ac78f9526e2bb4168d321'),
    ('frame_00013',495895,'6c75c9c50ac30b7348cc2cc3a9a16fb9239857a790f03bc34b8d8b57e568b20c'),
    ('frame_00017',496836,'e241759c94334fe7c3d2c5c3330fd4b0cd347c7be3258f10630d1d045177999c'),
    ('frame_00021',473463,'7074d6da51ab6eafc2d6d4074ef7ff04bc2d92bd9886ef3d90783ca5c05ef5ca'),
    ('frame_00025',440400,'9f4808bfc1b6dc15c1966ba4f9739d6e4babba6bb9749573b95681078ba1b3ce'),
    ('frame_00029',496013,'1b2a846146496499ac176a45f7cc782bdf079e2dd9054b63592bff20b8362b45'),
]

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
    args=ap.parse_args()
    training_path=BASE/'KOIVU_FROZEN.json'
    training_pin=pin(training_path,'trainingFreeze',TRAIN_SHA)
    training=json.loads(training_path.read_text())
    ids=[row[0] for row in ARRAYS]
    trained={row['frameID'] for row in training['trainingFrames']}
    excluded=set(training['excludedTestIDs'])
    if (len(trained)!=265 or len(excluded)!=29 or trained & excluded
            or set(ids)-trained!={'frame_00021'} or set(ids)&excluded!={'frame_00021'}):
        raise ValueError('fixed seven-training/one-excluded view association mismatch')
    pose=Path(training['posePath'])
    if training['pins'][str(pose)]!=POSE_SHA:raise ValueError('training pose pin mismatch')
    pose_pin=pin(pose,'pose',POSE_SHA)
    frames=json.loads(pose.read_text())['frames'];names=[Path(f['file_path']).stem for f in frames]
    if len(names)!=294 or len(set(names))!=294 or any(n not in names for n in ids):
        raise ValueError('fixed-view pose association mismatch')
    saved=REFERENCE/'run-evaluate/comparison'
    paths=dict(mesh=str(BASE/'koivu/unfiltered-tsdf-mesh.ply'),pose=str(pose),
        evaluator=str(ROOT/'evaluate.py'),protocol=str(ROOT/'PROTOCOL.md'),trainingFreeze=str(training_path),
        savedReferenceDirectory=str(saved),referenceResult=str(saved/'COMPARISON_RESULTS.json'),
        associationReport=str(saved/'ASSOCIATION_REPORT.json'),referenceReceipt=str(REFERENCE/'run-evaluate/RUN_RECEIPT.json'),
        heldoutReceipt=str(HELDOUT/'run-01/RUN_RECEIPT.json'),heldoutRecount=str(HELDOUT/'POSTRUN_RECOUNT.json'),baselineStage=str(BASE),
        heldoutStage=str(HELDOUT),savedReferenceStage=str(ROOT))
    pins=[training_pin,pose_pin,pin(paths['protocol'],'protocol',PROTOCOL_SHA),
        pin(paths['mesh'],'mesh',MESH_SHA),
        pin(paths['referenceResult'],'referenceResult','3dd8431ea152ac1019fc52e70cdeb49c2dfa8065917d92d546cf8a33f47f48cd'),
        pin(paths['associationReport'],'associationReport','c84075e2be6cb4be7e9f247335eb28d78aafda0eeda68aeec89621f20c6f416b'),
        pin(paths['referenceReceipt'],'referenceReceipt','fd36b71d05aff5b149b70affb3e8caa100f668fa27911fee5707854c114440f4'),
        pin(paths['heldoutReceipt'],'heldoutReceipt',HELDOUT_RECEIPT_SHA),
        pin(paths['heldoutRecount'],'heldoutRecount',HELDOUT_RECOUNT_SHA)]
    receipt=json.loads(Path(paths['heldoutReceipt']).read_text())
    if (receipt.get('sourceAndInputHashesVerifiedBeforeAndAfter') is not True
            or [(r.get('mode'),r.get('exitCode')) for r in receipt.get('modes',[])]
                !=[('conventions',0),('evaluate',0)]):
        raise ValueError('held-out execution not terminal and verified')
    recount=json.loads(Path(paths['heldoutRecount']).read_text())
    if recount.get('success') is not True or recount.get('scheduledRays')!=1335885:
        raise ValueError('independent held-out recount prerequisite failed')
    for p,expected in [(ROOT/'evaluate.py',None),(ROOT/'run_bounded.py',None),
                       (Path(__file__).resolve(),None),(REFERENCE/'reference_geometry.py',HELPER_SHA),
                       (HELDOUT/'evaluate.py',HELDOUT_SOURCE_SHA)]:
        pins.append(pin(p,'source',expected))
    for name,size,expected in ARRAYS:
        row=pin(saved/(name+'-scheduled-rays.npz'),'savedReferenceRays',expected)
        if row['bytes']!=size:raise ValueError('saved array size mismatch')
        pins.append(row)
    if len({p['path'] for p in pins})!=len(pins):raise ValueError('duplicate manifest pin')
    result=dict(schemaVersion=1,paths=paths,frameIDs=ids,pins=pins,limits=LIMITS,
        expectedMesh=dict(vertices=242293,triangles=461256),
        schedule=dict(stride=4,pixelOffset=0.5,width=738,height=994,raysPerFrame=46065,totalRays=368520),
        viewAssociation=dict(training=[n for n in ids if n in trained],excluded=['frame_00021']),
        dataEvaluationExecuted=False,noFaroMeshInput=True,
        privateRuntimePaths='absolute local paths; normalize publication copies only')
    b=(json.dumps(result,indent=2,sort_keys=True)+'\n').encode()
    with args.output.open('xb') as f:f.write(b)
    print(json.dumps(dict(status='frozen',path=str(args.output),sha256=hashlib.sha256(b).hexdigest(),pins=len(pins))))

if __name__=='__main__':main()
