"""Saved-result audit only: stdlib arithmetic/hashes; never GEOS/native/body calls.

The exact-rational XZ intersection audit below checks saved open polylines only.
It is not an obstacle/coverage validator, route generator or acceptance gate.
"""
import hashlib
import json
import math
from fractions import Fraction
from pathlib import Path
import subprocess
import types

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
WORK = REPO.parent
SOURCE = REPO / 'research/conference-geos-simplification-proposal-20261030'
ATTEMPT = WORK / 'conference-geos-simplification-attempt-001'
COMMIT = 'dad87dcc75d86e3b170201e778ccef69c76ccca4'
MANIFEST_SHA = 'd44748a362013322f5ad11ad8f30995b29d7e7021a294ce639f63b0c74c18caf'
PAIRS_SHA = '3b47960077f817b627b2868748204174020378832b50c3459c8bcdf35d73be47'
ARMS = ('unchangedCentered', 'geos025CenteredCandidate')


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def expand(name):
    path = Path(name.replace('@WORKSPACE@', str(WORK)))
    return path if path.is_absolute() else REPO / path


def checked_module(name, path, pins):
    data = path.read_bytes()
    require(hashlib.sha256(data).hexdigest() == pins[str(path.relative_to(REPO))], 'source hash')
    module = types.ModuleType(name)
    module.__file__ = str(path)
    # Only the reviewed math-only scheduler and terminal contract are loaded.
    exec(compile(data, str(path), 'exec', dont_inherit=True), module.__dict__)
    return module


def independently_count(chain):
    """Count the unchanged <=25mm / <=1deg schedule without creating events."""
    headings = [math.atan2(b[2] - a[2], b[0] - a[0])
                for a, b in zip(chain, chain[1:]) if b[0] != a[0] or b[2] != a[2]]
    yaw = headings[0]
    counts = dict(initial=1, turn=0, translate=0, stationary=0, terminal=1)
    turns = []
    length = 0.
    for a, b in zip(chain, chain[1:]):
        target = math.atan2(b[2] - a[2], b[0] - a[0]) if b[0] != a[0] or b[2] != a[2] else yaw
        delta = (target - yaw + math.pi) % (2 * math.pi) - math.pi
        if delta == -math.pi:
            delta = math.pi
        if delta:
            counts['turn'] += math.ceil(abs(delta) / (math.pi / 180.))
            turns.append(abs(delta))
            yaw += delta
        distance = math.dist(a, b)
        length += distance
        if distance:
            counts['translate'] += math.ceil(distance / .025)
        else:
            counts['stationary'] += 1
    return dict(vertices=len(chain), lengthMetres=length, eventCount=sum(counts.values()),
                eventCounts=counts, totalAuthoredTurnDegrees=math.degrees(math.fsum(turns)))


def exact_open_xz_simple(chain):
    """Exact determinants of saved binary floats, not GEOS/obstacle clearance."""
    points = [(Fraction(p[0]), Fraction(p[2])) for p in chain]
    require(points[0] != points[-1], 'audit supports open chains only')
    require(all(a != b for a, b in zip(points, points[1:])), 'audit requires nonzero XZ segments')

    def orient(a, b, c):
        return (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])

    def on(a, b, p):
        return orient(a, b, p) == 0 and all(min(a[k], b[k]) <= p[k] <= max(a[k], b[k]) for k in (0, 1))

    def meets(a, b, c, d):
        if any(max(min(a[k], b[k]), min(c[k], d[k])) > min(max(a[k], b[k]), max(c[k], d[k])) for k in (0, 1)):
            return False
        o1, o2, o3, o4 = orient(a, b, c), orient(a, b, d), orient(c, d, a), orient(c, d, b)
        return (o1*o2 < 0 and o3*o4 < 0) or on(a, b, c) or on(a, b, d) or on(c, d, a) or on(c, d, b)

    for a, b, c in zip(points, points[1:], points[2:]):
        if orient(a, b, c) == 0 and sum((b[k]-a[k])*(c[k]-b[k]) for k in (0, 1)) < 0:
            return False  # Adjacent overlap/backtracking, beyond their shared endpoint.
    segments = list(zip(points, points[1:]))
    return not any(meets(a, b, c, d) for i, (a, b) in enumerate(segments)
                   for c, d in segments[i+2:])


def main():
    manifest_path = SOURCE / 'SOURCE_PINS.json'
    require(digest(manifest_path) == MANIFEST_SHA, 'manifest identity')
    manifest = read(manifest_path)
    pins = manifest['inputs']
    require(len(pins) == 42, 'pin count')
    for name, expected in pins.items():
        require(digest(expand(name)) == expected, 'current pin mismatch: ' + name)
        if not name.startswith(('@WORKSPACE@', '/')):
            committed = subprocess.run(['git', 'show', COMMIT + ':' + name], cwd=REPO,
                                       capture_output=True, check=True).stdout
            require(hashlib.sha256(committed).hexdigest() == expected, 'commit pin mismatch: ' + name)
    committed_manifest = subprocess.run(['git', 'show', COMMIT + ':' + str(manifest_path.relative_to(REPO))],
                                        cwd=REPO, capture_output=True, check=True).stdout
    require(hashlib.sha256(committed_manifest).hexdigest() == MANIFEST_SHA, 'committed manifest identity')

    guard_path = ATTEMPT / 'GUARD_RUN/RESULT.json'
    pairs_path = ATTEMPT / 'comparison/PAIRS.json'
    guard, pairs = read(guard_path), read(pairs_path)
    require(digest(pairs_path) == PAIRS_SHA, 'saved pairs identity')
    require(guard['sourceCommit'] == COMMIT and guard['status'] == 'completed-zero-exit', 'guard completion')
    require(guard['manifestSHA256'] == pairs['sourcePinsSHA256'] == MANIFEST_SHA, 'manifest provenance')
    require(guard['pins'] == manifest and guard['inputHashesBefore'] == guard['inputHashesAfter'] == pins, 'guard pins')
    require([c['label'] for c in guard['commands']] == ['controls', 'comparison'], 'commands')
    require(all(c['exitCode'] == 0 and c['groupRetired'] is True for c in guard['commands']), 'terminal process state')
    for name, entry in guard['finalPayloadInventory'].items():
        if 'sha256' in entry:
            path = ATTEMPT / name
            require(digest(path) == entry['sha256'] and path.stat().st_size == entry['bytes'], 'payload inventory: ' + name)
    control = guard['authoredControls']
    require(control['status'] == 'passed' and control['count'] == 17 and
            control['failures'] == control['errors'] == control['skipped'] == 0, 'authored controls')
    require(read(ATTEMPT / 'GUARD_RUN/controls.stdout') == control, 'control readback')

    original = read(expand(manifest['proposalPath']))
    frozen = read(expand(manifest['baselineRoutesPath']))
    targets = read(expand(manifest['targetsPath']))['primaryPairs']
    scheduler = checked_module('review_scheduler', REPO / 'research/conference-body-source-20261029/schedule_source.py', pins)
    contract = checked_module('review_contract', SOURCE / 'contracts.py', pins)
    reviewed = contract.validate_result(pairs, original, frozen, scheduler.make_schedule)
    require(reviewed == pairs['reviewedSummary'] == guard['comparison'], 'terminal summary mismatch')
    # Four tiny arithmetic controls, unrelated to the actual 17 executed upstream-adapter controls.
    require(exact_open_xz_simple([[0,0,0], [1,0,0], [2,0,1]]), 'simple-line audit control')
    require(not exact_open_xz_simple([[0,0,0], [2,0,2], [0,0,2], [2,0,0]]), 'crossing audit control')
    require(not exact_open_xz_simple([[0,0,0], [2,0,0], [1,0,0]]), 'adjacent overlap audit control')
    require(not exact_open_xz_simple([[0,0,0], [2,0,0], [1,0,1], [1,0,0]]), 'nonadjacent touch audit control')

    rows = []
    for row, source, target in zip(pairs['paths'], original['paths'], targets):
        require(row['name'] == source['name'] == target['name'], 'target name')
        require(row['sourcePoseIndices'] == target['sourcePoseIndices'], 'target pose identity')
        for arm in ARMS:
            chain = row[arm]['chainXYZ']
            require(chain[0] == target['requestedStartXYZ'] and chain[-1] == target['requestedGoalXYZ'], 'exact requested endpoints')
            count = independently_count(chain)
            for key in ('vertices', 'eventCount', 'eventCounts'):
                require(count[key] == row[arm]['metrics'][key], 'independent schedule count: ' + key)
            for key in ('lengthMetres', 'totalAuthoredTurnDegrees'):
                require(math.isclose(count[key], row[arm]['metrics'][key], rel_tol=0, abs_tol=1e-8), 'independent metric: ' + key)
        candidate = row[ARMS[1]]
        require(candidate['fullReconstructedXZSimple'] is True and exact_open_xz_simple(candidate['chainXYZ']), 'full reconstructed saved-XZ simplicity')
        rows.append({
            'name': row['name'], 'sourcePoseIndices': row['sourcePoseIndices'],
            'baselineUnchanged': True, 'exactRequestedEndpoints': True,
            'orderedOriginalXYZSubsequence': True, 'connectorsAndFirstLastGraphEdgesUnchanged': True,
            'savedGEOSFullXZSimple': True, 'independentSavedXZExactIntersectionAuditSimple': True,
            'originalGraphLengthCapRetained': True,
            **{arm: row[arm]['metrics'] for arm in ARMS},
            'baselineNativeSegments': len(row[ARMS[0]]['chainXYZ'])-1,
            'candidateNativeSegments': len(candidate['chainXYZ'])-1,
            'bothArmsWholeNativeCorridorPass': True,
            'candidateEligibleForSeparateFullBodyDiagnostic': True,
            'independentCoverage': 'unknown', 'accepted': False,
        })
    require(pairs['paths'][5][ARMS[1]]['chainXYZ'] == list(reversed(pairs['paths'][6][ARMS[1]]['chainXYZ'])), 'reverse geometry changed')
    totals = reviewed['totals']
    reductions = {key: {'absolute': totals[ARMS[0]][key] - totals[ARMS[1]][key],
                        'percent': 100 * (1 - totals[ARMS[1]][key] / totals[ARMS[0]][key])}
                  for key in ('lengthMetres', 'totalAuthoredTurnDegrees', 'eventCount', 'turnEventCount')}
    result = {
        'status': 'savedResultIndependentlyRecountedNotPhysicalAcceptance',
        'sourceCommit': COMMIT, 'manifestSHA256': MANIFEST_SHA,
        'pairsSHA256': PAIRS_SHA, 'guardReceiptSHA256': digest(guard_path),
        'reviewSourceSHA256': digest(Path(__file__)),
        'matchedInputPins': len(pins), 'matchedBeforeAfterPins': True,
        'matchedFinalPayloadFiles': sum('sha256' in e for e in guard['finalPayloadInventory'].values()),
        'fixedToleranceMetres': .025, 'retainedObjectives': 7, 'includedRowsPerArm': 7,
        'authoredControlsActuallyPassed': 17,
        'guard': {k: guard[k] for k in ('status', 'aggregateCPUSeconds', 'wallSeconds', 'peakObservedAggregateRSS', 'limits')},
        'summary': reviewed, 'reductionsInDiagnosticMetricsOnly': reductions, 'rows': rows,
        'reverseCandidateExactlyReversed': True,
        'reviewMethod': 'Stdlib hash/inventory/commit checks; exact-byte math-only scheduler and terminal contract readback; independent event-count/length/total-turn arithmetic; exact rational intersections of saved candidate XZ chains. No native, GEOS, scientific library or body-engine import/call in this review.',
        'interpretation': 'Seven paired geometry/scheduling diagnostics, not seven independent scenes or physical journeys. All candidates provisional; native corridor and simple topology do not establish obstacle clearance, independent coverage, body/margin/support acceptance or calibrated alignment.',
        'geosOrNativeCallsByReview': 0, 'bodyComparisonExecutedByThisAttempt': False,
        'independentCoverageEstablished': False, 'physicalAuthority': False, 'movementExecuted': False,
    }
    (HERE / 'RESULT_REVIEW.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'status': result['status'], 'matchedPins': len(pins), 'totals': totals,
                      'reductions': reductions, 'nativeSegmentCalls': reviewed['nativeSegmentCalls'],
                      'guardSHA256': result['guardReceiptSHA256']}, indent=2))


if __name__ == '__main__':
    main()
