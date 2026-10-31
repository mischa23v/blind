#!/usr/bin/env python3
"""Prepared common-pose occupancy diagnostic. Requires explicit root-admitted run.

No OBJ, pose fitting, floor filter, route planner, or native build. Each whole
retained raster is inserted; table annotations are evaluator-only after insertion.
"""
import os
os.environ['OPENBLAS_NUM_THREADS'] = '1'
os.environ['OMP_NUM_THREADS'] = '1'
os.environ['MKL_NUM_THREADS'] = '1'
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import resource
import signal
import time

ROOT = Path(__file__).resolve().parent
FRAME_SELECTION_SHA = 'e5191320be4c61ba35820694d8b3638d799b27693f66b9890563c941bb4ec979'
PROJECTION_SHA = '52027afeb32a38f49d69e25713fa434d01291e4fc8a75d111daf151b5f44d7d4'
WRAPPER_SHA = '09645bd4065ccef13d28353d5a05e54c75f5ea284ca8e5c4439c58cc45aa4621'
LIBRARY_SHA = '0a044001b1455634ab881cc42fb5954362d960abf5cd851b7b6dc99b6c3eb963'
POSE_CONTRACT_SHA = '64a89282d3aaa3667483c6fefa7fa6e0ddec9a26e4ed14b34d1dc40c8e5d2bfc'
FRAMES = ('frame_00290', 'frame_00357', 'frame_00391')
UNKNOWN_PROBE = (100., 100., 100.)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024**2), b''):
            h.update(chunk)
    return h.hexdigest()


def pinned(path, expected, cap):
    require(path.is_file() and path.stat().st_size <= cap, 'missing/oversize input: ' + path.name)
    require(sha(path) == expected, 'input hash mismatch: ' + path.name)


def load_source(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def summarize(state):
    import numpy as np
    known = state['known'].astype(bool)
    occupied = state['occupied'].astype(bool) & known
    conflicts = (state['hitScans'] > 0) & (state['freeScans'] > 0)
    p = state['probability'][known]
    return {'keys': len(known), 'known': int(known.sum()),
            'occupied': int(occupied.sum()), 'knownNotOccupied': int((known & ~occupied).sum()),
            'unknown': int((~known).sum()), 'hitAndFreeConflictKeys': int(conflicts.sum()),
            'hitScanMaximum': int(state['hitScans'].max()) if len(known) else 0,
            'freeScanMaximum': int(state['freeScans'].max()) if len(known) else 0,
            'probabilityMin': float(p.min()) if len(p) else None,
            'probabilityMax': float(p.max()) if len(p) else None}


def transitions(before, after):
    import numpy as np
    b = before['known'].astype(bool) & before['occupied'].astype(bool)
    a = after['known'].astype(bool) & after['occupied'].astype(bool)
    return {'occupiedToNotOccupied': int((b & ~a).sum()),
            'notOccupiedToOccupied': int((~b & a).sum()),
            'occupiedRetained': int((b & a).sum()),
            'previouslyOccupied': int(b.sum()),
            'knownToUnknown': int((before['known'].astype(bool) & ~after['known'].astype(bool)).sum()),
            'newHitEvidenceKeys': int((after['hitScans'] > before['hitScans']).sum()),
            'newFreeEvidenceKeys': int((after['freeScans'] > before['freeScans']).sum())}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--depth-dir', type=Path, required=True)
    parser.add_argument('--transformations', type=Path, required=True)
    parser.add_argument('--diagnostic-dir', type=Path, required=True)
    parser.add_argument('--native-library', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='fresh owned output directory')
    parser.add_argument('--run-shared-map', action='store_true')
    args = parser.parse_args()
    require(args.run_shared_map, 'native execution requires explicit --run-shared-map admission')
    require(os.environ.get('COFFEE_SHARED_OUTER_GUARD') == '180', '180-second outer guard required')
    require(not args.output.exists(), 'refuse replacing any prior output')
    resource.setrlimit(resource.RLIMIT_AS, (512*1024**2, 512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU, (120, 120))
    resource.setrlimit(resource.RLIMIT_FSIZE, (32*1024**2, 32*1024**2))
    require(hasattr(os, 'sched_getaffinity'), 'single-CPU affinity support required')
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    require(len(os.sched_getaffinity(0)) == 1, 'single-CPU affinity failed')
    def time_limit(_signum, _frame):
        raise TimeoutError('internal wall limit reached')
    signal.signal(signal.SIGALRM, time_limit)
    signal.alarm(175)  # external guard has a hard 180-second total envelope
    start = time.monotonic()
    args.output.mkdir(parents=False)
    receipt = {'schema': 1, 'status': 'incomplete', 'frames': [],
               'coordinateFrame': 'P: original long-capture supplied-pose dataset world',
               'cameraConversion': 'T_frame @ diag(1,-1,-1,1); CV endpoints to saved world',
               'originalPolycamRegistration': 'absent; no original mesh input',
               'isHeldOut': False, 'physicalAuthority': False, 'routeAcceptance': False,
               'nativeConfidenceAvailable': False, 'processedExportNotNativeDepth': True,
               'geometryFilter': 'full raster; 0 < original axial depth < 4m; no floor filter',
               'excludedRaysGenerateNoEvidence': True, 'evaluatorCannotChangeMapperInput': True,
               'limits': {'cpuSeconds': 120, 'addressSpaceBytes': 512*1024**2,
                          'outerWallSeconds': 180, 'cpuAffinityCount': 1, 'fileBytes': 32*1024**2},
               'sourceSHA256': sha(Path(__file__)), 'sourcePoseContractSHA256': POSE_CONTRACT_SHA,
               'sourceProjectionSHA256': PROJECTION_SHA, 'sourceWrapperSHA256': WRAPPER_SHA,
               'nativeLibrarySHA256': LIBRARY_SHA, 'frozenSelectionSHA256': FRAME_SELECTION_SHA}
    checked_inputs = []
    try:
        frozen_path = ROOT/'FRAME_SELECTION.json'
        pose_path = ROOT/'pose_contract.py'
        projection_path = ROOT.parent/'coffee-table-retention-default-guard-source-20261029/retention.py'
        wrapper_path = ROOT.parent/'coffee-table-retention-default-guard-source-20261029/octomap_engine.py'
        for p, digest, cap in [(frozen_path, FRAME_SELECTION_SHA, 65536),
                               (pose_path, POSE_CONTRACT_SHA, 65536),
                               (projection_path, PROJECTION_SHA, 65536),
                               (wrapper_path, WRAPPER_SHA, 65536),
                               (args.native_library, LIBRARY_SHA, 2*1024**2)]:
            pinned(p, digest, cap); checked_inputs.append((p, digest, cap))
        frozen = json.loads(frozen_path.read_text())
        require(tuple(frozen['frameIDs']) == FRAMES and frozen['isHeldOut'] is False,
                'frozen non-heldout batch changed')
        selection_path = args.diagnostic_dir/'PATCH_SELECTION.json'
        for p, digest, cap in [(args.transformations, frozen['originalPosesSHA256'], 1024**2),
                               (selection_path, frozen['evaluatorSelectionSHA256'], 65536)]:
            pinned(p, digest, cap); checked_inputs.append((p, digest, cap))
        receipt['posesSHA256'] = frozen['originalPosesSHA256']
        receipt['evaluatorSelectionSHA256'] = frozen['evaluatorSelectionSHA256']
        selections = json.loads(selection_path.read_text())['frames']
        require(tuple(s['frame'] for s in selections) == FRAMES, 'evaluator frame order changed')
        metadata = json.loads(args.transformations.read_text())
        require(metadata.get('camera_model') == 'OPENCV' and
                metadata.get('orientation_override') == 'none', 'original metadata contract changed')
        frames = {}
        for frame in metadata['frames']:
            name = Path(frame['file_path']).stem
            require(name not in frames, 'duplicate source frame')
            frames[name] = frame
        pose = load_source(pose_path, 'frozen_pose_contract')
        contracts = {}
        # Validate every selected pose and depth hash before loading the native wrapper.
        for name in FRAMES:
            require(name in frames, 'missing source pose: ' + name)
            frame = frames[name]
            require(frame['file_path'] == './images/'+name+'.jpg' and
                    frame['depth_file_path'] == './depth/'+name+'.png', 'frame/image/depth association mismatch')
            contracts[name] = pose.frame_contract(frame)
            transform, origin = contracts[name]
            radial = max(math.hypot((u-frame['cx'])/frame['fl_x'],
                                    (v-frame['cy'])/frame['fl_y'])
                         for u in (0, 737) for v in (0, 993))
            max_ray = 4.*math.sqrt(1.+radial*radial)
            require(math.dist(origin, UNKNOWN_PROBE) > max_ray + math.sqrt(3)*.05,
                    'unknown probe not guaranteed outside accepted-ray envelope')
            dp = args.depth_dir/(name+'.png')
            pinned(dp, frozen['depthSHA256'][name], 1024**2)
            checked_inputs.append((dp, frozen['depthSHA256'][name], 1024**2))
        projection = load_source(projection_path, 'retained_projection')
        import numpy as np
        from PIL import Image
        engine = load_source(wrapper_path, 'retained_octomap_engine')
        engine.LIBRARY = args.native_library.resolve()
        retained = {}
        with engine.OctoMap(resolution=.05) as tree:
            defaults = tree.defaults()
            require(all(abs(defaults[k]-v) <= 1e-7 for k,v in
                        [('resolution',.05),('hit',.7),('miss',.4),('occupancy',.5)]),
                    'upstream defaults changed')
            receipt['nativeDefaults'] = defaults
            for scan_id, selection in enumerate(selections):
                name = selection['frame']; frame = frames[name]
                transform, origin = contracts[name]
                dp = args.depth_dir/(name+'.png')
                with Image.open(dp) as image:
                    require(image.size == (738,994), 'original raster size required')
                    depth = np.asarray(image)
                points, rows, cols = projection.project(depth, frame)
                require(len(points) == frozen['acceptedPointCounts'][name], 'original endpoint count changed')
                world = np.column_stack(pose.transform_coordinates(points[:,0], points[:,1], points[:,2], transform))
                require(np.isfinite(world).all(), 'nonfinite transformed endpoint')
                keys = tree.keys(world)
                unique_keys = np.unique(keys, axis=0)
                before = {key: {kind: tree.query_keys(values) for kind,values in sets.items()}
                          for key,sets in retained.items()}
                current_before = tree.query_keys(unique_keys)
                insertion = tree.insert(scan_id, world, origin)
                require(insertion['occupiedKeys'] == len(unique_keys), 'native endpoint-key count changed')
                require(insertion['treeNodes'] <= 500000, 'bounded map node cap exceeded')
                current_after = tree.query_keys(unique_keys)
                require(current_after['known'].all(), 'inserted endpoint became unknown')
                require(np.all(current_after['hitScans'] == current_before['hitScans'] + 1),
                        'endpoint vote accounting differs from one hit per scan')
                # Only now apply evaluator annotations; they never select mapper input.
                mask = projection.patch_mask(rows, cols, selection['tableInsetXYXY'])
                table_keys = np.unique(keys[mask], axis=0)
                require(len(table_keys) > 0, 'empty frozen table evaluator')
                retained[name] = {'allEndpointKeys': unique_keys, 'tableEndpointKeys': table_keys}
                history = []
                for historical, sets in retained.items():
                    states = {}
                    for kind, values in sets.items():
                        after = tree.query_keys(values)
                        require((after['hitScans'] <= scan_id+1).all() and
                                (after['freeScans'] <= scan_id+1).all(), 'per-scan vote cap exceeded')
                        states[kind] = {'after': summarize(after)}
                        if historical in before:
                            states[kind]['before'] = summarize(before[historical][kind])
                            states[kind]['transition'] = transitions(before[historical][kind], after)
                    history.append({'sourceFrame': historical, 'sets': states})
                unknown = tree.query([UNKNOWN_PROBE])
                require(not unknown['known'].any(), 'unobserved control was promoted to known')
                conversion = float(np.max(np.abs(world.astype(np.float32).astype(np.float64)-world)))
                row = {'scanID': scan_id, 'sourceFrame': name, 'depthSHA256': frozen['depthSHA256'][name],
                       'intrinsics': {k:frame[k] for k in ('fl_x','fl_y','cx','cy')},
                       'sourceCameraToWorldOpenGL': frame['transform_matrix'],
                       'cameraCVToSavedWorld': transform, 'sensorOriginSavedWorld': origin,
                       'acceptedPoints': len(points), 'zeroPixels': int((depth == 0).sum()),
                       'rangeExcludedPixels': int((depth >= 4000).sum()),
                       'worldFloat64SHA256': hashlib.sha256(world.tobytes()).hexdigest(),
                       'float32MaxAbsoluteConversionMetres': conversion,
                       'originFloat32MaxAbsoluteConversionMetres': float(np.max(np.abs(np.asarray(origin,dtype=np.float32).astype(np.float64)-origin))),
                       'uniqueEndpointKeys': len(unique_keys), 'tableEndpointPixels': int(mask.sum()),
                       'uniqueTableEndpointKeys': len(table_keys),
                       'nativeInsertion': insertion, 'currentEndpointBefore': summarize(current_before),
                       'currentEndpointAfter': summarize(current_after), 'retainedEvidenceHistory': history,
                       'unknownControlRemainsUnknown': True}
                receipt['frames'].append(row)
                del points, rows, cols, depth, world, keys, mask, before, current_before, current_after
            leaves = tree.leaves()
            require(len(leaves['xyzSizeProbability']) <= 500000, 'map leaf cap exceeded')
            # Local geometry-only artifact; receipt never includes raw image/depth arrays.
            map_path = args.output/'occupancy_leaves.npz'
            with map_path.open('xb') as stream:
                np.savez_compressed(stream, **leaves)
            receipt['mapArtifact'] = {'name': map_path.name, 'bytes': map_path.stat().st_size,
                                      'sha256': sha(map_path), 'leafCount': len(leaves['xyzSizeProbability']),
                                      'worldFrame': 'P', 'includesFreeLeaves': True,
                                      'unknownVolumeNotSerializedAsFree': True}
        for p,digest,cap in checked_inputs:
            pinned(p,digest,cap)
        receipt['inputHashesUnchangedAfter'] = True
        receipt['status'] = 'completed-observation-not-validation'
    except Exception as error:
        receipt['status'] = 'failed'
        receipt['failure'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        receipt['wallSeconds'] = time.monotonic()-start
        receipt['cpuSeconds'] = resource.getrusage(resource.RUSAGE_SELF).ru_utime + resource.getrusage(resource.RUSAGE_SELF).ru_stime
        receipt['peakRSSKiB'] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        with (args.output/'RESULT.json').open('x') as stream:
            json.dump(receipt, stream, indent=2, allow_nan=False); stream.write('\n')
        signal.alarm(0)


if __name__ == '__main__':
    main()
