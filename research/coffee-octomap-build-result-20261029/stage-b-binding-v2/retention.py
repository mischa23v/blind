#!/usr/bin/env python3
"""Source-only prepared regression. Explicit Stage B opt-in loads pinned native code.
Full frame geometry goes to mapper; RGB patches are evaluator-only. No world pose.
"""
import os
os.environ['OPENBLAS_NUM_THREADS'] = '1'
os.environ['OMP_NUM_THREADS'] = '1'
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import resource

FRAMES = ('frame_00290', 'frame_00357', 'frame_00391')
SELECTION_SHA = '7e938424d28ae9b3a64480c2629aacd422a75d00cb8087cbfc0724fd99b81497'
POSES_SHA = '46c8d1fc5188d38179e88eff98fd42f99956fb93b570bd9483e6e92764ae7010'
LIBRARY_SHA = '0a044001b1455634ab881cc42fb5954362d960abf5cd851b7b6dc99b6c3eb963'
EXPECTED_SEPARATION = {'frame_00290': 0.6495903326711645, 'frame_00357': 0.6310732555255073, 'frame_00391': 0.6207033297953501}
DEPTH_SHA = {
 'frame_00290': '333eeb023a27656ae4f313db27a6b4ecee72acfff4cf8691a769aa92117ac38e',
 'frame_00357': 'cc2282608bc1f34157c2504d8058baf7af43db786067210aad0569f2c190708f',
 'frame_00391': '42e35845a580ec2b66a5d6741b0973eea173c10d92a8f6b3b0758da4c4e0c2c9',
}

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def require(condition, message):
    if not condition:
        raise ValueError(message)

def pinned(path, expected, byte_cap):
    require(path.is_file() and path.stat().st_size <= byte_cap, 'missing/oversize input: ' + path.name)
    require(sha(path) == expected, 'input hash mismatch: ' + path.name)

def project(depth, k):
    """Full original raster, no ROI or class supplied. Missing/out-of-range unknown."""
    import numpy as np
    require(depth.shape == (994, 738) and depth.dtype == np.uint16, 'original uint16 raster required')
    require(all(np.isfinite(k[name]) for name in ('fl_x', 'fl_y', 'cx', 'cy')) and
            k['fl_x'] > 0 and k['fl_y'] > 0, 'invalid original K')
    rows, cols = np.nonzero((depth > 0) & (depth < 4000))
    z = depth[rows, cols].astype(np.float64) / 1000.0
    points = np.column_stack(((cols-k['cx'])*z/k['fl_x'], (rows-k['cy'])*z/k['fl_y'], z))
    return points, rows, cols

def patch_mask(rows, cols, box):
    x0, y0, x1, y1 = box
    require(0 <= x0 < x1 <= 738 and 0 <= y0 < y1 <= 994, 'invalid evaluator box')
    return (cols >= x0) & (cols < x1) & (rows >= y0) & (rows < y1)

def diagnostic(points, rows, cols, selection):
    import numpy as np
    # Exact historical stride is relative to each frozen patch origin, not global pixels.
    patches = {}
    for name, key in (('table', 'tableInsetXYXY'), ('floor', 'nearbyFloorInsetXYXY')):
        box = selection[key]
        mask = patch_mask(rows, cols, box)
        stride = ((cols-box[0]) % 4 == 0) & ((rows-box[1]) % 4 == 0)
        patches[name] = points[mask & stride]
    floor = patches['floor']
    require(len(floor) > 10 and len(patches['table']) > 10, 'insufficient diagnostic patch')
    centre = floor.mean(axis=0)
    _, singular, v = np.linalg.svd(floor-centre, full_matrices=False)
    n = v[-1] if v[-1, 1] < 0 else -v[-1]
    offset = -n @ centre
    distance = patches['table'] @ n + offset
    return {'tablePoints': len(patches['table']), 'floorPoints': len(floor),
            'floorNormalCameraCV': n.tolist(), 'floorOffset': float(offset),
            'floorSingularValues': singular.tolist(),
            'floorResidualMax': float(np.max(np.abs(floor@n+offset))),
            'tableSignedDistanceMedian': float(np.median(distance)),
            'tableSignedDistanceMin': float(np.min(distance)),
            'tableSignedDistanceMax': float(np.max(distance)),
            'floorFitIsEvaluatorOnly': True}

def native_retention(engine, points, rows, cols, selection):
    import numpy as np
    # Each camera-local frame owns a fresh tree: no guessed cross-view registration.
    with engine.OctoMap(resolution=0.05) as tree:
        defaults = tree.defaults()
        require(abs(defaults['hit']-.7) < 1e-12 and abs(defaults['miss']-.4) < 1e-12 and
                abs(defaults['occupancy']-.5) < 1e-12, 'upstream defaults changed')
        keys = tree.keys(points)
        before = tree.query_keys(keys)
        require(not before['known'].any(), 'new tree must be unknown')
        insertion = tree.insert(0, points, [0., 0., 0.])
        result = tree.query_keys(keys)
        # Every original retained endpoint key must survive; evaluate before labels.
        require(result['known'].all() and result['occupied'].all(), 'lost measured endpoint key')
        require((result['hitScans'] == 1).all(), 'pixels incorrectly counted as scan votes')
        mask = patch_mask(rows, cols, selection['tableInsetXYXY'])
        table_keys = np.unique(keys[mask], axis=0)
        require(len(table_keys) > 0, 'empty tabletop evaluator set')
        table = tree.query_keys(table_keys)
        require(table['occupied'].all(), 'tabletop endpoint retention failed')
        # Untouched remote volume is an independent negative control, not inferred free.
        unknown = tree.query([[100., 100., 100.]])
        require(not unknown['known'].any(), 'unobserved volume promoted to known')
        converted = points.astype(np.float32).astype(np.float64)
        return {'defaults': defaults, 'insertion': insertion,
                'endpointCount': len(points), 'distinctEndpointKeys': len(np.unique(keys, axis=0)),
                'tableEndpointCount': int(mask.sum()), 'distinctTableKeys': len(table_keys),
                'allTableKeysOccupied': bool(table['occupied'].all()),
                'float32MaxAbsoluteConversionMetres': float(np.max(np.abs(converted-points))),
                'keysSHA256': hashlib.sha256(keys.tobytes()).hexdigest(),
                'tableKeysSHA256': hashlib.sha256(table_keys.tobytes()).hexdigest(),
                'independentTrees': True, 'rawHitsNotClearedByFloor': True,
                'unknownControlRemainsUnknown': True}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--depth-dir', type=Path, required=True)
    parser.add_argument('--transformations', type=Path, required=True)
    parser.add_argument('--diagnostic-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--stage', choices=('A', 'B'), default='A')
    parser.add_argument('--native-library', type=Path)
    args = parser.parse_args()
    require(not args.output.exists(), 'refuse replacing prior result')
    require(args.stage != 'B' or args.native_library is not None, 'B requires authorized pinned library')
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30) if args.stage == 'A' else (120, 120))
    import numpy as np
    from PIL import Image
    selected_path = args.diagnostic_dir/'PATCH_SELECTION.json'
    pinned(selected_path, SELECTION_SHA, 65536)
    pinned(args.transformations, POSES_SHA, 32*1024**2)
    selections = json.loads(selected_path.read_text())['frames']
    require(tuple(s['frame'] for s in selections) == FRAMES, 'frozen frame order mismatch')
    all_frames = json.loads(args.transformations.read_text())['frames']
    frames = {}
    for f in all_frames:
        key = Path(f['file_path']).stem
        require(key not in frames, 'duplicate original frame key')
        frames[key] = f
    engine = None
    if args.stage == 'B':
        pinned(args.native_library, LIBRARY_SHA, 2*1024**2)
        wrapper = Path(__file__).with_name('octomap_engine.py')
        pins = json.loads(Path(__file__).with_name('SOURCE_PINS.json').read_text())
        pinned(wrapper, pins['rebuiltBinding']['octomap_engine.py'], 65536)
        spec = importlib.util.spec_from_file_location('pinned_octomap_engine', wrapper)
        engine = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(engine)
        # Only location changes; the historical wrapper rechecks the exact binary hash.
        engine.LIBRARY = args.native_library.resolve()
    receipt = {'stage': args.stage, 'status': 'incomplete', 'frames': [],
               'cameraConvention': 'CV x-right y-down z-forward, independent camera-local frames',
               'suppliedCalibrationNotAutolocation': True, 'nativeConfidenceAvailable': False,
               'processedExportNotNativeDepth': True, 'physicalAuthority': False,
               'meshRegistration': 'unverified; Stage C absent',
               'geometryFilter': 'full original raster, positive axial depth strictly below 4m; no floor filter',
               'rangeExcludedIsUnknown': True, 'evaluatorAnnotationsCannotChangeMapperInput': True,
               'sourceSHA256': sha(Path(__file__)), 'posesSHA256': POSES_SHA,
               'selectionSHA256': SELECTION_SHA}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    try:
        for selection in selections:
            name = selection['frame']; f = frames[name]
            require((f['w'], f['h']) == (738, 994), 'intrinsic raster mismatch')
            path = args.depth_dir/(name+'.png')
            pinned(path, DEPTH_SHA[name], 1024**2)
            with Image.open(path) as image:
                require(image.size == (738, 994), 'unexpected raster dimensions')
                depth = np.asarray(image)
            points, rows, cols = project(depth, f)
            require(len(points) > 0, 'empty retained frame')
            report = {'frame': name, 'depthSHA256': DEPTH_SHA[name],
                      'intrinsics': {k: f[k] for k in ('fl_x', 'fl_y', 'cx', 'cy')},
                      'acceptedPoints': len(points), 'zeroPixels': int((depth == 0).sum()),
                      'rangeExcludedPixels': int((depth >= 4000).sum()),
                      'pointsFloat64SHA256': hashlib.sha256(points.tobytes()).hexdigest(),
                      'diagnostic': diagnostic(points, rows, cols, selection)}
            require(abs(report['diagnostic']['tableSignedDistanceMedian']-EXPECTED_SEPARATION[name]) <= 1e-9,
                    'historical backprojection/plane regression mismatch')
            # Diagnostic floor fit is never supplied to native_retention or mapper.
            if engine is not None:
                report['native'] = native_retention(engine, points, rows, cols, selection)
            receipt['frames'].append(report)
        receipt['status'] = 'completed'
    except Exception as error:
        receipt['status'] = 'failed'
        receipt['failure'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        receipt['peakRSSKiB'] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        with args.output.open('x') as stream:
            json.dump(receipt, stream, indent=2); stream.write('\n')

if __name__ == '__main__':
    main()
