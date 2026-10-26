"""Verify the exact latest phone labels before any evaluator geometry is read.

Reference arrays in pipeline_out.npz are deliberately excluded from the returned
record and cannot participate in selection. This module never opens a mesh.
"""
from pathlib import Path
import hashlib, json, zipfile
import numpy as np
from scipy import ndimage

PHONE_KEYS = ('lo', 'R', 't', 'state', 'mean', 'n', 'tail', 'support',
              'deepBelow', 'nearDip', 'low1', 'lowUnresolvedFlag',
              'highObstacle', 'highUnknown', 'walk')
MASK_KEYS = PHONE_KEYS[7:]
SEED = 20261026

def validate_arrays(arrays, receipt):
    a = {k: np.array(arrays[k], copy=True) for k in PHONE_KEYS}
    shape = a['walk'].shape
    if len(shape) != 2 or not 0 < np.prod(shape) <= 200000:
        raise ValueError('bounded two-dimensional phone grid required')
    if a['lo'].shape != (3,) or a['lo'].dtype.kind not in 'iu' or a['lo'][2] != -4:
        raise ValueError('exact pipeline grid origin required')
    R, t = a['R'], a['t']
    if R.shape != (3, 3) or t.shape != (3,) or not np.isfinite(R).all() or not np.isfinite(t).all():
        raise ValueError('finite saved level transform required')
    if not np.allclose(R.T @ R, np.eye(3), atol=1e-10, rtol=0) or abs(np.linalg.det(R)-1) > 1e-10:
        raise ValueError('saved level transform must be proper rigid')
    for k in MASK_KEYS:
        if a[k].shape != shape or a[k].dtype != np.bool_:
            raise ValueError('exact boolean mask required: ' + k)
    if a['state'].shape != shape or a['state'].dtype.kind != 'U' or not np.isin(a['state'], ['clear','object','unresolved']).all():
        raise ValueError('unexpected statistical class')
    for k in ('mean', 'n', 'tail'):
        if a[k].shape != shape:
            raise ValueError('statistical grid shape mismatch')
    if a['n'].dtype.kind not in 'iu' or np.any(a['n'] < 0):
        raise ValueError('sample counts must be nonnegative integers')
    if not np.isfinite(a['mean'][a['n'] > 0]).all() or not np.isfinite(a['tail']).all() or np.any((a['tail'] < 0) | (a['tail'] > 1)):
        raise ValueError('invalid statistical summaries')
    rows = receipt['log']
    d1 = [x for x in rows if x['stage'] == 'D1']
    walk = [x for x in rows if x['stage'] == 'walk']
    if len(d1) != 1 or len(walk) != 1:
        raise ValueError('unique matching receipt stages required')
    for k in MASK_KEYS:
        if int(a[k].sum()) != d1[0][k]:
            raise ValueError('phone mask differs from receipt: ' + k)
    masks = masks_from_phone(a)
    for k in ('d1Permissive','d1Strict','statClearOnly','statObjectBlocked'):
        if int(masks[k].sum()) != walk[0][k]:
            raise ValueError('derived phone mask differs from receipt: ' + k)
    for value in ('clear','object','unresolved'):
        if int(((a['state'] == value) & a['walk']).sum()) != walk[0]['statStates_walk'][value]:
            raise ValueError('statistical walk classes differ from receipt')
        if int(((a['state'] == value) & a['walk'] & a['lowUnresolvedFlag']).sum()) != walk[0]['statStates_flagged'][value]:
            raise ValueError('flagged statistical classes differ from receipt')
    for v in a.values(): v.setflags(write=False)
    return a

def masks_from_phone(a):
    w = a['walk']
    obs = a['highObstacle'] | a['low1']
    labels, _ = ndimage.label(obs, structure=np.ones((3,3)))
    sizes = np.bincount(labels.ravel())
    return {'d1Permissive': w,
            'd1Strict': w & ~a['lowUnresolvedFlag'],
            'statClearOnly': w & (a['state'] == 'clear'),
            'statObjectBlocked': w & (a['state'] != 'object'),
            'statObject': (a['state'] == 'object') & (w | (a['low1'] & a['support'] & ~a['highObstacle'])),
            'isolatedSpecks': (sizes[labels] <= 3) & obs,
            'd1HighObstacleSupported': a['highObstacle'] & a['support']}

def load_verified(path, expected_sha256, receipt):
    path = Path(path)
    if path.stat().st_size > 32*1024**2:
        raise ValueError('artifact byte cap')
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != expected_sha256:
        raise ValueError('artifact hash mismatch')
    with zipfile.ZipFile(path) as z:
        entries = z.infolist()
        if len(entries) > 64 or sum(e.file_size for e in entries) > 32*1024**2 or len({e.filename for e in entries}) != len(entries):
            raise ValueError('artifact expanded/member cap or duplicate member')
    with np.load(path, allow_pickle=False) as arrays:
        return validate_arrays(arrays, receipt)

def select_columns(a):
    masks = masks_from_phone(a)
    primary = np.flatnonzero(masks['statObject'] | masks['isolatedSpecks'])
    clear = np.flatnonzero(masks['statClearOnly'])
    rng = np.random.default_rng(SEED)
    primary_chosen = np.sort(rng.choice(primary, 2048, replace=False)) if len(primary) > 2048 else primary
    clear_chosen = np.sort(rng.choice(clear, min(256, len(clear)), replace=False))
    chosen = np.union1d(primary_chosen, clear_chosen)
    rows = np.column_stack(np.unravel_index(chosen, a['walk'].shape))
    return rows, {'seed': SEED, 'selectedColumns': len(rows),
                  'primaryPopulation': len(primary), 'primarySelected': len(primary_chosen),
                  'clearPopulation': len(clear), 'clearSelected': len(clear_chosen),
                  'selectionReadsReferenceArrays': False, 'noResamplingAfterReferenceOutcomes': True}
