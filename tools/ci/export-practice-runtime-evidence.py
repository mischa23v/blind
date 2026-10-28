#!/usr/bin/env python3
"""Read one nonce-bound synthetic Practice receipt; never infer a UI test pass."""
import json
import math
import os
import selectors
import signal
import time
from pathlib import Path
import re
import subprocess
import sys

TEST = 'LaunchTests/testPracticeIsAnnouncedAndCanStop'
UUID = r'[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'
MARKER = re.compile(r'^PRACTICE_RUNTIME_RUN test=' + re.escape(TEST) + r' run=(' + UUID + r')$')
PHASES = {'startEntered', 'cameraStopped', 'feedbackStopped', 'calibrationGenerated', 'watchdogStarted',
          'speechHandedOff', 'expiryArmed', 'startReturned', 'expiryFired', 'endEntered',
          'endCameraStopped', 'endFeedbackStopped', 'endReturned'}
SOURCES = {'model', 'places', 'indoor', 'outdoor', 'mapping', 'journeys', 'voice', 'survey',
           'visualStairs', 'peopleTracking', 'detection', 'calibrationProgress'}
HAZARDS = {'stopped', 'calibrating', 'needsCalibration', 'observing', 'uncertain', 'drop', 'obstacle', 'overhead'}
KEYS = {'schema', 'scope', 'testID', 'runID', 'events', 'ticks', 'totalTickMS', 'maxTickMS',
        'maxTickGapMS', 'lastTickMS', 'hazard', 'hazardTransitions', 'publications', 'snapshots', 'truncated'}


def nonce_from_log(path):
    found = []
    total = 0
    with path.open('rb') as stream:
        for line in iter(lambda: stream.readline(1024 * 1024 + 1), b''):
            total += len(line)
            if total > 20 * 1024 * 1024 or len(line) > 1024 * 1024:
                raise ValueError('UI log exceeds diagnostic bounds')
            text = line.decode('utf-8', errors='replace').strip()
            match = MARKER.fullmatch(text)
            if match:
                found.append(match[1])
                if len(found) > 1:
                    raise ValueError('Duplicate Practice diagnostic run marker')
    if len(found) != 1:
        raise ValueError('Missing exact Practice diagnostic run marker')
    return found[0]


def integer(value, maximum):
    return type(value) is int and 0 <= value <= maximum


def milliseconds(value):
    return type(value) in (int, float) and 0 <= value <= 3_600_000 and math.isfinite(value)


def validate(data, nonce):
    if type(data) is not dict or set(data) != KEYS:
        raise ValueError('Unknown Practice diagnostic schema')
    if type(data['schema']) is not int or data['schema'] != 1 or data['scope'] != 'synthetic-practice-runtime':
        raise ValueError('Invalid Practice diagnostic scope')
    if data['testID'] != TEST or data['runID'] != nonce:
        raise ValueError('Practice diagnostic owner mismatch')
    if not integer(data['ticks'], 1_000_000) or not integer(data['hazardTransitions'], 1_000_000):
        raise ValueError('Invalid Practice counters')
    if not integer(data['snapshots'], 32) or data['snapshots'] == 0 or type(data['truncated']) is not bool:
        raise ValueError('Invalid Practice snapshot bounds')
    if any(not milliseconds(data[key]) for key in ('totalTickMS', 'maxTickMS', 'maxTickGapMS', 'lastTickMS')):
        raise ValueError('Invalid Practice timing')
    if data['maxTickMS'] > data['totalTickMS'] or type(data['hazard']) is not str or data['hazard'] not in HAZARDS:
        raise ValueError('Invalid Practice timing or hazard consistency')
    events = data['events']
    if type(events) is not list or not 1 <= len(events) <= 16:
        raise ValueError('Invalid Practice event bounds')
    previous = 0
    seen = set()
    for event in events:
        if type(event) is not dict or set(event) != {'phase', 'elapsedMS'} or type(event['phase']) is not str or event['phase'] not in PHASES:
            raise ValueError('Unknown Practice phase')
        if event['phase'] in seen or not milliseconds(event['elapsedMS']) or event['elapsedMS'] < previous:
            raise ValueError('Invalid Practice phase chronology')
        seen.add(event['phase']); previous = event['elapsedMS']
    if events[0]['phase'] != 'startEntered':
        raise ValueError('Missing Practice start boundary')
    publications = data['publications']
    if type(publications) is not dict or set(publications) - SOURCES or any(not integer(v, 1_000_000) for v in publications.values()):
        raise ValueError('Invalid Practice publication counters')
    return data


def read_receipt(container, nonce):
    if not re.fullmatch(UUID, nonce):
        raise ValueError('Invalid Practice run identity')
    container = container.resolve(strict=True)
    path = container / 'Library' / 'Caches' / 'BlindPracticeRuntime' / (nonce + '.json')
    # Never follow an injected symlink to another app/user file.
    for parent in [path, *list(path.parents)[:4]]:
        if parent.is_symlink():
            raise ValueError('Practice diagnostic symlink rejected')
    if path.resolve(strict=True).parent != (container / 'Library/Caches/BlindPracticeRuntime').resolve(strict=True):
        raise ValueError('Practice diagnostic path escaped')
    if path.stat().st_size > 16 * 1024:
        raise ValueError('Practice diagnostic exceeds 16 KiB')
    return validate(json.loads(path.read_text()), nonce)


def bounded_query(command, seconds=20, cap=4096):
    # Adapted from the repository's bounded xcresult query helper. Only this
    # invocation's process group is retired, including children holding pipes.
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    buffers = {process.stdout: bytearray(), process.stderr: bytearray()}
    deadline = time.monotonic() + seconds
    try:
        with selectors.DefaultSelector() as selector:
            for stream in buffers: selector.register(stream, selectors.EVENT_READ)
            while selector.get_map():
                if time.monotonic() >= deadline: raise ValueError('Simulator query timed out')
                for key, _ in selector.select(max(0, min(0.1, deadline - time.monotonic()))):
                    data = os.read(key.fd, cap + 1)
                    if data:
                        buffers[key.fileobj].extend(data)
                        if sum(map(len, buffers.values())) > cap: raise ValueError('Simulator query exceeded bounds')
                    else: selector.unregister(key.fileobj)
            if process.wait(timeout=max(0.01, deadline - time.monotonic())):
                raise ValueError('Selected simulator app container unavailable')
            return bytes(buffers[process.stdout])
    finally:
        try: os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError: pass
        process.wait()
        for stream in buffers: stream.close()


def simulator_container(simulator_file):
    simulator = simulator_file.read_text().strip().upper()
    if not re.fullmatch(UUID, simulator):
        raise ValueError('Invalid selected simulator identity')
    output = bounded_query(['xcrun', 'simctl', 'get_app_container', simulator, 'org.blindassist.mobility', 'data'])
    value = output.decode('utf-8').strip()
    if not value or '\n' in value or not Path(value).is_absolute():
        raise ValueError('Invalid simulator app container response')
    return Path(value)


def main():
    simulator_file, log, destination = map(Path, sys.argv[1:])
    destination.mkdir(parents=True, exist_ok=False)
    result = {'schema': 1, 'scope': 'synthetic-practice-runtime', 'testID': TEST,
              'uiOutcome': 'not_inferred_from_diagnostic', 'status': 'unavailable',
              'snapshotTiming': 'last_completed_async_write_not_atomic_with_test'}
    try:
        nonce = nonce_from_log(log)
        result['trace'] = read_receipt(simulator_container(simulator_file), nonce)
        result['status'] = 'trace_retained'
        result['endObserved'] = any(e['phase'] == 'endReturned' for e in result['trace']['events'])
    except (OSError, ValueError, RecursionError, subprocess.TimeoutExpired) as error:
        # No local absolute paths, user content, environment, or arbitrary stdout.
        result['error'] = str(error)[:180] if type(error) is ValueError else type(error).__name__
    (destination / 'practice-runtime-evidence.json').write_text(json.dumps(result, indent=2) + '\n')
    print('PRACTICE_RUNTIME_EVIDENCE=' + json.dumps(result, separators=(',', ':')))
    return 0 if result['status'] == 'trace_retained' else 1


if __name__ == '__main__':
    sys.exit(main())
