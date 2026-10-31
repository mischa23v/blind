"""Stdlib-only terminal review; no GEOS/native/body call or acceptance path."""
import math

PROPOSAL_SHA = '0f50fbbd52df3fa4369c0784579a93a2461b6c765b052acb2daf51d15f5f290f'
MESH_SHA = '79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1'
VERTEX_SHA = '50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb'
TRIANGLE_SHA = '2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324'
NAMES = ['table_92_to_120', 'table_120_to_200', 'table_200_to_220', 'table_220_to_20', 'table_20_to_92', 'varpu_130_to_160', 'varpu_160_to_130']
NATIVE_CONFIG = {'radius': .225, 'height': 1.75, 'cell_size': .025, 'cell_height': .025, 'max_climb': .025, 'max_slope': 15, 'max_cells': 250000, 'max_nodes': 4096}
EVENT_KINDS = ('initial', 'turn', 'translate', 'stationary', 'terminal')


def require(condition, message):
    if not condition: raise ValueError(message)


def length(chain):
    require(isinstance(chain, list) and 2 <= len(chain) <= 1000, 'chain cardinality')
    require(all(isinstance(p, list) and len(p) == 3 and all(not isinstance(v, bool) and isinstance(v, (int, float)) and math.isfinite(v) for v in p) for p in chain), 'chain coordinates')
    return sum(math.dist(a, b) for a, b in zip(chain, chain[1:]))


def check_metrics(record, chain, make_schedule):
    schedule = make_schedule(chain); events = schedule['events']
    counts = {kind: sum(e['kind'] == kind for e in events) for kind in EVENT_KINDS}
    turn = sum(abs(e['dyaw']) for e in events if e['kind'] == 'turn')
    require(record['vertices'] == len(chain) and record['eventCount'] == len(events) and record['eventCounts'] == counts, 'schedule counts changed')
    for name, expected in (('lengthMetres', length(chain)), ('totalAuthoredTurnRadians', turn), ('totalAuthoredTurnDegrees', math.degrees(turn))):
        require(math.isclose(record[name], expected, rel_tol=0, abs_tol=1e-8), 'metric arithmetic mismatch: ' + name)


def check_segments(record, chain):
    require(record['nativeCorridorScope'] == 'admitted-unchanged-native', 'unverified native owner scope')
    segments = record['nativeCorridorSegments']
    require(len(segments) == len(chain) - 1 and [s['segment'] for s in segments] == list(range(len(chain) - 1)), 'incomplete segment checks')
    require(all(type(s[k]) is bool or s[k] is None for s in segments for k in ('forward', 'reverse')), 'invalid corridor evidence')
    passed = all(s['forward'] is True and s['reverse'] is True for s in segments)
    require(record['allNativeSegmentsPassBothDirections'] is passed, 'corridor result mismatch')
    two_d = record['independent2D']
    require(two_d['status'] == 'unknown' and two_d['blockers'] == ['independent_projection_coverage_contract_missing'] and two_d['live_guidance_allowed'] is False, 'missing independent coverage promoted')
    require(record['accepted'] is False and record['physicalAuthority'] is False and record['full3DValidation'] == 'requiredNotExecuted', 'unsupported acceptance/body claim')
    return passed


def validate_result(actual, proposals, frozen_routes, make_schedule):
    require(actual['status'] == 'pairedDiagnosticComplete' and actual['error'] is None, 'incomplete paired diagnostic')
    require(actual['proposalSHA256'] == PROPOSAL_SHA and actual['sourceMeshSHA256'] == MESH_SHA, 'source identity changed')
    require(actual['registeredFloat32VerticesSHA256'] == VERTEX_SHA and actual['trianglesInt32SHA256'] == TRIANGLE_SHA, 'transformed mesh identity changed')
    require(actual['nativeConfig'] == NATIVE_CONFIG and actual['nativeMarkedExclusionSpans'] == 0, 'native configuration/exclusion changed')
    require(actual['bodyWidthDepthHeightMetres'] == [.45, .30, 1.60] and actual['horizontalMarginMetres'] == .15, 'declared body/margin changed')
    require(actual['nativeOwner']['callbackBoundToKnownImplementation'] is True and actual['nativeOwner']['routeSearchCalled'] is False, 'callback binding absent')
    require(actual['nativeOwner']['sourcePath'] == 'coffee-native-replay-prepared-002/blind-clearance-centered-loop-55/planner.py' and actual['nativeOwner']['binaryPath'] == 'coffee-native-replay-prepared-002/blind-tabletop-exclusion-planner-66/libblind_detour.so', 'native owner identity changed')
    require(actual['toleranceMetres'] == .025, 'fixed tolerance changed')
    for key in ('accepted', 'physicalAuthority', 'movementExecuted', 'bodyComparisonExecuted', 'validatedCameraMeshAlignment', 'nativeRouteSearchExecuted', 'independentCoverageEstablished'):
        require(actual[key] is False, 'unsupported claim: ' + key)
    require(actual['registrationAuthority'] == 'historicalEstimatedComparatorOnlyNotOfficialCameraMeshCalibration', 'registration claim changed')
    require([p['name'] for p in actual['paths']] == NAMES == [p['name'] for p in proposals['paths']] == [p['name'] for p in frozen_routes['paths']], 'fixed objectives changed')
    counts = {'baselineRows': 7, 'baselineWholeCorridorPass': 0, 'candidateRows': 7,
              'candidateWithChain': 0, 'candidateWholeCorridorPass': 0, 'candidateEligibleForLaterBodyDiagnostic': 0,
              'candidateRejectedSimplification': 0, 'candidateRejectedFullXZTopology': 0, 'independentCoverageUnknown': 7}
    totals = {arm: {'lengthMetres': 0., 'totalAuthoredTurnDegrees': 0., 'eventCount': 0, 'turnEventCount': 0, 'includedRows': 0} for arm in ('unchangedCentered', 'geos025CenteredCandidate')}
    reported_calls = 0
    for pair, original, frozen in zip(actual['paths'], proposals['paths'], frozen_routes['paths']):
        require(pair['sourcePoseIndices'] == original['sourcePoseIndices'], 'source poses changed')
        for key in ('accepted', 'physicalAuthority', 'movementExecuted', 'defaultEnabled'):
            require(pair[key] is False, 'per-objective authority changed')
        require(pair['toleranceMetres'] == .025 and pair['independentCoverage'] == 'unknown', 'per-objective tolerance/coverage changed')
        baseline = pair['unchangedCentered']; chain = baseline['chainXYZ']
        require(chain == original['gridSelection']['clearanceGrid']['requestedConnectorChainXYZ'] == frozen['chain'], 'baseline chain changed')
        check_metrics(baseline['metrics'], chain, make_schedule)
        require(baseline['metrics']['eventCount'] == frozen['eventCount'] and baseline['metrics']['eventCounts'] == frozen['eventCounts'], 'baseline frozen schedule changed')
        base_pass = check_segments(baseline['checks'], chain); reported_calls += 2 * (len(chain) - 1)
        require(baseline['checks']['eligibleForLaterFullBodyDiagnostic'] is base_pass, 'baseline diagnostic gate changed')
        counts['baselineWholeCorridorPass'] += int(base_pass)
        candidate = pair['geos025CenteredCandidate']
        require(candidate['accepted'] is False and candidate['physicalAuthority'] is False, 'candidate accepted')
        if candidate['status'] == 'rejectedSimplification':
            require(candidate['chainXYZ'] is None and candidate['eligibleForLaterFullBodyDiagnostic'] is False and candidate.get('reason'), 'incomplete rejected candidate')
            counts['candidateRejectedSimplification'] += 1
        else:
            require(candidate['status'] in ('provisionalIndependentCoverageUnknown', 'provisionalNativeCorridorRejectedOrUnknown', 'rejectedFullXZTopology'), 'unexpected candidate status')
            graph = original['gridSelection']['clearanceGrid']['pointsXYZ']; indices = candidate['retainedSourceGraphIndices']
            require(isinstance(indices, list) and len(indices) >= 2 and all(type(i) is int and 0 <= i < len(graph) for i in indices) and all(a < b for a, b in zip(indices, indices[1:])), 'invalid retained source index sequence')
            reconstructed = [original['requestedStartXYZ']] + [graph[i] for i in indices] + [original['requestedGoalXYZ']]
            require(candidate['chainXYZ'] == reconstructed and reconstructed[:3] == chain[:3] and reconstructed[-3:] == chain[-3:], 'requested connectors/locked edges/source XYZ changed')
            cap = original['gridSelection']['lengthCapMetres']
            require(candidate['unchangedGraphLengthCapMetres'] == cap and math.isclose(cap, 1.5 * original['gridSelection']['distanceGrid']['lengthMetres'] + .5, rel_tol=0, abs_tol=1e-9), 'graph detour cap changed')
            glength = length(reconstructed[1:-1]); require(math.isclose(candidate['graphLengthMetres'], glength, rel_tol=0, abs_tol=1e-9) and glength <= cap + 1e-9, 'candidate graph length/cap')
            check_metrics(candidate['metrics'], reconstructed, make_schedule)
            corridor_pass = check_segments(candidate['checks'], reconstructed); reported_calls += 2 * (len(reconstructed) - 1)
            require(type(candidate['fullReconstructedXZSimple']) is bool, 'missing reconstructed topology evidence')
            simple = candidate['fullReconstructedXZSimple']; eligible = corridor_pass and simple
            require(candidate['checks']['eligibleForLaterFullBodyDiagnostic'] is eligible, 'candidate diagnostic gate changed')
            expected_status = 'rejectedFullXZTopology' if not simple else 'provisionalIndependentCoverageUnknown' if corridor_pass else 'provisionalNativeCorridorRejectedOrUnknown'
            require(candidate['status'] == expected_status, 'candidate status mismatch')
            counts['candidateWithChain'] += 1; counts['candidateWholeCorridorPass'] += int(corridor_pass)
            counts['candidateEligibleForLaterBodyDiagnostic'] += int(eligible)
            counts['candidateRejectedFullXZTopology'] += int(not simple)
        for arm in totals:
            entry = pair[arm]
            if entry['chainXYZ'] is not None:
                for key in ('lengthMetres', 'totalAuthoredTurnDegrees', 'eventCount'):
                    totals[arm][key] += entry['metrics'][key]
                totals[arm]['turnEventCount'] += entry['metrics']['eventCounts']['turn']; totals[arm]['includedRows'] += 1
    require(totals['unchangedCentered']['eventCount'] == 13704 and totals['unchangedCentered']['turnEventCount'] == 12049, 'baseline schedule total changed')
    require(type(actual['nativeSegmentCalls']) is int and reported_calls <= actual['nativeSegmentCalls'] <= 2348, 'native segment accounting/bound changed')
    return {'status': 'sevenPairedDiagnosticsReviewedNotAcceptance', **counts, 'totals': totals,
            'nativeSegmentCalls': actual['nativeSegmentCalls'], 'reportedSegmentCalls': reported_calls,
            'unattributedCallsOnRejectedCandidates': actual['nativeSegmentCalls'] - reported_calls,
            'physicalAuthority': False, 'bodyComparisonExecuted': False,
            'interpretation': 'Length, cumulative authored turn, event counts and whole-route diagnostic eligibility only. No contact-event percentage or safety improvement claim.'}
