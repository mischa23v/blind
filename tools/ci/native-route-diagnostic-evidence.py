#!/usr/bin/env python3
"""Read ONLY authored public Apple-fixture/synthetic JSON into existing evidence.

Exact per-test `export attachments --test-id` and manifest keys follow the
existing export-practice-layout-screenshots.py / Chromium Xcode16LogParser:
https://chromium.googlesource.com/chromium/src/+/HEAD/ios/build/bots/scripts/xcode_log_parser.py
https://developer.apple.com/documentation/xcode-release-notes/xcode-16_3-release-notes
Temporary per-test exports are bounded and deleted. Only the fixed JSON report
is opened; unrelated attachment names/contents never enter evidence.

No source/outcome changes, retries, screenshots, logs, private history, audio or
model output. Unknown schema is an explicit evidence error, NOT a test verdict.
"""
import hashlib
import json
import math
import os
import resource
import signal
import stat
import subprocess
import tempfile
import time
from pathlib import Path
import re

LIMIT = 1024 * 1024
BASE = 'ee8f183ca4d7b6fd9aabecf2f7cd8d39bc472ce071873bceafe4c557f65f8123'
WIDTH = 'c52792a1213a1b3969e97a6201d43bac2426a444f3f39e8b906a5feb0e0f701d'
JOURNEY = '8e060627d0f570820fd00a427e22f6672eb50048611dfc9682986cac5c30cc9a'
FIXTURES = {'Hallway2': 'f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d',
            'Bedroom3': '44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e'}
SPECS = (
    ('SavedRoomRouteDiagnosticAppleTests/testPredeclaredApplePathsWaypointSinkAndIndependentFullBodySweeps',
     'APPLE_ROOM_ROUTE_original-baseline_OUTCOMES.json', 'original-baseline'),
    ('SavedRoomRouteDiagnosticAppleTests/testSeparatelyPreregistered28cmWidthDoesNotReplaceBaseline',
     'APPLE_ROOM_ROUTE_width28-addendum_OUTCOMES.json', 'width28-addendum'),
    ('SavedRoomRouteJourneyAppleTests/testPredeclaredSuppliedBedChairConnectorsAroundRoomDoorWithholdingAndReturn',
     'APPLE_SUPPLIED_POSTURE_JOURNEY_OUTCOMES.json', 'journey'))
# Optional additive witnesses: older xcresults keep the original three reports.
# No suite-wide export or general-purpose test/attachment matching is permitted.
DIAGNOSTIC_SPECS = (
    ('SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleExportMetadataAndNodeInventory',
     'APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json', 'metadata-inventory'),
    ('SavedRoomRouteCollisionOracleTests/testBackendDiagnosticMatrixRecordsEveryControl',
     'SavedRoomCollisionBackendMatrix-v1.json', 'collision-backend'))
DIAGNOSTIC_LIMIT = 131072
CONTROL_NAMES = ('thinWallForward', 'thinWallReverse', 'wallInitialOverlap', 'wallTerminalOverlap',
                 'containedSolid', 'overheadTallForward', 'overheadTallReverse', 'overheadShort', 'clear', 'floor')
STATUSES = {'Success': 'Passed', 'Failure': 'Failed', 'Skipped': 'Skipped', 'Expected Failure': 'Expected Failure'}


class EvidenceError(ValueError):
    """Only fixed, authored codes may leave this parser; never dump raw errors."""


def require(condition, code):
    if not condition:
        raise EvidenceError(code)


def decode(raw):
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, 'duplicate_json_key')
            result[key] = value
        return result
    def bad_constant(_):
        raise EvidenceError('nonfinite_number')
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=bad_constant)


def canonical(identifier):
    if not isinstance(identifier, str):
        return None
    stripped = identifier.removesuffix('()')
    if stripped.startswith('BlindAssistTests/'):
        stripped = stripped[len('BlindAssistTests/'):]
    return stripped if stripped in {s[0] for s in SPECS + DIAGNOSTIC_SPECS} else None


def export_size(directory):
    """No recursion or file reads: reject links, subdirectories and large exports."""
    require(not directory.is_symlink(), 'unsupported_export_entry')
    if not directory.exists(): return 0
    total = count = 0
    with os.scandir(directory) as entries:
        for entry in entries:
            count += 1
            require(count <= 8, 'export_file_count_over_budget')
            info = entry.stat(follow_symlinks=False)
            require(stat.S_ISREG(info.st_mode), 'unsupported_export_entry')
            total += info.st_size
            require(total <= LIMIT + 65536, 'export_over_budget')
    return total


def export_test(bundle, identifier, destination):
    """Exact allowlisted case only; owned child timeout/file/count/aggregate bounds."""
    require(canonical(identifier) is not None, 'unapproved_test_identifier')
    def bound_file():
        resource.setrlimit(resource.RLIMIT_FSIZE, (LIMIT, LIMIT))
    command = ['xcrun','xcresulttool','export','attachments','--path',str(bundle),
               '--test-id',identifier,'--output-path',str(destination)]
    process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               start_new_session=True, preexec_fn=bound_file)
    try:
        deadline = time.monotonic() + 30
        while process.poll() is None:
            export_size(destination)
            require(time.monotonic() < deadline, 'attachment_export_timeout')
            time.sleep(.05)
        export_size(destination)
        require(process.returncode == 0, 'attachment_export_failed')
    finally:
        try: os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError: pass
        process.wait()


def exported_report(directory, name):
    export_size(directory)
    manifest = directory / 'manifest.json'
    require(not manifest.is_symlink() and manifest.stat().st_size <= 65536, 'invalid_export_manifest')
    entries = decode(manifest.read_bytes())
    require(isinstance(entries, list) and len(entries) == 1, 'unsupported_export_manifest')
    entry = entries[0]
    require(isinstance(entry, dict) and isinstance(entry.get('attachments'), list), 'unsupported_export_manifest')
    require(len(entry['attachments']) <= 7, 'export_file_count_over_budget')
    selected = []
    # xcresulttool adds an index/identifier suffix to its human-readable name.
    # Match only this exact authored basename (with optional exporter suffix).
    stem = name.removesuffix('.json')
    pattern = re.compile(re.escape(stem) + r'(?:\.json)?(?:_[0-9]+_[A-Za-z0-9-]{1,100})?\.json')
    for item in entry['attachments']:
        require(isinstance(item, dict), 'unsupported_attachment_schema')
        suggested = item.get('suggestedHumanReadableName')
        require(isinstance(suggested, str), 'unsupported_attachment_schema')
        if suggested != name and not pattern.fullmatch(suggested):
            # No unrelated content is opened, even if it claims JSON.
            raise EvidenceError('unexpected_test_attachment')
        if 'uniformTypeIdentifier' in item:
            require(item['uniformTypeIdentifier'] == 'public.json', 'unsupported_attachment_type')
        if 'payloadSize' in item:
            require(type(item['payloadSize']) is int and 0 < item['payloadSize'] <= LIMIT, 'attachment_over_budget')
        filename = item.get('exportedFileName')
        require(isinstance(filename, str) and 0 < len(filename) <= 512 and
                '/' not in filename and '\\' not in filename and '\x00' not in filename and
                filename not in ('.','..') and filename.endswith('.json'), 'invalid_attachment_filename')
        path = directory / filename
        require(not path.is_symlink() and path.resolve().parent == directory.resolve(), 'attachment_path_escape')
        require(path.is_file() and 0 < path.stat().st_size <= LIMIT, 'attachment_over_budget')
        selected.append(path)
    require(len(selected) == 1, 'missing_attachment' if not selected else 'duplicate_attachment')
    return selected[0].read_bytes()


def sources(repo):
    """Pinned public data and protocols; no user files or paths enter the report."""
    root = repo / 'ios/BlindAssistTests/Fixtures'
    expected = {f'RoomRouteDiagnostic/{name}.json': digest for name, digest in
                [('PROTOCOL', BASE), ('PROFILE_28CM_ADDENDUM', WIDTH), ('JOURNEY_ADDENDUM', JOURNEY)]}
    expected.update({f'RoomPlanApple/{room}.capturedRoom.json': digest for room, digest in FIXTURES.items()})
    documents, hashes = {}, {}
    for name, digest in expected.items():
        path = root / name
        require(not path.is_symlink() and path.stat().st_size <= LIMIT, 'invalid_source_file')
        raw = path.read_bytes()
        require(hashlib.sha256(raw).hexdigest() == digest, 'source_hash_mismatch')
        documents[name] = decode(raw)
        hashes['ios/BlindAssistTests/Fixtures/' + name] = digest
    uuids = {}
    for room in FIXTURES:
        doc = documents[f'RoomPlanApple/{room}.capturedRoom.json']
        uuids[room] = {item['identifier'] for kind in ('floors','walls','doors','windows','openings','objects') for item in doc[kind]}
    for name in ('ios/BlindAssistTests/SavedRoomRouteDiagnosticAppleTests.swift',
                 'ios/BlindAssistTests/SavedRoomRouteJourneyAppleTests.swift',
                 'ios/BlindAssistTests/SavedRoomRouteMeshAppleFixtureTests.swift',
                 'ios/BlindAssistTests/SavedRoomRouteCollisionOracleTests.swift',
                 'ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift',
                 'ios/BlindAssist/SavedRoomRouteMeshAdapter.swift',
                 'BlindCore/Sources/BlindCore/SpatialFacts.swift',
                 'BlindCore/Sources/BlindCore/GuidanceCadence.swift'):
        path = repo / name
        require(not path.is_symlink() and path.stat().st_size <= LIMIT, 'invalid_source_file')
        hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return documents, uuids, hashes


FALSE_FIELDS = {'physicalAuthority','fullFootprintSupportVerified','cameraLocalizationTested',
                'getUpKinematicsTested','currentCoverageKnown','currentDoorStateKnown',
                'sustainedControllerTested','VoiceOverTested'}
BOOL_FIELDS = {'initialBodyContact','initialMarginContact','waypointSinkDelivered','nativeComplete',
               'bodyContact','marginContact','expectedWithhold','historicalDoorOpen','guidanceDelivered'}
VECTORS = {'requestedStart','requestedGoal','projectedStart','projectedGoal','originalSuppliedStandingPoint',
           'declaredHeading','replayPositionAfterStage','from','to'}
NUMBERS = {'rawRadius','rawHeight','effectiveRadius','effectiveHeight','startProjectionMetres',
           'goalProjectionMetres','angleDegrees','horizontalMetres','syntheticSeconds'}
IDS = {'initialFurnitureBoundIDs','floorContactIDs','obstacleSurfaceIDs','furnitureBoundIDs','closedDoorStraightProbeContactIDs'}
FAILURES = {'wrongExecutionContext','sourceMismatch','invalidSource','unsupportedGeometry','exportFailed',
            'missingMetadata','invalidMesh','sourceGeometryMismatch','budgetExceeded','invalidGeometry',
            'invalidQuery','invalidFurnitureBox','invalidInput','unavailable','stale','nativeFailure'}
METADATA_FAILURES = {'wrongExecutionContext','sourceMismatch','invalidSource','unsupportedGeometry','exportFailed',
                     'invalidMesh','sourceGeometryMismatch','budgetExceeded','metadataReadFailed','metadataDecodeFailed',
                     'metadataEmpty','metadataInvalidEntries','meshNodeMissingMetadata','metadataUnknownFeature','unclassifiedError'}
FAILURES.update(METADATA_FAILURES - {'unclassifiedError'})
FAILURES.update('backendUnavailable("' + message + '")' for message in (
    'unassociated physics contact', 'bidirectional thin-plane continuous sweep',
    'contained-cylinder initial overlap distinct from shell', 'bidirectional height-sensitive overhead sweep',
    'negative sweep control', 'separate floor contact'))
SEGMENT_PATTERN = r'(?:requested-start-to-projection|projection-to-detour-start|detour-segment-[1-9][0-9]{0,3}|detour-end-to-projection|projection-to-requested-goal)'
DIRECTIONS = {'ahead':'ahead','aheadLeft':'ahead, slightly left','aheadRight':'ahead, slightly right',
              'left':'on your left','right':'on your right','behindLeft':'behind you on the left',
              'behindRight':'behind you on the right','behind':'behind you'}


def number(value):
    return type(value) in (int, float) and abs(value) <= 1_000_000 and math.isfinite(value)


def vector(value):
    return isinstance(value, list) and len(value) == 3 and all(number(n) for n in value)


def keys(obj, allowed, required):
    require(isinstance(obj, dict) and not set(obj) - allowed and required <= set(obj), 'unsupported_report_schema')


def approved_failure(value):
    if not isinstance(value, str): return False
    if value in FAILURES: return True
    prefix, suffix = 'backendUnavailable("backend controls failed: ', '")'
    if not value.startswith(prefix) or not value.endswith(suffix): return False
    names = value[len(prefix):-len(suffix)].split(',')
    return bool(names) and names == [name for name in CONTROL_NAMES if name in names]


def fields(obj, room, uuids):
    for key, item in obj.items():
        if key in FALSE_FIELDS:
            require(item is False, 'physical_authority_or_coverage_claim')
        elif key in BOOL_FIELDS:
            require(type(item) is bool, 'invalid_boolean')
        elif key in VECTORS:
            require(vector(item), 'invalid_vector')
        elif key in NUMBERS:
            require(number(item) and (key == 'angleDegrees' or item >= 0), 'invalid_number')
        elif key in IDS:
            require(isinstance(item, list) and len(item) <= 512 and all(isinstance(v, str) and v in uuids[room] for v in item), 'unknown_fixture_identifier')
        elif key in ('error','nativeError'):
            require(approved_failure(item), 'unapproved_error_text')
        elif key == 'nativeStatus':
            require(type(item) is int and 0 <= item < 2**32, 'invalid_native_status')


CHAIN_ROW_FIELDS = {'scoredChainContinuous','scoredChainIncludesRequestedGoal','sourceFloorSupportAlongScoredChain'}
CHAIN_SEGMENT_FIELDS = {'floorContactIDs','fullFootprintSupportVerified','sourceFloorSupport'}


def validate_scored_chain(row, journey):
    """Validate recorded edges, never repair/invent a route or infer floor support."""
    points, segments = row['routePoints'], row['segments']
    start, ps, pg, goal = (row[k] for k in ('requestedStart','projectedStart','projectedGoal','requestedGoal'))
    expected = [('requested-start-to-projection', start, ps)]
    if points[0] != ps:
        expected.append(('projection-to-detour-start', ps, points[0]))
    expected.extend(('detour-segment-' + str(i), points[i-1], points[i]) for i in range(1,len(points)))
    if row['nativeComplete']:
        if points[-1] != pg:
            expected.append(('detour-end-to-projection', points[-1], pg))
        expected.append(('projection-to-requested-goal', pg, goal))
    require(len(segments) == len(expected) and all(
        (segment['kind'],segment['from'],segment['to']) == edge
        for segment, edge in zip(segments, expected)), 'scored_chain_mismatch')
    # Both contact aggregates are literal initial+segment observations. A clear
    # label cannot silently discard a connector's contact; this is not a physics
    # calculation and says nothing about the unobserved surrounding world.
    for aggregate, initial in (('bodyContact','initialBodyContact'),('marginContact','initialMarginContact')):
        require(row[aggregate] == (row[initial] or any(segment[aggregate] for segment in segments)), 'contact_aggregate_mismatch')
    present = CHAIN_ROW_FIELDS & set(row)
    require(not present or (not journey and present == CHAIN_ROW_FIELDS), 'incomplete_chain_metadata')
    if present:
        require(row['scoredChainContinuous'] is True and row['scoredChainIncludesRequestedGoal'] is row['nativeComplete'], 'chain_metadata_disagreement')
        require(row['sourceFloorSupportAlongScoredChain'] == 'unverified-full-footprint', 'unsupported_floor_support_claim')
    for segment in segments:
        added = CHAIN_SEGMENT_FIELDS & set(segment)
        require(added == (CHAIN_SEGMENT_FIELDS if present else set()), 'incomplete_segment_support_metadata')
        if added:
            require(segment['fullFootprintSupportVerified'] is False and
                    segment['sourceFloorSupport'] == 'unverified-full-footprint', 'unsupported_floor_support_claim')
            # Producer reports margin-floor IDs per segment and includes those
            # same IDs in its aggregate; presence is NOT positive floor support.
            require(set(segment['floorContactIDs']) <= set(row['floorContactIDs']), 'floor_contact_aggregate_mismatch')


def validate_report(report, label, docs, uuids):
    journey = label == 'journey'
    common = {'schema','protocolSHA256','physicalAuthority','fullFootprintSupportVerified','outcomes','errors'}
    extra = ({'baseline18Unchanged','suppliedPoseCandidateReplayOnly','cameraLocalizationTested','getUpKinematicsTested',
              'productionGuidanceCode','sustainedControllerTested','VoiceOverTested'} if journey else
             {'profileAddendumSHA256','schedule','currentCoverageKnown','scope'})
    keys(report, common | extra, common | extra)
    require(type(report['schema']) is int and report['schema'] == 1, 'unsupported_report_schema')
    require(report['protocolSHA256'] == (JOURNEY if journey else BASE), 'protocol_hash_mismatch')
    fields(report, 'Hallway2', uuids)
    base = docs['RoomRouteDiagnostic/PROTOCOL.json']
    plan = docs['RoomRouteDiagnostic/JOURNEY_ADDENDUM.json']
    if journey:
        require(report['baseline18Unchanged'] is True and report['suppliedPoseCandidateReplayOnly'] is True, 'missing_replay_limitation')
        require(report['productionGuidanceCode'] == ['SpatialFacts.relation','SpatialFacts.phrase','GuidanceCadence.label'], 'unapproved_guidance_source')
        schedules = {(j['id'], s['id']): (j['room'], j, s) for j in plan['journeys'] for s in j['stages']}
        outcomes = {'not-run-after-aborted-stage','not-run-after-journey-stop','unsupported-geometry','invalid-standing-start-contact',
                    'expected-withheld-outbound','native-query-failure','expected-withheld-partial','partial-route','candidate-contact',
                    'unexpected-outbound-completion','modeled-segment-candidate-no-contact'}
    else:
        require(report['schedule'] == label and report['profileAddendumSHA256'] == (WIDTH if label == 'width28-addendum' else 'none'), 'protocol_hash_mismatch')
        require(report['scope'] == 'candidate waypoint replay; not controller/device arrival', 'missing_replay_limitation')
        profiles = (docs['RoomRouteDiagnostic/PROFILE_28CM_ADDENDUM.json']['profiles'] if label == 'width28-addendum' else base['profiles'])
        schedules = {(p['id'], profile['id']): (p['room'], p, profile) for p in base['pairs'] for profile in profiles}
        outcomes = {'not-run-after-aborted-stage','unsupported-geometry','collision-backend-unavailable','invalid-start-contact',
                    'native-query-failure','partial-route','candidate-contact','candidate-model-route-no-contact'}
    errors = {'Stage aborted; unexecuted schedules are not arrivals' if journey else
              'Stage threw before terminal reporting; unexecuted schedules are not passes'}
    errors.update(room + ': ' + failure for room in FIXTURES for failure in FAILURES)
    errors.update(room + ' collision backend unavailable: ' + failure for room in FIXTURES for failure in FAILURES)
    if journey:
        errors.update(j + '/' + s + ' crossed withheld original support/state' for j, s in schedules)
    def approved_error(value):
        if not isinstance(value, str): return False
        if value in errors: return True
        return any(value.startswith(prefix) and approved_failure(value[len(prefix):])
                   for room in FIXTURES for prefix in (room + ': ', room + ' collision backend unavailable: '))
    require(isinstance(report['errors'], list) and len(report['errors']) <= 32 and
            all(approved_error(e) for e in report['errors']), 'unapproved_error_text')
    rows = report['outcomes']
    require(isinstance(rows, list) and len(rows) == len(schedules), 'schedule_denominator_mismatch')
    seen = set()
    row_common = {'outcome','sourceSHA256','requestedStart','requestedGoal','initialBodyContact','initialMarginContact',
                  'physicalAuthority','nativeError','nativeComplete','nativeStatus','routePoints','projectedStart','projectedGoal',
                  'startProjectionMetres','goalProjectionMetres','segments','bodyContact','marginContact','floorContactIDs',
                  'obstacleSurfaceIDs','furnitureBoundIDs','fullFootprintSupportVerified','error'}
    row_extra = ({'journey','stage','seatedFeatureID','seatedObservationIsAuthored','originalSuppliedStandingPoint','declaredHeading',
                  'cameraLocalizationTested','getUpKinematicsTested','expectedWithhold','historicalDoorOpen','currentDoorStateKnown',
                  'closedDoorStraightProbeContactIDs','guidanceDelivered','productionGuidanceReceipts','replayPositionAfterStage'} if journey else
                 {'pair','profile','rawRadius','rawHeight','effectiveRadius','effectiveHeight','initialFurnitureBoundIDs','waypointSinkDelivered'} | CHAIN_ROW_FIELDS)
    for row in rows:
        identity = ('journey','stage') if journey else ('pair','profile')
        keys(row, row_common | row_extra, set(identity) | {'outcome'})
        require(all(isinstance(row[k], str) for k in identity), 'unknown_schedule')
        pair = tuple(row[k] for k in identity)
        require(pair in schedules and pair not in seen, 'unknown_or_duplicate_schedule')
        seen.add(pair)
        room, authored, stage = schedules[pair]
        require(isinstance(row['outcome'], str) and row['outcome'] in outcomes, 'unknown_outcome')
        fields(row, room, uuids)
        if row['outcome'].startswith('not-run-') or row['outcome'] in {'unsupported-geometry','collision-backend-unavailable'}:
            require(set(row) <= set(identity) | {'outcome','error'}, 'unexpected_unexecuted_payload')
            continue
        require(row.get('sourceSHA256') == FIXTURES[room] and row.get('physicalAuthority') is False, 'source_hash_or_authority_mismatch')
        active = {'sourceSHA256','physicalAuthority','requestedStart','requestedGoal','initialBodyContact','initialMarginContact'}
        active |= ({'seatedFeatureID','seatedObservationIsAuthored','originalSuppliedStandingPoint','declaredHeading',
                    'cameraLocalizationTested','getUpKinematicsTested','expectedWithhold','replayPositionAfterStage','guidanceDelivered'} if journey else
                   {'rawRadius','rawHeight','effectiveRadius','effectiveHeight','initialFurnitureBoundIDs','fullFootprintSupportVerified','waypointSinkDelivered'})
        require(active <= set(row), 'missing_active_outcome_fields')
        failure = 'nativeError' in row
        require(failure != ('nativeComplete' in row), 'missing_or_ambiguous_native_result')
        delivered_key = 'guidanceDelivered' if journey else 'waypointSinkDelivered'
        if failure:
            require(row[delivered_key] is False, 'failed_query_delivered_guidance')
            require(not set(row) & ({'routePoints','segments','projectedStart','projectedGoal','productionGuidanceReceipts'} | CHAIN_ROW_FIELDS), 'failed_query_has_route')
        else:
            required_route = {'nativeComplete','nativeStatus','routePoints','projectedStart','projectedGoal',
                              'startProjectionMetres','goalProjectionMetres','segments','bodyContact','marginContact',
                              'floorContactIDs','obstacleSurfaceIDs','furnitureBoundIDs','fullFootprintSupportVerified'}
            if journey: required_route.add('productionGuidanceReceipts')
            require(required_route <= set(row), 'missing_candidate_route_fields')
        invalid_start = row['initialBodyContact'] or row['initialMarginContact']
        if invalid_start:
            expected_outcome = 'invalid-standing-start-contact' if journey else 'invalid-start-contact'
        elif failure:
            expected_outcome = 'expected-withheld-outbound' if journey and stage['expectedWithhold'] else 'native-query-failure'
        elif not row['nativeComplete']:
            expected_outcome = 'expected-withheld-partial' if journey and stage['expectedWithhold'] else 'partial-route'
        elif row['bodyContact'] or row['marginContact']:
            expected_outcome = 'candidate-contact'
        elif journey and stage['expectedWithhold']:
            expected_outcome = 'unexpected-outbound-completion'
        else:
            expected_outcome = 'modeled-segment-candidate-no-contact' if journey else 'candidate-model-route-no-contact'
        require(row['outcome'] == expected_outcome, 'outcome_fields_disagree')
        if journey:
            require(row.get('seatedFeatureID') == authored.get('seatedFeatureID','none') and row.get('seatedObservationIsAuthored') is True,
                    'unapproved_seated_observation')
            require(row.get('expectedWithhold') is stage['expectedWithhold'], 'schedule_withholding_mismatch')
        if 'routePoints' in row:
            require(isinstance(row['routePoints'], list) and 0 < len(row['routePoints']) <= 4096 and all(vector(v) for v in row['routePoints']), 'invalid_route_points')
        segments = row.get('segments', [])
        require(isinstance(segments, list) and (failure or len(segments) > 0) and len(segments) <= 4100, 'invalid_segments')
        for segment in segments:
            keys(segment, {'kind','from','to','bodyContact','marginContact'} | (set() if journey else CHAIN_SEGMENT_FIELDS), {'kind','from','to','bodyContact','marginContact'})
            require(isinstance(segment['kind'], str) and re.fullmatch(SEGMENT_PATTERN, segment['kind']), 'unknown_segment')
            fields(segment, room, uuids)
        if not failure:
            validate_scored_chain(row, journey)
        receipts = row.get('productionGuidanceReceipts', [])
        require(isinstance(receipts, list) and len(receipts) <= 4100, 'invalid_guidance_receipts')
        if journey:
            require(row['guidanceDelivered'] == bool(receipts), 'guidance_delivery_disagreement')
        for receipt in receipts:
            expected = {'segmentIndex','segmentKind','from','to','sector','angleDegrees','horizontalMetres','text','source','syntheticSeconds','physicalAuthority'}
            keys(receipt, expected, expected)
            fields(receipt, room, uuids)
            i = receipt['segmentIndex']
            require(type(i) is int and 0 <= i < len(segments), 'invalid_guidance_segment')
            segment = segments[i]
            require(receipt['segmentKind'] == segment['kind'] and receipt['from'] == segment['from'] and receipt['to'] == segment['to'], 'guidance_segment_mismatch')
            require(isinstance(receipt['sector'], str) and receipt['sector'] in DIRECTIONS, 'invalid_guidance_sector')
            require(receipt['source'] == 'production SpatialFacts + GuidanceCadence; supplied heading', 'unapproved_guidance_source')
            # Exact authored target prefix and fixed English formatter grammar;
            # model/free-form text, paths, user history and speech are not accepted.
            prefix = 'TEST ' + row['stage'] + ' ' + segment['kind'] + ': ' + DIRECTIONS[receipt['sector']] + ', '
            require(isinstance(receipt['text'], str) and re.fullmatch(re.escape(prefix) + r'[0-9]{1,7}(?:\.[0-9])? metres\.', receipt['text']), 'unapproved_guidance_text')
    return report


def bounded_integer(value, maximum):
    return type(value) is int and 0 <= value <= maximum


def inventory_name(value, digest):
    require(isinstance(value, str) and (value == '<redacted>' or
            re.fullmatch(r'[A-Za-z0-9_. -]{1,128}', value)), 'unapproved_inventory_text')
    require(isinstance(digest, str) and re.fullmatch(r'[0-9a-f]{64}', digest), 'invalid_inventory_hash')
    if value != '<redacted>':
        require(hashlib.sha256(value.encode()).hexdigest() == digest, 'inventory_name_hash_mismatch')


def validate_metadata_inventory(report, uuids):
    """No raw metadata values/paths; only fixed fixture IDs, enums and bounded names."""
    top = {'schema', 'physicalAuthority', 'fixtures'}
    keys(report, top, top)
    require(report['schema'] == 'blind.saved-room-route-mesh-metadata-inventory.v1' and
            report['physicalAuthority'] is False, 'unsupported_report_schema')
    fixtures = report['fixtures']
    require(isinstance(fixtures, list) and len(fixtures) == 2, 'inventory_fixture_count_mismatch')
    seen = set()
    kinds = {'object', 'array', 'string', 'number', 'boolean', 'null'}
    required = {'fixtureID','sourceSHA256','metadataByteCount','metadataFormat','metadataRootKind','metadataEntryCount',
                'metadataEntriesTruncated','metadataEntries','nodeCount','nodesTruncated','nodes',
                'meshCount','unmatchedMeshCount','unknownFeatureMeshCount'}
    for fixture in fixtures:
        keys(fixture, required | {'adapterFailure','inventoryFailure'}, required)
        room = fixture['fixtureID']
        require(isinstance(room, str) and room in FIXTURES and room not in seen, 'unknown_or_duplicate_fixture')
        seen.add(room)
        require(fixture['sourceSHA256'] == FIXTURES[room], 'source_hash_mismatch')
        require(bounded_integer(fixture['metadataByteCount'], LIMIT), 'inventory_metadata_over_budget')
        require(isinstance(fixture['metadataRootKind'], str) and
                fixture['metadataRootKind'] in kinds | {'unread','invalidJSON'}, 'unsupported_metadata_kind')
        require(isinstance(fixture['metadataFormat'], str) and fixture['metadataFormat'] in
                {'unread','json','binaryPlist','xmlPlist','unknown'}, 'unsupported_metadata_format')
        require((fixture['metadataFormat'] == 'json') == (fixture['metadataRootKind'] in kinds) and
                (fixture['metadataFormat'] == 'unread') == (fixture['metadataRootKind'] == 'unread'), 'metadata_format_disagreement')
        for field in ('adapterFailure','inventoryFailure'):
            if field in fixture:
                require(isinstance(fixture[field], str) and fixture[field] in METADATA_FAILURES, 'unapproved_error_text')
        for count, rows, truncated, cap in (('metadataEntryCount','metadataEntries','metadataEntriesTruncated',64),
                                             ('nodeCount','nodes','nodesTruncated',128)):
            require(bounded_integer(fixture[count], 4096), 'inventory_count_over_budget')
            require(isinstance(fixture[rows], list) and len(fixture[rows]) == min(fixture[count], cap) and
                    type(fixture[truncated]) is bool and fixture[truncated] == (fixture[count] > cap),
                    'inventory_count_mismatch')
        for field in ('meshCount','unmatchedMeshCount','unknownFeatureMeshCount'):
            require(bounded_integer(fixture[field], fixture['nodeCount']), 'inventory_mesh_count_mismatch')
        require(fixture['unmatchedMeshCount'] + fixture['unknownFeatureMeshCount'] <= fixture['meshCount'],
                'inventory_mesh_count_mismatch')
        entry_keys = {'key','keySHA256','valueKind','uuidValue','knownFeature'}
        entry_hashes = set()
        for entry in fixture['metadataEntries']:
            keys(entry, entry_keys | {'uuid'}, entry_keys)
            inventory_name(entry['key'], entry['keySHA256'])
            require(entry['keySHA256'] not in entry_hashes, 'duplicate_inventory_key')
            entry_hashes.add(entry['keySHA256'])
            require(isinstance(entry['valueKind'], str) and entry['valueKind'] in kinds and
                    type(entry['uuidValue']) is bool and type(entry['knownFeature']) is bool,
                    'unsupported_metadata_entry')
            require(entry['knownFeature'] == ('uuid' in entry) and
                    (not entry['uuidValue'] or entry['valueKind'] == 'string'), 'metadata_uuid_disagreement')
            if 'uuid' in entry:
                require(entry['uuidValue'] is True and isinstance(entry['uuid'], str) and
                        entry['uuid'] in uuids[room], 'unknown_fixture_identifier')
        node_keys = {'index','depth','name','nameSHA256','isMesh','directMappingPresent','inheritedMappingPresent','knownFeature'}
        nodes = fixture['nodes']
        for i, node in enumerate(nodes):
            keys(node, node_keys | {'parentIndex','directUUID','inheritedUUID','resolvedUUID','vertexCount','submeshCount'}, node_keys)
            require(type(node['index']) is int and node['index'] == i and bounded_integer(node['depth'],64), 'invalid_inventory_node')
            inventory_name(node['name'], node['nameSHA256'])
            for field in ('isMesh','directMappingPresent','inheritedMappingPresent','knownFeature'):
                require(type(node[field]) is bool, 'invalid_boolean')
            require(('vertexCount' in node) == node['isMesh'] and ('submeshCount' in node) == node['isMesh'], 'invalid_inventory_mesh')
            if node['isMesh']:
                require(bounded_integer(node['vertexCount'],200000) and bounded_integer(node['submeshCount'],4096), 'invalid_inventory_mesh')
            if 'parentIndex' in node:
                parent = node['parentIndex']
                require(bounded_integer(parent, i - 1) and node['depth'] == nodes[parent]['depth'] + 1, 'invalid_inventory_parent')
                ancestor = nodes[parent]
                require(node['inheritedMappingPresent'] == (ancestor['directMappingPresent'] or ancestor['inheritedMappingPresent']) and
                        node.get('inheritedUUID') == ancestor.get('resolvedUUID'), 'metadata_inheritance_disagreement')
            else:
                require(node['depth'] == 0 and node['inheritedMappingPresent'] is False and 'inheritedUUID' not in node, 'invalid_inventory_parent')
            for field in ('directUUID','inheritedUUID','resolvedUUID'):
                if field in node:
                    require(isinstance(node[field], str) and node[field] in uuids[room], 'unknown_fixture_identifier')
            require(node['knownFeature'] == ('resolvedUUID' in node) and
                    ('directUUID' not in node or node['directMappingPresent']) and
                    ('inheritedUUID' not in node or node['inheritedMappingPresent']), 'metadata_uuid_disagreement')
            # Direct unknown mappings override a known inherited mapping; never
            # silently relabel an unknown mesh as a recognized parent feature.
            resolved = node.get('directUUID') if node['directMappingPresent'] else node.get('inheritedUUID')
            require(node.get('resolvedUUID') == resolved, 'metadata_uuid_disagreement')
        sampled_meshes = [node for node in nodes if node['isMesh']]
        sampled_counts = {'meshCount':len(sampled_meshes),
                          'unmatchedMeshCount':sum(not node['directMappingPresent'] and not node['inheritedMappingPresent'] for node in sampled_meshes),
                          'unknownFeatureMeshCount':sum(not node['knownFeature'] and (node['directMappingPresent'] or node['inheritedMappingPresent']) for node in sampled_meshes)}
        for field, count in sampled_counts.items():
            require(count <= fixture[field] and (fixture['nodesTruncated'] or count == fixture[field]), 'inventory_mesh_count_mismatch')
    return report


def collision_control_passed(query):
    """Literal mirror of fixed synthetic predicates, not an independent physics test."""
    initial, swept, terminal = (query[phase] for phase in ('initial','swept','terminal'))
    obstacle, floor, bound = ('obstacleSurfaceIDs','floorSurfaceIDs','furnitureBoundIDs')
    union = {key: set(initial[key] + swept[key] + terminal[key]) for key in (obstacle,floor,bound)}
    empty = lambda contacts: not any(contacts.values())
    wall, solid, overhead, ground = ('00000000-0000-0000-0000-00000000000' + str(i) for i in range(1,5))
    name = query['name']
    no_floor_or_bound = not union[floor] and not union[bound]
    if name in ('thinWallForward','thinWallReverse','overheadTallForward','overheadTallReverse'):
        expected = wall if name.startswith('thinWall') else overhead
        return empty(initial) and empty(terminal) and swept[obstacle] == [expected] and no_floor_or_bound
    if name == 'wallInitialOverlap':
        return initial[obstacle] == [wall] and empty(terminal) and union[obstacle] == {wall} and no_floor_or_bound
    if name == 'wallTerminalOverlap':
        return terminal[obstacle] == [wall] and empty(initial) and union[obstacle] == {wall} and no_floor_or_bound
    if name == 'containedSolid':
        return initial[bound] == [solid] and terminal[bound] == [solid] and union[bound] == {solid} and not union[obstacle] and not union[floor]
    if name in ('overheadShort','clear'):
        return empty(union)
    return initial[floor] == [ground] and terminal[floor] == [ground] and union[floor] == {ground} and not union[obstacle] and not union[bound]


def validate_collision_matrix(report):
    top = {'schemaVersion','evidenceKind','physicalAuthority','fullFootprintSupportVerified','cells'}
    keys(report, top, top)
    require(type(report['schemaVersion']) is int and report['schemaVersion'] == 1 and
            report['evidenceKind'] == 'synthetic-collision-backend-matrix' and
            report['physicalAuthority'] is False and report['fullFootprintSupportVerified'] is False, 'unsupported_report_schema')
    cells = report['cells']
    configurations = ('restricted-no-renderer','default-no-renderer','restricted-offscreen-renderer','default-offscreen-renderer')
    require(isinstance(cells, list) and len(cells) == 4, 'collision_matrix_count_mismatch')
    cell_keys = {'configurationID','sourceCollisionMask','rendererMode','physicsSpeed','timeStepSeconds','gravity',
                 'sourceCategoryMask','probeCategoryMask','queryCollisionMask','backendReady','failedControls','queries'}
    query_keys = {'name','passed','errorCode','initial','swept','terminal'}
    ids = ['00000000-0000-0000-0000-00000000000' + str(i) for i in range(1,5)]
    contact_ids = {'obstacleSurfaceIDs':set(ids[:3]),'furnitureBoundIDs':{ids[1]},'floorSurfaceIDs':{ids[3]}}
    for cell, configuration in zip(cells, configurations):
        keys(cell, cell_keys, cell_keys)
        require(cell['configurationID'] == configuration and
                cell['sourceCollisionMask'] == ('probe-only' if configuration.startswith('restricted') else 'platform-default-all') and
                cell['rendererMode'] == ('none' if configuration.endswith('no-renderer') else 'retained-offscreen-update'), 'collision_configuration_mismatch')
        for key, value in (('physicsSpeed',1),('sourceCategoryMask',1),('probeCategoryMask',2),('queryCollisionMask',1)):
            require(type(cell[key]) is int and cell[key] == value, 'collision_configuration_mismatch')
        require(number(cell['timeStepSeconds']) and cell['timeStepSeconds'] == 1 / 60 and
                vector(cell['gravity']) and cell['gravity'] == [0,0,0], 'collision_configuration_mismatch')
        queries = cell['queries']
        require(isinstance(queries, list) and len(queries) == len(CONTROL_NAMES), 'collision_query_count_mismatch')
        failed = []
        for query, name in zip(queries, CONTROL_NAMES):
            keys(query, query_keys, query_keys)
            require(query['name'] == name and type(query['passed']) is bool, 'collision_control_mismatch')
            require(isinstance(query['errorCode'], str) and query['errorCode'] in
                    {'none','invalidGeometry','invalidQuery','invalidFurnitureBox','unassociatedContact','unexpectedError'}, 'unapproved_error_text')
            for phase in ('initial','swept','terminal'):
                contacts = query[phase]
                keys(contacts, set(contact_ids), set(contact_ids))
                for category, allowed in contact_ids.items():
                    values = contacts[category]
                    require(isinstance(values, list) and len(values) <= len(allowed) and
                            all(isinstance(value, str) and value in allowed for value in values) and
                            values == sorted(set(values)), 'unknown_synthetic_identifier')
            if query['errorCode'] != 'none':
                require(query['passed'] is False and not any(query[phase][category]
                        for phase in ('initial','swept','terminal') for category in contact_ids), 'collision_error_disagreement')
            else:
                require(query['passed'] == collision_control_passed(query), 'collision_pass_disagreement')
            if not query['passed']: failed.append(name)
        require(type(cell['backendReady']) is bool and cell['backendReady'] == (not failed) and
                cell['failedControls'] == failed, 'collision_readiness_disagreement')
    return report


def collect(repo, bundle, cases, query):
    result = {'schema':1, 'status':'not_observed', 'physicalAuthority':False,
              'scope':'public Apple historical fixtures and synthetic controls; no physical authority',
              'aggregateByteLimit':LIMIT, 'reports':[]}
    wanted = {}
    observed = {canonical(case['identifier']) for case in cases}
    specs = SPECS + tuple(spec for spec in DIAGNOSTIC_SPECS if spec[0] in observed)
    for key, name, label in specs:
        found = [c for c in cases if canonical(c['identifier']) == key]
        record = {'attachmentName':name, 'testIdentifier':key, 'status':'test_not_observed'}
        result['reports'].append(record)
        if len(found) == 1:
            wanted[key] = found[0]
            record.update(testIdentifier=found[0]['identifier'], testResult=found[0]['result'], status='pending')
        elif found:
            record['status'] = 'duplicate_test_case'
    if not wanted:
        if any(r['status'] == 'duplicate_test_case' for r in result['reports']): result['status'] = 'error'
        return result
    try:
        docs, uuids, hashes = sources(repo)
        result['sourceSHA256'] = hashes
        total = 0
        for (key, name, label), record in zip(specs, result['reports']):
            if key not in wanted: continue
            try:
                # No suite/all-test export and no --only-failures: passing and
                # failed keepAlways reports both matter. No test is rerun.
                with tempfile.TemporaryDirectory(prefix='blind-route-evidence-') as tmp:
                    directory = Path(tmp) / 'attachments'
                    export_test(bundle, wanted[key]['identifier'], directory)
                    raw = exported_report(directory, name)
                require(total + len(raw) <= LIMIT, 'aggregate_over_budget')
                total += len(raw)
                if label in ('metadata-inventory','collision-backend'):
                    require(len(raw) <= DIAGNOSTIC_LIMIT, 'diagnostic_over_budget')
                    report = (validate_metadata_inventory(decode(raw), uuids) if label == 'metadata-inventory'
                              else validate_collision_matrix(decode(raw)))
                else:
                    report = validate_report(decode(raw), label, docs, uuids)
                record.update(status='collected', bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest(), report=report)
            except (ValueError, OSError, KeyError, TypeError, RecursionError, subprocess.SubprocessError) as error:
                record['status'] = str(error) if isinstance(error, EvidenceError) else 'attachment_export_or_schema_error'
        result['rawAttachmentBytes'] = total
        result['status'] = 'complete' if all(r['status'] == 'collected' for r in result['reports']) else 'incomplete'
    except (ValueError, OSError, KeyError, TypeError, RecursionError) as error:
        result['status'] = str(error) if isinstance(error, EvidenceError) else 'source_validation_error'
        for record in result['reports']:
            if record['status'] == 'pending': record['status'] = 'not_collected'
    return result

