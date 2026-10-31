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
import base64
import binascii
import hashlib
import json
import math
import os
import resource
import signal
import stat
import struct
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
     'SavedRoomCollisionBackendMatrix-v1.json', 'collision-backend'),
    ('SavedRoomRouteCollisionOracleTests/testMixedSceneCombinedAndSeparatedQueriesRecordEveryPhase',
     'SavedRoomCollisionMixedScene-v1.json', 'collision-mixed-scene'),
    ('SavedRoomRouteMeshAppleFixtureTests/testPublicRawExportAndExactDegenerateReceiptsRemainAuditable',
     'APPLE_ROOM_PACKED_ROUTING_GEOMETRY.json', 'packed-routing'))
CONTACT_PHASE_SPEC = ('SavedRoomRouteDiagnosticAppleTests/testAdditiveSourceProvedStartsAndUnchangedHallContactPhases',
                      'APPLE_VALID_START_CONTACT_PHASES.json', 'valid-start-contact-phases')
DIAGNOSTIC_LIMIT = 131072
CONTROL_NAMES = ('thinWallForward', 'thinWallReverse', 'wallInitialOverlap', 'wallTerminalOverlap',
                 'containedSolid', 'overheadTallForward', 'overheadTallReverse', 'overheadShort', 'clear', 'floor')
MIXED_CONTROL_NAMES = ('thinWallForward', 'thinWallReverse', 'wallInitialOverlap', 'wallTerminalOverlap', 'clear', 'floor')
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
    return stripped if stripped in {s[0] for s in SPECS + DIAGNOSTIC_SPECS + (CONTACT_PHASE_SPEC,)} else None


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
                     'metadataEmpty','metadataInvalidEntries','meshNodeMissingMetadata','metadataUnknownFeature','unclassifiedError','floorTessellationFailed','floorTessellationIndexOutOfRange',
                     'floorTessellationWindingMismatch','floorTessellationDegenerateTriangle'}
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


def validate_metadata_inventory(report, uuids, docs=None):
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
        keys(fixture, required | {'adapterFailure','inventoryFailure','geometryProbe','geometryProbeFailure','meshParity','floorTessellation','rawExportTriangleCount','routingTriangleCount','ignoredDegenerateFaces'}, required)
        room = fixture['fixtureID']
        require(isinstance(room, str) and room in FIXTURES and room not in seen, 'unknown_or_duplicate_fixture')
        seen.add(room)
        require(fixture['sourceSHA256'] == FIXTURES[room], 'source_hash_mismatch')
        require(bounded_integer(fixture['metadataByteCount'], LIMIT), 'inventory_metadata_over_budget')
        require(isinstance(fixture['metadataRootKind'], str) and
                fixture['metadataRootKind'] in kinds | {'unread','invalidJSON','invalidPropertyList'}, 'unsupported_metadata_kind')
        require(isinstance(fixture['metadataFormat'], str) and fixture['metadataFormat'] in
                {'unread','json','binaryPlist','xmlPlist','unknown'}, 'unsupported_metadata_format')
        # The attachment remains JSON; this field describes the source export.
        # Keep pre-repair binary-plist/invalidJSON witnesses as historical errors.
        roots_by_format = {'unread':{'unread'}, 'json':kinds,
                           'binaryPlist':kinds | {'invalidJSON','invalidPropertyList'},
                           'xmlPlist':{'invalidJSON'}, 'unknown':{'invalidJSON'}}
        require(fixture['metadataRootKind'] in roots_by_format[fixture['metadataFormat']], 'metadata_format_disagreement')
        for field in ('adapterFailure','inventoryFailure','geometryProbeFailure'):
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
        if 'geometryProbeFailure' in fixture:
            require(fixture.get('adapterFailure') == 'sourceGeometryMismatch' and
                    'geometryProbe' not in fixture, 'geometry_probe_context_mismatch')
        if 'geometryProbe' in fixture:
            validate_geometry_probe(fixture, docs)
        if 'meshParity' in fixture:
            validate_mesh_parity(fixture)
        validate_floor_inventory(fixture, uuids, docs)
    return report



def validate_floor_inventory(fixture, uuids, docs):
    """Public-fixture diagnostics only; never a support or collision verdict."""
    extra = {'floorTessellation','rawExportTriangleCount','routingTriangleCount','ignoredDegenerateFaces'}
    if not extra & set(fixture):
        return  # Historical v1 receipts remain valid without new diagnostics.
    require({'floorTessellation','ignoredDegenerateFaces'} <= set(fixture), 'incomplete_floor_inventory')
    require(isinstance(docs, dict), 'floor_inventory_source_unavailable')
    room = docs.get('RoomPlanApple/' + fixture['fixtureID'] + '.capturedRoom.json')
    require(isinstance(room, dict), 'floor_inventory_source_unavailable')
    counts = {'rawExportTriangleCount','routingTriangleCount'} & set(fixture)
    require(not counts or len(counts) == 2, 'incomplete_floor_counts')
    for name in counts:
        require(bounded_integer(fixture[name],100000), 'floor_triangle_count_over_budget')
    captures = fixture['floorTessellation']
    require(isinstance(captures,list) and len(captures) <= len(room['floors']) <= 64, 'floor_capture_count')
    polygons = [[[float32(x) for x in p] for p in f['polygonCorners']] for f in room['floors']]
    seen = set()
    def geometry(g):
        keys(g, {'sourceCount','elementCount','sources','elements'}, {'sourceCount','elementCount','sources','elements'})
        for count, rows in [('sourceCount','sources'),('elementCount','elements')]:
            require(bounded_integer(g[count],4096) and isinstance(g[rows],list) and len(g[rows]) == min(g[count],8), 'floor_geometry_count')
            for row in g[rows]:
                names = ({'vectorCount','componentsPerVector','bytesPerComponent','dataOffset','dataStride','dataByteCount','usesFloatComponents'} if rows == 'sources' else
                         {'primitiveType','primitiveCount','bytesPerIndex','dataByteCount'})
                keys(row,names|{'dataBase64'},names)
                for name in names - {'usesFloatComponents'}:
                    require(bounded_integer(row[name],32*1024*1024), 'floor_buffer_integer')
                if rows == 'sources':
                    require(type(row['usesFloatComponents']) is bool and row['vectorCount'] <= 200000 and row['componentsPerVector'] <= 16 and row['bytesPerComponent'] <= 8, 'floor_source_format')
                else:
                    require(row['primitiveType'] <= 4 and row['primitiveCount'] <= 100000 and row['bytesPerIndex'] <= 8, 'floor_element_format')
                require(('dataBase64' in row) == (row['dataByteCount'] <= 4096), 'floor_buffer_capture_mismatch')
                if 'dataBase64' in row:
                    value = row['dataBase64']
                    require(isinstance(value,str) and len(value) <= 5464, 'floor_buffer_over_budget')
                    try: raw = base64.b64decode(value,validate=True)
                    except (ValueError, binascii.Error): require(False, 'invalid_floor_buffer_base64')
                    require(len(raw) == row['dataByteCount'] and base64.b64encode(raw).decode() == value, 'floor_buffer_capture_mismatch')
    for capture in captures:
        fields = {'schema','physicalAuthority','sourcePolygon','direct','afterModelIOConversion','roundTrip','modelIOVertexCount','modelIOSubmeshCount'}
        keys(capture,fields|{'adapterFailure'},fields)
        require(capture['schema'] == 'blind.public-or-synthetic-floor-tessellation-probe.v1' and capture['physicalAuthority'] is False, 'unsupported_floor_probe_schema')
        polygon = capture['sourcePolygon']
        require(isinstance(polygon,list) and 3 <= len(polygon) <= 1024 and all(vector(p) for p in polygon), 'floor_polygon_invalid')
        match = next((i for i,p in enumerate(polygons) if p == polygon),None)
        require(match is not None and match not in seen, 'floor_polygon_source_mismatch'); seen.add(match)
        for name in ('modelIOVertexCount','modelIOSubmeshCount'):
            require(bounded_integer(capture[name],200000), 'floor_probe_count')
        if 'adapterFailure' in capture:
            require(capture['adapterFailure'] in METADATA_FAILURES, 'unapproved_error_text')
        for name in ('direct','afterModelIOConversion','roundTrip'): geometry(capture[name])
    faces = fixture['ignoredDegenerateFaces']
    require(isinstance(faces,list) and len(faces) <= 4096 and (not faces or len(counts) == 2), 'degenerate_receipt_count')
    seen_faces=set()
    for face in faces:
        fields={'rawTriangleIndex','featureID','indices','localVertices','worldVertices'}; keys(face,fields,fields)
        index=face['rawTriangleIndex']
        require(bounded_integer(index,fixture['rawExportTriangleCount']-1) and index not in seen_faces, 'degenerate_receipt_index');seen_faces.add(index)
        require(isinstance(face['featureID'],str) and face['featureID'] in uuids[fixture['fixtureID']], 'unknown_fixture_identifier')
        require(isinstance(face['indices'],list) and len(face['indices']) == 3 and all(bounded_integer(i,199999) for i in face['indices']), 'degenerate_receipt_indices')
        for name in ('localVertices','worldVertices'):
            points=face[name]
            require(isinstance(points,list) and len(points)==3 and all(vector(p) for p in points), 'degenerate_receipt_vertices')
            require(len({tuple(p) for p in points}) < 3, 'degenerate_receipt_not_exact_duplicate')
        pairs=((0,1),(1,2),(0,2))
        require([face['localVertices'][a] == face['localVertices'][b] for a,b in pairs] ==
                [face['worldVertices'][a] == face['worldVertices'][b] for a,b in pairs], 'degenerate_duplicate_pair_mismatch')


def validate_packed_routing(report, uuids, docs):
    fields={'schema','representation','coordinateEncoding','frame','complete','physicalAuthority','fullFootprintSupportVerified','fixtures'}
    keys(report,fields,fields)
    require(report['schema']=='blind.public-apple-packed-routing-geometry.v1' and report['representation']=='final-adapter-routing-input' and
            report['coordinateEncoding']=='float32-bit-patterns' and report['frame']=='original-saved-world-y-up-metres' and
            report['complete'] is True and report['physicalAuthority'] is False and report['fullFootprintSupportVerified'] is False, 'packed_routing_schema')
    require(isinstance(docs,dict), 'packed_source_unavailable')
    fixtures=report['fixtures'];require(isinstance(fixtures,list) and len(fixtures)==2,'packed_fixture_count');seen=set()
    for f in fixtures:
        fields={'fixtureID','sourceSHA256','worldPositionBits','triangleIndices','floorSupport','triangleFeatureIDs','furnitureBoxes'}
        keys(f,fields,fields);room=f['fixtureID']
        require(isinstance(room,str) and room in FIXTURES and room not in seen and f['sourceSHA256']==FIXTURES[room],'packed_fixture_identity');seen.add(room)
        words=f['worldPositionBits'];require(isinstance(words,list) and 3<=len(words)<=6144 and len(words)%3==0 and all(type(w)is int and 0<=w<=0xffffffff for w in words),'packed_position_words')
        values=[struct.unpack('<f',struct.pack('<I',w))[0] for w in words]
        require(all(math.isfinite(v) and abs(v)<=10000 for v in values),'packed_position_number')
        indices=f['triangleIndices'];require(isinstance(indices,list) and 3<=len(indices)<=3072 and len(indices)%3==0 and all(type(i)is int and 0<=i<len(words)//3 for i in indices),'packed_triangle_indices')
        count=len(indices)//3
        require(isinstance(f['floorSupport'],list) and len(f['floorSupport'])==count and all(type(v)is bool for v in f['floorSupport']),'packed_support_alignment')
        require(isinstance(f['triangleFeatureIDs'],list) and len(f['triangleFeatureIDs'])==count and all(isinstance(v,str) and v in uuids[room] for v in f['triangleFeatureIDs']),'packed_feature_alignment')
        source=docs['RoomPlanApple/'+room+'.capturedRoom.json'];floor_ids={x['identifier'] for x in source['floors']}
        require(all(s==(i in floor_ids) for s,i in zip(f['floorSupport'],f['triangleFeatureIDs'])),'packed_support_identity')
        boxes=f['furnitureBoxes'];require(isinstance(boxes,list) and len(boxes)<=64,'packed_box_count');objects={x['identifier']:x for x in source['objects']};box_seen=set()
        for box in boxes:
            keys(box,{'featureID','dimensions','transform'},{'featureID','dimensions','transform'});i=box['featureID']
            require(isinstance(i,str) and i in objects and i not in box_seen,'packed_box_identity');box_seen.add(i)
            dims=box['dimensions'];matrix=box['transform']
            require(isinstance(dims,list) and len(dims)==3 and all(number(v) and 0<v<=100 for v in dims),'packed_box_dimensions')
            require(isinstance(matrix,list) and len(matrix)==16 and all(number(v) and abs(v)<=10000 for v in matrix),'packed_box_transform')
            require(dims==[float32(v) for v in objects[i]['dimensions']] and matrix==[float32(v) for v in objects[i]['transform']],'packed_box_source_mismatch')
        require(box_seen==set(objects),'packed_box_inventory_incomplete')
    return report


def validate_mesh_parity(fixture):
    """Bounded raw same-export numeric capture; validation is not geometry parity.

    Float32 words avoid decimal conversion loss. Internal matrix/point coherence
    is checked, while source-frame agreement and face/winding equality belong to
    the independent reader comparison, not an assumed successful capture.
    """
    capture = fixture['meshParity']
    fields = {'schema','representation','coordinateEncoding','winding','complete','meshes'}
    keys(capture, fields, fields)
    require(capture['schema'] == 'blind.public-apple-native-mesh-parity.v1' and
            capture['representation'] == 'raw-diagnostic-export' and
            capture['coordinateEncoding'] == 'float32-bit-patterns-column-major' and
            capture['winding'] == 'ordered-native-triangle-indices' and capture['complete'] is True,
            'unsupported_mesh_parity_schema')
    require(fixture['nodesTruncated'] is False and fixture['unmatchedMeshCount'] == 0 and
            fixture['unknownFeatureMeshCount'] == 0 and 'inventoryFailure' not in fixture,
            'mesh_parity_incomplete_context')
    rows = capture['meshes']
    nodes = {node['index']:node for node in fixture['nodes'] if node['isMesh']}
    require(isinstance(rows, list) and 0 < len(rows) == len(nodes) <= 64, 'mesh_parity_count_mismatch')
    def values(words, count):
        require(isinstance(words, list) and len(words) == count and all(
                type(word) is int and 0 <= word <= 0xffffffff for word in words), 'invalid_mesh_parity_words')
        decoded = [struct.unpack('<f', struct.pack('<I', word))[0] for word in words]
        require(all(math.isfinite(value) and abs(value) <= 10000 for value in decoded), 'invalid_mesh_parity_number')
        return decoded
    seen = set(); vertex_count = triangle_count = 0
    row_fields = {'nodeIndex','featureID','localTransformBits','worldTransformBits',
                  'localPositionBits','worldPositionBits','triangleIndices'}
    for row in rows:
        keys(row, row_fields, row_fields)
        i = row['nodeIndex']
        require(type(i) is int and i in nodes and i not in seen, 'mesh_parity_node_mismatch')
        seen.add(i); node = nodes[i]
        require(node['knownFeature'] is True and row['featureID'] == node.get('resolvedUUID'), 'mesh_parity_feature_mismatch')
        count = node['vertexCount']; vertex_count += count
        require(0 < count and vertex_count <= 1024, 'mesh_parity_vertex_budget')
        local = values(row['localPositionBits'], count * 3)
        world = values(row['worldPositionBits'], count * 3)
        local_t = values(row['localTransformBits'], 16)
        world_t = values(row['worldTransformBits'], 16)
        for matrix in (local_t, world_t):
            require(all(abs(matrix[k]) <= 64 * 2**-23 for k in (3,7,11)) and
                    abs(matrix[15] - 1) <= 64 * 2**-23, 'invalid_mesh_parity_affine')
        indices = row['triangleIndices']
        require(isinstance(indices, list) and 0 < len(indices) <= 3072 and len(indices) % 3 == 0 and
                all(type(index) is int and 0 <= index < count for index in indices), 'invalid_mesh_parity_indices')
        triangle_count += len(indices) // 3
        require(triangle_count <= 1024, 'mesh_parity_triangle_budget')
        for offset in range(0, len(local), 3):
            p = local[offset:offset+3]
            expected = [sum(world_t[c*4+r]*p[c] for c in range(3))+world_t[12+r] for r in range(3)]
            actual = world[offset:offset+3]
            # SIMD may fuse Float32 operations. This is the existing arithmetic
            # scale allowance, not sensor accuracy or an extrusion tolerance.
            scale = max([1] + [abs(value) for value in p + world_t + expected + actual])
            require(all(abs(a-b) <= 64 * 2**-23 * scale for a,b in zip(actual, expected)),
                    'mesh_parity_world_local_mismatch')
    require(seen == set(nodes), 'mesh_parity_count_mismatch')
    return capture


def float32(value):
    """Exact representation conversion, not an acceptance tolerance or repair."""
    return struct.unpack('<f', struct.pack('<f', value))[0]


def validate_geometry_probe(fixture, docs):
    """Only one failed mesh from the already SHA-verified public fixture export."""
    require(fixture.get('adapterFailure') == 'sourceGeometryMismatch' and
            'geometryProbeFailure' not in fixture, 'geometry_probe_context_mismatch')
    require(isinstance(docs, dict), 'geometry_source_unavailable')
    probe = fixture['geometryProbe']
    vectors = {'meshLocalPoint','worldPoint','sourceLocalPoint','sourceDimensions','sourceLocalMinimum','sourceLocalMaximum',
               'sourceWorldMinimum','sourceWorldMaximum','exportedWorldMinimum','exportedWorldMaximum',
               'exportedSourceLocalMinimum','exportedSourceLocalMaximum','assetUpAxis'}
    matrices = {'sourceTransform','meshLocalTransform','meshGlobalTransform','parentGlobalTransform','rootGlobalTransform'}
    required = {'sourceEncoding','nodeIndex','featureID','featureKind','vertexIndex','vertexCount','axis','side',
                'lower','upper','epsilon','residual'} | vectors | matrices
    keys(probe, required, required)
    require(probe['sourceEncoding'] == 'capturedRoomFloat32', 'unsupported_geometry_source_encoding')
    for field in vectors | matrices:
        value = probe[field]
        require(isinstance(value, list) and len(value) == (3 if field in vectors else 16) and
                all(number(item) and abs(item) <= 10000 for item in value), 'invalid_geometry_probe_number')
    for field, maximum in (('lower',10000),('upper',10000),('epsilon',1),('residual',20000)):
        require(number(probe[field]) and abs(probe[field]) <= maximum, 'invalid_geometry_probe_number')
    require(bounded_integer(probe['nodeIndex'],127) and probe['nodeIndex'] < len(fixture['nodes']), 'invalid_geometry_probe_node')
    node = fixture['nodes'][probe['nodeIndex']]
    require(node['isMesh'] is True and node['knownFeature'] is True and
            probe['featureID'] == node.get('resolvedUUID'), 'geometry_probe_feature_mismatch')
    require(bounded_integer(probe['vertexCount'],200000) and probe['vertexCount'] > 0 and
            probe['vertexCount'] == node['vertexCount'] and
            bounded_integer(probe['vertexIndex'],probe['vertexCount'] - 1), 'invalid_geometry_probe_vertex')
    room = docs.get('RoomPlanApple/' + fixture['fixtureID'] + '.capturedRoom.json')
    require(isinstance(room, dict), 'geometry_source_unavailable')
    sources = [(kind, feature) for key, kind in (('floors','floor'),('walls','wall'),('doors','door'),
               ('windows','window'),('openings','opening'),('objects','furniture')) for feature in room[key]
               if feature['identifier'] == probe['featureID']]
    require(len(sources) == 1 and probe['featureKind'] == sources[0][0], 'geometry_probe_feature_mismatch')
    kind, feature = sources[0]
    dimensions = [float32(value) for value in feature['dimensions']]
    transform = [float32(value) for value in feature['transform']]
    corners = [] if kind == 'furniture' else [[float32(value) for value in point] for point in feature.get('polygonCorners', [])]
    minimum = [min(point[axis] for point in corners) if corners else -dimensions[axis] / 2 for axis in range(3)]
    maximum = [max(point[axis] for point in corners) if corners else dimensions[axis] / 2 for axis in range(3)]
    require(probe['sourceDimensions'] == dimensions and probe['sourceTransform'] == transform and
            all(0 <= value <= 100 for value in dimensions) and probe['sourceLocalMinimum'] == minimum and
            probe['sourceLocalMaximum'] == maximum, 'geometry_probe_source_mismatch')
    points = corners or [[maximum[axis] if mask & (1 << axis) else minimum[axis] for axis in range(3)] for mask in range(8)]
    original_world = [[transform[axis] * point[0] + transform[4+axis] * point[1] +
                       transform[8+axis] * point[2] + transform[12+axis] for axis in range(3)] for point in points]
    require(probe['sourceWorldMinimum'] == [min(point[axis] for point in original_world) for axis in range(3)] and
            probe['sourceWorldMaximum'] == [max(point[axis] for point in original_world) for axis in range(3)], 'geometry_probe_source_mismatch')
    # Match NativeCameraTransform.inverted().applying(to:) over its source
    # Float32 values copied into Double. Do not rederive the SIMD Float mesh
    # multiplication: its native contraction/rounding is separate evidence.
    world = probe['worldPoint']
    source_local = []
    for axis in range(3):
        offset = axis * 4
        inverse_translation = -(transform[offset] * transform[12] + transform[offset+1] * transform[13] + transform[offset+2] * transform[14])
        source_local.append(transform[offset] * world[0] + transform[offset+1] * world[1] + transform[offset+2] * world[2] + inverse_translation)
    require(probe['sourceLocalPoint'] == source_local, 'geometry_probe_world_local_mismatch')
    for prefix in ('sourceWorld','exportedWorld','exportedSourceLocal'):
        require(all(lo <= hi for lo, hi in zip(probe[prefix+'Minimum'],probe[prefix+'Maximum'])), 'invalid_geometry_probe_bounds')
    for point, prefix in (('worldPoint','exportedWorld'),('sourceLocalPoint','exportedSourceLocal')):
        require(all(lo <= value <= hi for lo, value, hi in
                    zip(probe[prefix+'Minimum'],probe[point],probe[prefix+'Maximum'])), 'geometry_probe_point_outside_bounds')
    axis = probe['axis']
    require(bounded_integer(axis,2) and probe['side'] in ('belowMinimum','aboveMaximum'), 'invalid_geometry_probe_predicate')
    require(probe['lower'] == minimum[axis] and probe['upper'] == maximum[axis], 'geometry_probe_source_mismatch')
    scale = max([1] + [abs(value) for value in probe['worldPoint'] + transform + dimensions])
    epsilon = 64 * 2**-23 * scale
    local = probe['sourceLocalPoint']
    residual = minimum[axis] - local[axis] if probe['side'] == 'belowMinimum' else local[axis] - maximum[axis]
    violates = local[axis] < minimum[axis] - epsilon if probe['side'] == 'belowMinimum' else local[axis] > maximum[axis] + epsilon
    require(probe['epsilon'] == epsilon and probe['residual'] == residual and residual > epsilon and
            violates and
            all(minimum[i] - epsilon <= local[i] <= maximum[i] + epsilon for i in range(axis)),
            'geometry_probe_predicate_disagreement')
    return probe


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


def mixed_collision_control_passed(query, layout):
    """Mirror paired synthetic observations; a floor contact is not support proof."""
    initial, swept, terminal = (query[phase] for phase in ('initial','swept','terminal'))
    obstacle, floor, bound = ('obstacleSurfaceIDs','floorSurfaceIDs','furnitureBoundIDs')
    union = {key:set(initial[key] + swept[key] + terminal[key]) for key in (obstacle,floor,bound)}
    wall, ground = ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002')
    if union[bound] or (layout == 'wall-only' and union[floor]): return False
    name = query['name']
    if name in ('thinWallForward','thinWallReverse'):
        return not initial[obstacle] and not terminal[obstacle] and swept[obstacle] == [wall]
    if name == 'wallInitialOverlap':
        return initial[obstacle] == [wall] and not terminal[obstacle] and union[obstacle] == {wall}
    if name == 'wallTerminalOverlap':
        return terminal[obstacle] == [wall] and not initial[obstacle] and union[obstacle] == {wall}
    if name == 'clear': return not union[obstacle]
    return (not union[obstacle] and (not union[floor] if layout == 'wall-only' else
            initial[floor] == [ground] and terminal[floor] == [ground] and union[floor] == {ground}))


def validate_mixed_collision_matrix(report):
    """Separate versioned witness; never reinterpret the original 4x10 matrix."""
    top = {'schemaVersion','evidenceKind','physicalAuthority','fullFootprintSupportVerified','cells'}
    keys(report, top, top)
    require(type(report['schemaVersion']) is int and report['schemaVersion'] == 1 and
            report['evidenceKind'] == 'synthetic-collision-mixed-scene' and
            report['physicalAuthority'] is False and report['fullFootprintSupportVerified'] is False, 'unsupported_report_schema')
    cells = report['cells']
    configurations = ('wall-only-combined','wall-and-floor-combined','wall-only-separated','wall-and-floor-separated')
    require(isinstance(cells, list) and len(cells) == 4, 'collision_matrix_count_mismatch')
    cell_keys = {'configurationID','layout','queryMode','rendererMode','physicsSpeed','timeStepSeconds','gravity',
                 'obstacleCategoryMask','floorCategoryMask','probeCategoryMask','queryCollisionMasks',
                 'backendReady','failedControls','queries'}
    query_keys = {'name','passed','errorCode','initial','swept','terminal'}
    allowed_ids = {'obstacleSurfaceIDs':{'10000000-0000-0000-0000-000000000001'},
                   'floorSurfaceIDs':{'10000000-0000-0000-0000-000000000002'},'furnitureBoundIDs':set()}
    for cell, configuration in zip(cells, configurations):
        keys(cell, cell_keys, cell_keys)
        mode = 'separated' if configuration.endswith('separated') else 'combined'
        layout = 'wall-and-floor' if configuration.startswith('wall-and-floor') else 'wall-only'
        require(cell['configurationID'] == configuration and cell['layout'] == layout and cell['queryMode'] == mode and
                cell['rendererMode'] == 'retained-offscreen-update', 'collision_configuration_mismatch')
        for key, value in (('physicsSpeed',1),('obstacleCategoryMask',1),('floorCategoryMask',4 if mode == 'separated' else 1),('probeCategoryMask',2)):
            require(type(cell[key]) is int and cell[key] == value, 'collision_configuration_mismatch')
        masks = cell['queryCollisionMasks']
        require(isinstance(masks, list) and all(type(mask) is int for mask in masks) and
                masks == ([1,4] if mode == 'separated' else [1]) and
                number(cell['timeStepSeconds']) and cell['timeStepSeconds'] == 1 / 60 and
                vector(cell['gravity']) and cell['gravity'] == [0,0,0], 'collision_configuration_mismatch')
        queries = cell['queries']
        require(isinstance(queries, list) and len(queries) == len(MIXED_CONTROL_NAMES), 'collision_query_count_mismatch')
        failed = []
        for query, name in zip(queries, MIXED_CONTROL_NAMES):
            keys(query, query_keys, query_keys)
            require(query['name'] == name and type(query['passed']) is bool, 'collision_control_mismatch')
            require(isinstance(query['errorCode'], str) and query['errorCode'] in
                    {'none','invalidGeometry','invalidQuery','invalidFurnitureBox','unassociatedContact','unexpectedError'}, 'unapproved_error_text')
            for phase in ('initial','swept','terminal'):
                contacts = query[phase]
                keys(contacts, set(allowed_ids), set(allowed_ids))
                for category, allowed in allowed_ids.items():
                    values = contacts[category]
                    require(isinstance(values, list) and len(values) <= len(allowed) and
                            all(isinstance(value, str) and value in allowed for value in values) and
                            values == sorted(set(values)), 'unknown_synthetic_identifier')
            if query['errorCode'] != 'none':
                require(query['passed'] is False and not any(query[phase][category]
                        for phase in ('initial','swept','terminal') for category in allowed_ids), 'collision_error_disagreement')
            else:
                require(query['passed'] == mixed_collision_control_passed(query, layout), 'collision_pass_disagreement')
            if not query['passed']: failed.append(name)
        require(type(cell['backendReady']) is bool and cell['backendReady'] == (not failed) and
                cell['failedControls'] == failed, 'collision_readiness_disagreement')
    return report


CONTACT_PHASE_INPUT = 'RoomRouteDiagnostic/VALID_START_PHASE_ADDENDUM.json'
CONTACT_PHASE_SHA256 = 'a8d4cc19bf25292b52d7d3282229d52177c920c39795badda413f82377475663'
CONTACT_PHASE_SPEC = ('SavedRoomRouteDiagnosticAppleTests/testAdditiveSourceProvedStartsAndUnchangedHallContactPhases',
                      'APPLE_VALID_START_CONTACT_PHASES.json', 'valid-start-contact-phases')
CONTACT_HALL_IDS = {'0D0716C9-28D9-4F00-BE7C-E2A6FAFA36FA', '0CD2F73E-5F0B-444C-BE63-2F9855C59D47'}


def contact_phase_source(repo, docs, hashes):
    # Optional exact public fixture only. Older result bundles never need this file.
    name = 'ios/BlindAssistTests/Fixtures/' + CONTACT_PHASE_INPUT
    path = repo / name
    require(not path.is_symlink() and path.is_file() and 0 < path.stat().st_size <= 16384, 'invalid_contact_phase_source')
    raw = path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == CONTACT_PHASE_SHA256, 'contact_phase_source_hash_mismatch')
    docs[CONTACT_PHASE_INPUT] = decode(raw)
    hashes[name] = CONTACT_PHASE_SHA256


def contact_phase_point(local, floor):
    # Same declared Float32 RoomPlan feature transform and final Float32 point.
    matrix = [float32(value) for value in floor['transform']]
    return [float32(((matrix[r] * local[0] + matrix[4+r] * local[1]) +
                     matrix[8+r] * local[2]) + matrix[12+r]) for r in range(3)]


def contact_phase_same_number(actual, expected):
    # JSON NSNumber Float formatting may shorten the exact Float32 decimal.
    # Two Float32 ULP-scale serialization tolerance, never a geometry clearance.
    return number(actual) and abs(actual - expected) <= max(1e-8, abs(expected) * 2**-22)


def contact_phase_feature_sets(room, docs):
    source = docs['RoomPlanApple/' + room + '.capturedRoom.json']
    return {'floorIDs': {x['identifier'] for x in source['floors']},
            'boundIDs': {x['identifier'] for x in source['objects']},
            'obstacleIDs': {x['identifier'] for kind in ('walls','doors','windows','openings','objects') for x in source[kind]}}


def validate_contact_phase(phase, room, docs):
    allowed = contact_phase_feature_sets(room, docs)
    names = set(allowed) | {'hasObstacleContact', 'details'}
    keys(phase, names, names)
    for field, identities in allowed.items():
        values = phase[field]
        require(isinstance(values, list) and len(values) <= len(identities) and
                all(isinstance(v, str) and v in identities for v in values) and
                values == sorted(set(values)), 'contact_phase_feature_identity')
    require(type(phase['hasObstacleContact']) is bool and
            phase['hasObstacleContact'] == bool(phase['obstacleIDs'] or phase['boundIDs']), 'contact_phase_contact_disagreement')
    details = phase['details']
    require(isinstance(details, list) and len(details) <= 128, 'contact_phase_detail_budget')
    kinds = {'obstacle-surface':'obstacleIDs', 'floor-surface':'floorIDs', 'furniture-bound':'boundIDs'}
    observed = {field:set() for field in allowed}
    for detail in details:
        fields = {'featureID','kind','point','normal','penetrationDistance'}
        keys(detail, fields, fields)
        kind = detail['kind']
        require(isinstance(kind, str) and kind in kinds and isinstance(detail['featureID'], str) and
                detail['featureID'] in phase[kinds[kind]], 'contact_phase_detail_identity')
        require(vector(detail['point']) and vector(detail['normal']) and
                all(abs(n) <= 10000 for n in detail['point']) and all(abs(n) <= 2 for n in detail['normal']) and
                number(detail['penetrationDistance']) and abs(detail['penetrationDistance']) <= 100,
                'contact_phase_detail_number')
        observed[kinds[kind]].add(detail['featureID'])
    require(all(observed[k] == set(phase[k]) for k in allowed), 'contact_phase_detail_inventory')


def validate_contact_phases(phases, room, docs, radius, height):
    fields = {'initial','swept','terminal','fullFootprintSupportVerified','physicalAuthority','actualCylinder'}
    keys(phases, fields, fields)
    require(phases['fullFootprintSupportVerified'] is False and phases['physicalAuthority'] is False,
            'physical_authority_or_coverage_claim')
    shape = phases['actualCylinder']
    shape_fields = {'radius','height','radialSegmentCount','heightSegmentCount','collisionMargin'}
    keys(shape, shape_fields, shape_fields)
    require(contact_phase_same_number(shape['radius'], radius) and contact_phase_same_number(shape['height'], height) and
            number(shape['collisionMargin']) and shape['collisionMargin'] == 0 and
            number(shape['radialSegmentCount']) and shape['radialSegmentCount'] == int(shape['radialSegmentCount']) and 3 <= shape['radialSegmentCount'] <= 1024 and
            number(shape['heightSegmentCount']) and shape['heightSegmentCount'] == int(shape['heightSegmentCount']) and 1 <= shape['heightSegmentCount'] <= 1024,
            'contact_cylinder_mismatch')
    for name in ('initial','swept','terminal'):
        validate_contact_phase(phases[name], room, docs)
    return any(phases[name]['hasObstacleContact'] for name in ('initial','swept','terminal'))


def validate_contact_triangles(geometry, docs):
    require(isinstance(geometry, list) and len(geometry) <= 128, 'contact_triangle_budget')
    wall_ids = {x['identifier'] for x in docs['RoomPlanApple/Hallway2.capturedRoom.json']['walls']}
    require(CONTACT_HALL_IDS <= wall_ids, 'contact_triangle_source_identity')
    seen = set()
    for triangle in geometry:
        fields = {'triangleIndex','featureID','indices','worldPositionFloat32Bits'}
        keys(triangle, fields, fields)
        index = triangle['triangleIndex']
        require(bounded_integer(index, 1000000) and index not in seen and
                isinstance(triangle['featureID'], str) and triangle['featureID'] in CONTACT_HALL_IDS,
                'contact_triangle_identity')
        seen.add(index)
        require(isinstance(triangle['indices'], list) and len(triangle['indices']) == 3 and
                all(bounded_integer(v, 1000000) for v in triangle['indices']), 'contact_triangle_indices')
        words = triangle['worldPositionFloat32Bits']
        require(isinstance(words, list) and len(words) == 3 and all(isinstance(v, list) and len(v) == 3 for v in words),
                'contact_triangle_words')
        for vertex in words:
            require(all(bounded_integer(v, 0xffffffff) for v in vertex), 'contact_triangle_words')
            values = [struct.unpack('<f', struct.pack('<I', v))[0] for v in vertex]
            require(all(math.isfinite(v) and abs(v) <= 10000 for v in values), 'contact_triangle_number')
    require([v['triangleIndex'] for v in geometry] == sorted(seen), 'contact_triangle_order')


def validate_contact_phase_report(report, docs):
    top = {'schema','physicalAuthority','fullFootprintSupportVerified','originalSchedulesChanged','outcomes','hallTriangles'}
    keys(report, top, top)
    require(type(report['schema']) is int and report['schema'] == 1 and
            report['physicalAuthority'] is False and report['fullFootprintSupportVerified'] is False and
            report['originalSchedulesChanged'] is False, 'unsupported_contact_report_schema')
    require(CONTACT_PHASE_INPUT in docs, 'contact_phase_source_unavailable')
    plan = docs[CONTACT_PHASE_INPUT]
    require(plan['sourceFixtureSHA256'] == FIXTURES and plan['baseProtocolSHA256'] == BASE and
            plan['physicalAuthority'] is False and plan['nativeExecuted'] is False and
            plan['changesOriginalSchedules'] is False, 'contact_phase_source_mismatch')
    queries = plan['queries']; rows = report['outcomes']
    require(isinstance(rows, list) and len(rows) == 4 and len(queries) == 4, 'contact_phase_schedule_count')
    profiles = docs['RoomRouteDiagnostic/PROTOCOL.json']['profiles'] + docs['RoomRouteDiagnostic/PROFILE_28CM_ADDENDUM.json']['profiles']
    base = {'id','room','profile','physicalAuthority','fullFootprintSupportVerified','outcome'}
    meta = {'sourceSHA256','requestedStart','requestedGoal','rawRadius','rawHeight','effectiveRadius','effectiveHeight'}
    phases = ['startRaw','startMargin','goalRaw','goalMargin']
    native = {'nativeComplete','nativeStatus','routePoints','projectedStart','projectedGoal'}
    error_outcomes = {'diagnostic-budget-exceeded','contact-detail-budget-exceeded','query-or-oracle-error'}
    outcomes = error_outcomes | {'not-run-after-undrained-owner','stationary-endpoint-contact','native-query-failure','partial-route','candidate-contact','historical-model-no-contact'}
    undrained = False
    for row, query in zip(rows, queries):
        keys(row, base | meta | set(phases) | native | {'segments','detailsComplete','cleanupAcknowledged'}, base)
        require((row['id'],row['room'],row['profile']) == (query['id'],query['room'],query['profile']) and
                row['physicalAuthority'] is False and row['fullFootprintSupportVerified'] is False,
                'contact_phase_schedule_identity')
        outcome = row['outcome']
        require(isinstance(outcome, str) and outcome in outcomes, 'contact_phase_unknown_outcome')
        if undrained:
            require(outcome == 'not-run-after-undrained-owner' and set(row) == base, 'contact_phase_undrained_admission')
            continue
        require(outcome != 'not-run-after-undrained-owner', 'contact_phase_unjustified_abort')
        error = outcome in error_outcomes
        require((row.get('detailsComplete') is False) if error else ('detailsComplete' not in row), 'contact_phase_completeness_disagreement')
        if 'cleanupAcknowledged' in row:
            require(type(row['cleanupAcknowledged']) is bool, 'contact_phase_cleanup_boolean')
            undrained = not row['cleanupAcknowledged']
        room = query['room']; source = docs['RoomPlanApple/' + room + '.capturedRoom.json']
        profile = next((p for p in profiles if p['id'] == query['profile']), None)
        require(profile is not None, 'contact_phase_unknown_profile')
        radius = math.hypot(profile['width'], profile['depth']) / 2
        raw_radius, raw_height = float32(radius), float32(profile['height'])
        margin_radius, margin_height = float32(radius + profile['margin']), float32(profile['height'] + profile['margin'])
        metadata_present = set(row) & meta
        require(metadata_present in (set(), meta), 'contact_phase_partial_metadata')
        if metadata_present:
            require(row['sourceSHA256'] == FIXTURES[room], 'contact_phase_source_hash_mismatch')
            floor = source['floors'][0]
            for field, local in [('requestedStart',query['start']),('requestedGoal',query['goal'])]:
                expected = contact_phase_point(local, floor)
                require(vector(row[field]) and all(contact_phase_same_number(a,b) for a,b in zip(row[field],expected)), 'contact_phase_requested_point_mismatch')
            for field, expected in [('rawRadius',radius),('rawHeight',profile['height']),('effectiveRadius',margin_radius),('effectiveHeight',margin_height)]:
                require(contact_phase_same_number(row[field],expected), 'contact_phase_profile_mismatch')
        else:
            require(error and set(row) <= base | {'detailsComplete'}, 'contact_phase_missing_active_metadata')
            continue
        phase_present = [name for name in phases if name in row]
        require(phase_present == phases[:len(phase_present)], 'contact_phase_endpoint_order')
        endpoint_contact = False
        for name in phase_present:
            r,h = (raw_radius,raw_height) if name.endswith('Raw') else (margin_radius,margin_height)
            endpoint_contact |= validate_contact_phases(row[name],room,docs,r,h)
        if 'cleanupAcknowledged' in row:
            require(phase_present == phases and not endpoint_contact, 'contact_phase_cleanup_without_admission')
        if not error:
            require(phase_present == phases, 'contact_phase_endpoint_receipt_missing')
        if outcome == 'stationary-endpoint-contact':
            require(endpoint_contact and not set(row) & (native | {'segments','cleanupAcknowledged'}), 'contact_phase_stationary_disagreement')
            continue
        if not error:
            require(not endpoint_contact and 'cleanupAcknowledged' in row, 'contact_phase_native_admission_disagreement')
        native_present = set(row) & native
        require(native_present in (set(),native), 'contact_phase_partial_native_metadata')
        if not native_present:
            require('segments' not in row and (error or outcome == 'native-query-failure'), 'contact_phase_missing_route')
            continue
        require('cleanupAcknowledged' in row and phase_present == phases and not endpoint_contact, 'contact_phase_route_without_admission')
        require(type(row['nativeComplete']) is bool and bounded_integer(row['nativeStatus'],2**32-1) and
                isinstance(row['routePoints'],list) and len(row['routePoints']) <= 128 and all(vector(v) for v in row['routePoints']) and
                vector(row['projectedStart']) and vector(row['projectedGoal']), 'contact_phase_native_fields')
        points = row['routePoints']; segments = row.get('segments',[])
        require(isinstance(segments,list) and len(segments) <= 131, 'contact_phase_segment_budget')
        if not points:
            require(error and not segments, 'contact_phase_empty_route')
            continue
        expected = [('requested-start-to-projection',row['requestedStart'],row['projectedStart'])]
        if points[0] != row['projectedStart']: expected.append(('projection-to-detour-start',row['projectedStart'],points[0]))
        expected += [('detour-segment-'+str(i),points[i-1],points[i]) for i in range(1,len(points))]
        if row['nativeComplete']:
            if points[-1] != row['projectedGoal']: expected.append(('detour-end-to-projection',points[-1],row['projectedGoal']))
            expected.append(('projection-to-requested-goal',row['projectedGoal'],row['requestedGoal']))
        require(len(segments) <= len(expected) and (error or len(segments) == len(expected)), 'contact_phase_segment_chain')
        route_contact = False
        for index,(segment,edge) in enumerate(zip(segments,expected)):
            fields = {'kind','from','to','raw','margin','receiptState'}
            keys(segment,fields,fields-{'margin'})
            require((segment['kind'],segment['from'],segment['to']) == edge and vector(segment['from']) and vector(segment['to']), 'contact_phase_segment_chain')
            state = segment['receiptState']
            require(state in ('raw-recorded','complete') and (('margin' in segment) == (state == 'complete')), 'contact_phase_segment_state')
            require(state == 'complete' or (error and index == len(segments)-1), 'contact_phase_incomplete_segment_position')
            route_contact |= validate_contact_phases(segment['raw'],room,docs,raw_radius,raw_height)
            if 'margin' in segment: route_contact |= validate_contact_phases(segment['margin'],room,docs,margin_radius,margin_height)
        if not error:
            expected_outcome = 'partial-route' if not row['nativeComplete'] else 'candidate-contact' if route_contact else 'historical-model-no-contact'
            require(outcome == expected_outcome, 'contact_phase_outcome_disagreement')
    validate_contact_triangles(report['hallTriangles'],docs)
    return report


def collect(repo, bundle, cases, query):
    result = {'schema':1, 'status':'not_observed', 'physicalAuthority':False,
              'scope':'public Apple historical fixtures and synthetic controls; no physical authority',
              'aggregateByteLimit':LIMIT, 'reports':[]}
    wanted = {}
    observed = {canonical(case['identifier']) for case in cases}
    specs = SPECS + tuple(spec for spec in DIAGNOSTIC_SPECS + (CONTACT_PHASE_SPEC,) if spec[0] in observed)
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
                if label == 'valid-start-contact-phases':
                    contact_phase_source(repo, docs, hashes)
                    report = validate_contact_phase_report(decode(raw), docs)
                elif label in ('metadata-inventory','collision-backend','collision-mixed-scene','packed-routing'):
                    require(len(raw) <= DIAGNOSTIC_LIMIT, 'diagnostic_over_budget')
                    if label == 'metadata-inventory': report = validate_metadata_inventory(decode(raw), uuids, docs)
                    elif label == 'collision-backend': report = validate_collision_matrix(decode(raw))
                    elif label == 'packed-routing': report = validate_packed_routing(decode(raw), uuids, docs)
                    else: report = validate_mixed_collision_matrix(decode(raw))
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

