"""Opt-in paired glue. Importing this module never loads GEOS/routing libraries.

No CLI, default activation, route search, custom simplifier, or physical acceptance.
The caller must separately admit/pin the native owner and bound the whole process.
"""
import copy
import ctypes as C
import hashlib
import math
import pathlib
import types

H = pathlib.Path(__file__).resolve().parent
R = H.parents[1]
TOLERANCE_METRES = 0.025  # Declared before any result; never a caller parameter.
MAX_POINTS = 1000
NAMES = ['table_92_to_120', 'table_120_to_200', 'table_200_to_220',
         'table_220_to_20', 'table_20_to_92', 'varpu_130_to_160', 'varpu_160_to_130']
VALIDATOR = R / 'research/independent-2d-route-validator-20261029/validator.py'
VALIDATOR_SHA = '7b86a1a5c38bc503d2f673434a158b7312713c0e20c177a03e6ef56c891c9619'
SCHEDULER = R / 'research/conference-body-source-20261029/schedule_source.py'
SCHEDULER_SHA = 'eb6bee87b245d10fa7cb07d3a34e9dc4cc45a49e21f2b64440b6ec09bf83bdbd'
GEOS_FILES = {
    '/usr/lib/x86_64-linux-gnu/libgeos.so.3.13.1': '6c45eaeaa14224a136814fde55a67de4d7ff030c77aa0dc147e9a34dcd0c9379',
    '/usr/lib/x86_64-linux-gnu/libgeos_c.so.1.19.2': '50a74a5e45e18803ee2af907724cfc824add2294b9d273849e8f206bcf45591f',
}
GEOS_CAPI = '/usr/lib/x86_64-linux-gnu/libgeos_c.so.1.19.2'


def source_module(name, path, expected):
    source_bytes = path.read_bytes()
    if hashlib.sha256(source_bytes).hexdigest() != expected:
        raise ValueError('reused source pin mismatch: ' + path.name)
    module = types.ModuleType(name)
    module.__file__ = str(path)
    # Execute precisely the checked bytes: no second path read or cached .pyc.
    exec(compile(source_bytes, str(path), 'exec', dont_inherit=True), module.__dict__)
    return module


def existing_validator():
    for path, expected in GEOS_FILES.items():
        if hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() != expected:
            raise ValueError('GEOS binary pin mismatch')
    v = source_module('_conference_existing_2d', VALIDATOR, VALIDATOR_SHA)
    def pinned_library(name):
        if name != 'geos_c':
            raise ValueError('unrecognized GEOS library request')
        return GEOS_CAPI
    # Only this fresh module's resolver changes; the unchanged owner still binds
    # and frees its geometries. No global ctypes/find_library monkeypatch.
    v.ctypes = types.SimpleNamespace(util=types.SimpleNamespace(find_library=pinned_library))
    base_owner = v.GEOS
    class PinnedOwner(base_owner):
        def __init__(self):
            super().__init__()
            try:
                check_geos_owner(self)
            except BaseException:
                self.close()
                raise
    v.GEOS = PinnedOwner
    return v


def check_geos_owner(g):
    if g.version != '3.13.1-CAPI-1.19.2' or g.lib._name != GEOS_CAPI:
        raise ValueError('unexpected GEOS version or primary library')
    expected = {str(pathlib.Path(p).resolve()): digest for p, digest in GEOS_FILES.items()}
    mapped = set()
    for line in pathlib.Path('/proc/self/maps').read_text().splitlines():
        fields = line.split(maxsplit=5)
        if len(fields) < 6 or not fields[5].startswith('/'):
            continue
        name = fields[5]
        if pathlib.Path(name).name.startswith(('libgeos.', 'libgeos_c.')):
            if name.endswith(' (deleted)'):
                raise ValueError('deleted GEOS mapping refused')
            mapped.add(str(pathlib.Path(name).resolve()))
    if mapped != set(expected):
        raise ValueError('unexpected GEOS mapped primary/dependency set')
    for path, digest in expected.items():
        if hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() != digest:
            raise ValueError('mapped GEOS binary bytes differ')


def checked_points(points):
    if not isinstance(points, list) or not 2 <= len(points) <= MAX_POINTS:
        raise ValueError('bounded nonempty polyline required')
    if any(not isinstance(p, list) or len(p) != 3 or any(isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x) or abs(x) > 1e6 for x in p) for p in points):
        raise ValueError('finite original XYZ required')
    return copy.deepcopy(points)


def geos_simplify_xz(points_xz):
    """Only upstream GEOS chooses retained vertices; output has no acceptance."""
    v = existing_validator()
    g = v.GEOS()
    try:
        check_geos_owner(g)
        p = C.c_void_p
        def bind(name, args, result):
            fn = getattr(g.lib, name); fn.argtypes = args; fn.restype = result
            return fn
        simplify = bind('GEOSTopologyPreserveSimplify_r', [p, p, C.c_double], p)
        simple = bind('GEOSisSimple_r', [p, p], C.c_byte)
        kind = bind('GEOSGeomTypeId_r', [p, p], C.c_int)
        sequence = bind('GEOSGeom_getCoordSeq_r', [p, p], p)
        size = bind('GEOSCoordSeq_getSize_r', [p, p, C.POINTER(C.c_uint)], C.c_int)
        get_xy = bind('GEOSCoordSeq_getXY_r', [p, p, C.c_uint, C.POINTER(C.c_double), C.POINTER(C.c_double)], C.c_int)
        original = g.geometry('LINESTRING(' + v.coords(points_xz) + ')')
        if simple(g.ctx, original) != 1:
            raise ValueError('non-simple source line refused')
        result = simplify(g.ctx, original, TOLERANCE_METRES)
        if not result:
            raise ValueError('GEOS simplification failed')
        g.owned.append(result)
        if kind(g.ctx, result) != 1 or g.valid(g.ctx, result) != 1 or simple(g.ctx, result) != 1:
            raise ValueError('invalid/non-simple/non-LineString GEOS output')
        seq = sequence(g.ctx, result); count = C.c_uint()
        if not seq or size(g.ctx, seq, C.byref(count)) != 1 or not 2 <= count.value <= len(points_xz):
            raise ValueError('invalid GEOS output cardinality')
        output = []
        for i in range(count.value):
            x, z = C.c_double(), C.c_double()
            if get_xy(g.ctx, seq, i, C.byref(x), C.byref(z)) != 1 or not all(math.isfinite(a) for a in (x.value, z.value)):
                raise ValueError('GEOS coordinate extraction failed')
            output.append([x.value, z.value])
        return output
    finally:
        g.close()


def geos_full_chain_simple(chain):
    """The inner simplifier alone cannot certify reattached locked segments."""
    chain = checked_points(chain)
    v = existing_validator(); g = v.GEOS()
    try:
        check_geos_owner(g)
        simple = g.lib.GEOSisSimple_r
        simple.argtypes = [C.c_void_p, C.c_void_p]; simple.restype = C.c_byte
        line = g.geometry('LINESTRING(' + v.coords([[p[0], p[2]] for p in chain]) + ')')
        answer = simple(g.ctx, line)
        if answer not in (0, 1):
            raise ValueError('full-chain GEOS simplicity check failed')
        return answer == 1
    finally:
        g.close()


def recover_original_xyz(graph, simplified_middle_xz):
    """Strict identity/order check, not nearest matching or geometric search."""
    lookup = {}
    for index, p in enumerate(graph):
        key = (p[0], p[2])
        if key in lookup:
            raise ValueError('ambiguous repeated source XZ; no Y reconstruction')
        lookup[key] = index
    middle_indices = []
    for p in simplified_middle_xz:
        if not isinstance(p, list) or len(p) != 2 or any(isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x) for x in p) or tuple(p) not in lookup:
            raise ValueError('GEOS output is not an exact original XZ vertex')
        middle_indices.append(lookup[tuple(p)])
    if not middle_indices or middle_indices[0] != 1 or middle_indices[-1] != len(graph) - 2:
        raise ValueError('locked first/last graph edges changed')
    if any(b <= a for a, b in zip(middle_indices, middle_indices[1:])):
        raise ValueError('output is not an ordered original subsequence')
    indices = [0] + middle_indices + [len(graph) - 1]
    return [copy.deepcopy(graph[i]) for i in indices], indices


def schedule_metrics(chain):
    scheduler = source_module('_conference_existing_schedule', SCHEDULER, SCHEDULER_SHA)
    schedule = scheduler.make_schedule(chain)
    total_turn = sum(abs(e['dyaw']) for e in schedule['events'] if e['kind'] == 'turn')
    return {'vertices': len(chain), 'lengthMetres': sum(math.dist(a, b) for a, b in zip(chain, chain[1:])),
            'eventCount': len(schedule['events']), 'totalAuthoredTurnRadians': total_turn,
            'totalAuthoredTurnDegrees': math.degrees(total_turn),
            'eventCounts': {kind: sum(e['kind'] == kind for e in schedule['events']) for kind in ('initial', 'turn', 'translate', 'stationary', 'terminal')}}


def check_segments(chain, native, scene, frame, revision, now, corridor_scope):
    chain = checked_points(chain)
    corridor = []
    for index, (a, b) in enumerate(zip(chain, chain[1:])):
        results = []
        for start, goal in ((a, b), (b, a)):
            try:
                value = native.segment(start, goal) if native is not None else None
                results.append(value if type(value) is bool else None)
            except Exception:
                results.append(None)
        corridor.append({'segment': index, 'forward': results[0], 'reverse': results[1]})
    corridor_pass = all(x['forward'] is True and x['reverse'] is True for x in corridor)
    if scene is None or frame is None or revision is None or now is None:
        two_d = {'status': 'unknown', 'blockers': ['independent_projection_coverage_contract_missing'], 'live_guidance_allowed': False}
    else:
        v = existing_validator()
        two_d = v.validate({'points': [[p[0], p[2]] for p in chain], 'frame': frame, 'revision': revision}, scene, now)
        if two_d.get('geos_version') not in (None, '3.13.1-CAPI-1.19.2'):
            raise ValueError('unexpected independent-2D GEOS version')
    return {'nativeCorridorScope': corridor_scope, 'nativeCorridorSegments': corridor,
            'allNativeSegmentsPassBothDirections': corridor_pass, 'independent2D': two_d,
            # Missing independent evidence blocks acceptance, not a diagnostic 3D test.
            'eligibleForLaterFullBodyDiagnostic': corridor_pass and corridor_scope == 'admitted-unchanged-native' and two_d['status'] != 'rejected',
            'accepted': False, 'full3DValidation': 'requiredNotExecuted', 'physicalAuthority': False}


def paired_objective(row, *, native=None, corridor_scope='not-established', scene=None, frame=None, revision=None, now=None):
    """No search or fallback. Retain baseline and an explicit candidate outcome."""
    if corridor_scope not in ('not-established', 'authored-control-stub', 'admitted-unchanged-native'):
        raise ValueError('explicit corridor evidence scope required')
    selected = row['gridSelection']['clearanceGrid']
    graph = checked_points(selected['pointsXYZ'])
    original = checked_points(selected['requestedConnectorChainXYZ'])
    if original != [row['requestedStartXYZ']] + graph + [row['requestedGoalXYZ']]:
        raise ValueError('original requested connectors changed')
    cap = row['gridSelection']['lengthCapMetres']
    shortest = row['gridSelection']['distanceGrid']['lengthMetres']
    if not math.isfinite(cap) or cap < 0 or not math.isfinite(shortest) or shortest < 0 or not math.isclose(cap, 1.5 * shortest + .5, rel_tol=0, abs_tol=1e-9):
        raise ValueError('invalid original graph cap')
    evidence_args = (native, scene, frame, revision, now, corridor_scope)
    baseline = {'chainXYZ': original, 'metrics': schedule_metrics(original), 'checks': check_segments(original, *evidence_args)}
    pair = {'name': row['name'], 'sourcePoseIndices': copy.deepcopy(row['sourcePoseIndices']),
            'toleranceMetres': TOLERANCE_METRES, 'unchangedCentered': baseline,
            'geos025CenteredCandidate': None, 'defaultEnabled': False, 'accepted': False,
            'physicalAuthority': False, 'movementExecuted': False, 'independentCoverage': 'unknown'}
    try:
        # Even an unchanged short chain must not reconstruct ambiguous XZ heights.
        if len({(p[0], p[2]) for p in graph}) != len(graph):
            raise ValueError('ambiguous repeated source XZ; no Y reconstruction')
        if len(graph) < 4:
            simplified, indices = copy.deepcopy(graph), list(range(len(graph)))
        else:
            middle = [[p[0], p[2]] for p in graph[1:-1]]
            simplified, indices = recover_original_xyz(graph, geos_simplify_xz(middle))
        chain = [copy.deepcopy(row['requestedStartXYZ'])] + simplified + [copy.deepcopy(row['requestedGoalXYZ'])]
        if chain[:3] != original[:3] or chain[-3:] != original[-3:]:
            raise ValueError('requested connector or locked graph edge changed')
        graph_length = sum(math.dist(a, b) for a, b in zip(simplified, simplified[1:]))
        if graph_length > cap + 1e-9:
            raise ValueError('candidate exceeds unchanged original graph cap')
        full_xz_simple = geos_full_chain_simple(chain)
        checks = check_segments(chain, *evidence_args)
        status = 'provisionalIndependentCoverageUnknown'
        if not checks['allNativeSegmentsPassBothDirections']:
            status = 'provisionalNativeCorridorRejectedOrUnknown'
        if checks['independent2D']['status'] == 'rejected':
            status = 'rejectedIndependent2D'
        if not full_xz_simple:
            status = 'rejectedFullXZTopology'
            checks['eligibleForLaterFullBodyDiagnostic'] = False
        pair['geos025CenteredCandidate'] = {'status': status, 'chainXYZ': chain, 'retainedSourceGraphIndices': indices,
                                           'fullReconstructedXZSimple': full_xz_simple,
                                           'graphLengthMetres': graph_length, 'unchangedGraphLengthCapMetres': cap,
                                           'metrics': schedule_metrics(chain), 'checks': checks,
                                           'accepted': False, 'physicalAuthority': False}
    except Exception as error:
        pair['geos025CenteredCandidate'] = {'status': 'rejectedSimplification', 'reason': type(error).__name__ + ': ' + str(error),
                                           'chainXYZ': None, 'accepted': False, 'physicalAuthority': False,
                                           'eligibleForLaterFullBodyDiagnostic': False}
    return pair


def paired_all_seven(proposals, **evidence):
    if [p['name'] for p in proposals['paths']] != NAMES:
        raise ValueError('all seven fixed ordered objectives required')
    return {'status': 'pairedDiagnosticOnlyNotAcceptance', 'paths': [paired_objective(row, **evidence) for row in proposals['paths']],
            'allSevenObjectivesRetained': True, 'accepted': False, 'physicalAuthority': False, 'movementExecuted': False}
