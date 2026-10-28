#!/usr/bin/env python3
"""Read ONLY three authored public Apple-fixture JSON reports into existing evidence.

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
    return stripped if stripped in {s[0] for s in SPECS} else None


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
            require(isinstance(item, str) and item in FAILURES, 'unapproved_error_text')
        elif key == 'nativeStatus':
            require(type(item) is int and 0 <= item < 2**32, 'invalid_native_status')


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
    require(isinstance(report['errors'], list) and len(report['errors']) <= 32 and
            all(isinstance(e, str) and e in errors for e in report['errors']), 'unapproved_error_text')
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
                 {'pair','profile','rawRadius','rawHeight','effectiveRadius','effectiveHeight','initialFurnitureBoundIDs','waypointSinkDelivered'})
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
            require(not set(row) & {'routePoints','segments','projectedStart','projectedGoal','productionGuidanceReceipts'}, 'failed_query_has_route')
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
            keys(segment, {'kind','from','to','bodyContact','marginContact'}, {'kind','from','to','bodyContact','marginContact'})
            require(isinstance(segment['kind'], str) and re.fullmatch(SEGMENT_PATTERN, segment['kind']), 'unknown_segment')
            fields(segment, room, uuids)
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


def collect(repo, bundle, cases, query):
    result = {'schema':1, 'status':'not_observed', 'physicalAuthority':False,
              'scope':'public Apple historical fixtures; supplied-pose candidate replay only',
              'aggregateByteLimit':LIMIT, 'reports':[]}
    wanted = {}
    for key, name, label in SPECS:
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
        for (key, name, label), record in zip(SPECS, result['reports']):
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
