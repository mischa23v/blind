#!/usr/bin/env python3
"""Prepared root-admitted fixed paired diagnostic. No search/body/contact run."""
import argparse, copy, dataclasses, hashlib, json, math, pathlib, types
H = pathlib.Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--pins', type=pathlib.Path, required=True); parser.add_argument('--pins-sha256', required=True)
    cli_args = parser.parse_args()
    manifest_bytes = cli_args.pins.read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != cli_args.pins_sha256: raise ValueError('manifest SHA mismatch')
    pins = json.loads(manifest_bytes); runtime_bytes = (H / 'runtime.py').read_bytes()
    if hashlib.sha256(runtime_bytes).hexdigest() != pins['inputs']['research/conference-geos-simplification-proposal-20261030/runtime.py']:
        raise ValueError('runtime source mismatch')
    runtime = types.ModuleType('_paired_runtime_worker'); runtime.__file__ = str(H / 'runtime.py')
    exec(compile(runtime_bytes, runtime.__file__, 'exec', dont_inherit=True), runtime.__dict__)
    runtime.check_sanitized_environment()
    manifest = runtime.Manifest(cli_args.pins, cli_args.pins_sha256)
    candidate = manifest.module('_paired_candidate', H / 'candidate.py')
    contracts = manifest.module('_paired_contracts_worker', H / 'contracts.py')
    scheduler = manifest.module('_paired_scheduler_worker', candidate.SCHEDULER)
    proposal_bytes = manifest.source(manifest.expand(pins['proposalPath']))
    mesh_bytes = manifest.source(manifest.expand(pins['meshPath']))
    if hashlib.sha256(proposal_bytes).hexdigest() != contracts.PROPOSAL_SHA or hashlib.sha256(mesh_bytes).hexdigest() != contracts.MESH_SHA:
        raise ValueError('wrong original proposal or mesh')
    proposals = json.loads(proposal_bytes)
    frozen = json.loads(manifest.source(manifest.expand(pins['baselineRoutesPath'])))
    requests = json.loads(manifest.source(manifest.expand(pins['targetsPath'])))['primaryPairs']
    if [row['name'] for row in proposals['paths']] != contracts.NAMES or [row['name'] for row in frozen['paths']] != contracts.NAMES:
        raise ValueError('all seven unchanged objectives required')
    for row, request, baseline in zip(proposals['paths'], requests, frozen['paths']):
        if row['name'] != request['name']:
            raise ValueError('objective order changed')
        for key in ('requestedStartXYZ', 'requestedGoalXYZ', 'sourcePoseIndices'):
            if row[key] != request[key] or baseline[key] != request[key]: raise ValueError('fixed endpoint/pose changed')
        if row['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ'] != baseline['chain']:
            raise ValueError('baseline centered chain changed')
    out = manifest.expand(pins['comparisonDirectory']); out.mkdir(exist_ok=False)
    model = {'status': 'started', 'error': None, 'sourcePinsSHA256': cli_args.pins_sha256,
             'proposalSHA256': contracts.PROPOSAL_SHA, 'sourceMeshSHA256': contracts.MESH_SHA,
             'registeredFloat32VerticesSHA256': None, 'trianglesInt32SHA256': None,
             'registrationAuthority': 'historicalEstimatedComparatorOnlyNotOfficialCameraMeshCalibration',
             'validatedCameraMeshAlignment': False, 'bodyWidthDepthHeightMetres': [.45, .30, 1.60], 'horizontalMarginMetres': .15,
             'toleranceMetres': .025, 'nativeConfig': None, 'nativeMarkedExclusionSpans': None,
             'nativeOwner': None, 'nativeSegmentCalls': 0, 'nativeRouteSearchExecuted': False,
             'independentCoverageEstablished': False, 'bodyComparisonExecuted': False,
             'accepted': False, 'physicalAuthority': False, 'movementExecuted': False, 'paths': [],
             'limitations': ['Historical estimated registration, not calibrated camera/body alignment.',
                             'Independent conference floor/body/head projection and coverage remain unknown.',
                             'GEOS/native corridor success is not body/margin/support acceptance.',
                             'Cumulative authored turn and event counts are diagnostic scheduling measures, not executed movement.',
                             'No contact-event percentage is calculated or used as a safety improvement.']}
    # Retain every original chain immediately, even if the attempt later stops.
    for row in proposals['paths']:
        chain = copy.deepcopy(row['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ'])
        model['paths'].append({'name': row['name'], 'sourcePoseIndices': copy.deepcopy(row['sourcePoseIndices']),
                               'unchangedCentered': {'chainXYZ': chain, 'metrics': candidate.schedule_metrics(chain), 'checks': None},
                               'geos025CenteredCandidate': {'status': 'notAttempted', 'chainXYZ': None, 'accepted': False, 'physicalAuthority': False}})
    def save():
        encoded = json.dumps(model, indent=2, allow_nan=False) + '\n'
        if len(encoded.encode()) > 15 * 1024 ** 2: raise RuntimeError('paired output cap')
        (out / 'PAIRS.json').write_text(encoded)
    save(); native = None
    try:
        original, faces = [], []
        for line in mesh_bytes.decode('utf8').splitlines():
            fields = line.split()
            if not fields: continue
            if fields[0] == 'v':
                if len(fields) != 4: raise ValueError('unsupported original vertex')
                xyz = [float(x) for x in fields[1:]]
                if not all(math.isfinite(x) for x in xyz): raise ValueError('nonfinite original vertex')
                original.append(xyz)
            elif fields[0] == 'f':
                if len(fields) != 4: raise ValueError('nontriangular original source')
                faces.append([int(x.split('/')[0]) - 1 for x in fields[1:]])
        if (len(original), len(faces)) != (18398, 29366) or min(min(f) for f in faces) < 0 or max(max(f) for f in faces) >= 18398:
            raise ValueError('original mesh cardinality/index mismatch')
        registration = json.loads(manifest.source(manifest.expand(pins['registrationPath'])))
        if registration['scale'] != 1 or not registration['acceptedForComparator'] or registration['referenceUsed']:
            raise ValueError('historical registration contract changed')
        # Exact original comparator arithmetic; confirm byte identity before Native.
        import numpy as np
        obj = np.asarray(original, dtype=np.float64); tri = np.asarray(faces, dtype=np.int32)
        Q = np.asarray(registration['rotationOBJToLevel'], dtype=np.float64)
        translation = np.asarray(registration['translationOBJToLevel'], dtype=np.float64)
        if not np.allclose(Q @ Q.T, np.eye(3), atol=1e-12, rtol=0) or abs(float(np.linalg.det(Q)) - 1) > 1e-12:
            raise ValueError('not a preserved proper rigid transform')
        level = obj @ Q.T + translation; vertices = np.c_[level[:, 0], level[:, 2], -level[:, 1]]
        vertex_sha = hashlib.sha256(np.ascontiguousarray(vertices, dtype='<f4').tobytes()).hexdigest()
        triangle_sha = hashlib.sha256(np.ascontiguousarray(tri, dtype='<i4').tobytes()).hexdigest()
        if vertex_sha != contracts.VERTEX_SHA or triangle_sha != contracts.TRIANGLE_SHA:
            raise ValueError('original registered mesh bytes changed; no native engine constructed')
        model.update(registeredFloat32VerticesSHA256=vertex_sha, trianglesInt32SHA256=triangle_sha)
        with runtime.exact_native_imports(manifest) as native_paths:
            from native_exclusion import Native
        native = Native(vertices, tri, exclusion=False)
        binary = native_paths['native_exclusion'].with_name('libblind_detour.so')
        model['nativeOwner'] = runtime.assert_native_binding(native, Native, native_paths['planner'], binary)
        config = dataclasses.asdict(native.engine.config)
        if config != contracts.NATIVE_CONFIG or native.marked_span_count != 0:
            raise ValueError('unchanged native configuration/exclusion contract failed')
        model.update(nativeConfig=config, nativeMarkedExclusionSpans=native.marked_span_count)
        callback = native.segment
        class BoundCorridor:
            def segment(self, a, b):
                model['nativeSegmentCalls'] += 1
                if model['nativeSegmentCalls'] > 2348: raise RuntimeError('native segment call cap')
                return callback(a, b)
        corridor = BoundCorridor()
        for index, row in enumerate(proposals['paths']):
            # No independent 2D scene is invented: it remains explicitly unknown.
            pair = candidate.paired_objective(row, native=corridor, corridor_scope='admitted-unchanged-native')
            if model['nativeSegmentCalls'] > 2348: raise RuntimeError('native segment call cap')
            model['paths'][index] = pair; save()
            proposed = pair['geos025CenteredCandidate']
            print(json.dumps({'objective': row['name'], 'candidateStatus': proposed['status'],
                              'original': pair['unchangedCentered']['metrics'], 'candidate': proposed.get('metrics'),
                              'wholeRouteEligibleForLaterBodyDiagnostic': proposed.get('checks', {}).get('eligibleForLaterFullBodyDiagnostic', False),
                              'physicalAuthority': False}), flush=True)
        model['status'] = 'pairedDiagnosticComplete'
        model['reviewedSummary'] = contracts.validate_result(model, proposals, frozen, scheduler.make_schedule)
        save()
    except BaseException as error:
        model.update(status='failedPartialRetained', error=type(error).__name__ + ': ' + str(error)); save(); raise
    finally:
        if native is not None: native.close()
        manifest.verify()


if __name__ == '__main__': main()
