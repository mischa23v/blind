#!/usr/bin/env python3
"""Closed-schema synthetic seated timing only; no test-outcome inference."""
import json
from pathlib import Path
import re
import stat
import sys

INPUT_LIMIT = 64 * 1024 * 1024
LINE_LIMIT = 4096
RECORD_LIMIT = 32  # Per prefix: one kind cannot evict the other kind.
SOURCE_RECORD_LIMIT = 64  # Matches the fixture's separately bounded source capture.
UUID = r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}'
NUMBER = r'(?:-1|[0-9]{1,15})'
STAGE = r'(?:requestEnqueued|workerStarted|nativeBuildBegin|nativeBuildEnd|routeBegin|routeEnd|nativeFailure|completionQueued|completionDelivered|discardRequested|discardWorkerStarted|discardReleased|discardCompletionDelivered|workerFinished|requestRetired|sourceSnapshotEnqueued|sourceSnapshotWorkerStarted|sourceSnapshotWorkerFinished|sourceSnapshotDeliveryStarted|sourceSnapshotDeliveryFinished)'
PHASE = re.compile(
    rf'SEATED_CANDIDATE_PHASE id=(?:{UUID}|none) '
    r'event=(?:happy_wait_finished|rejection_wait_finished|drain_complete) '
    rf'elapsed_ms={NUMBER} native_callback_ms={NUMBER} main_held_ms={NUMBER} '
    rf'stages=(?:{STAGE}:[0-9]{{1,15}}(?:;{STAGE}:[0-9]{{1,15}}){{0,63}})?'
)
# worker_begin_ms is owner-clock-relative, not request queue latency.
WORKER = re.compile(
    rf'SEATED_CANDIDATE_WORKER id={UUID} worker_begin_ms={NUMBER} '
    + ' '.join(rf'{name}_wall_ms=(?P<{name}_wall>{NUMBER}) '
               rf'{name}_cpu_us=(?P<{name}_cpu>{NUMBER}) '
               rf'{name}_pair_valid=(?P<{name}_valid>true|false)'
               for name in ('worker', 'build', 'route'))
    + r' records=(?:[0-9]|[1-5][0-9]|6[0-4])'
)
# SOURCE elapsed_ms is source-request-relative, not the PHASE submission clock
# or the native stages' owner-relative clock. Preserve the explicit request ordinal.
SOURCE = re.compile(
    rf'SEATED_CANDIDATE_SOURCE id=(?:{UUID}|none) '
    r'request=(?:[1-9]|[1-5][0-9]|6[0-4]) '
    r'event=(?:source_requested|source_native_callback|source_main_callback|source_controller_callback|render_enqueued|render_begin|render_end|display_accepted|display_rejected|source_refused) '
    rf'elapsed_ms={NUMBER} main_thread=(?:true|false) outcome=(?:none|success|unavailable|stale|runtime_invalidLimits|runtime_budget|runtime_unavailable|runtime_stale|runtime_invalidRetainedState)'
)
PREFIXES = {'phase': b'SEATED_CANDIDATE_PHASE ',
            'worker': b'SEATED_CANDIDATE_WORKER ',
            'source': b'SEATED_CANDIDATE_SOURCE '}


def valid(kind, line):
    match = {'phase': PHASE, 'worker': WORKER, 'source': SOURCE}[kind].fullmatch(line)
    if not match:
        return False
    if kind == 'worker':
        for name in ('worker', 'build', 'route'):
            wall, cpu = int(match[name + '_wall']), int(match[name + '_cpu'])
            paired = match[name + '_valid'] == 'true'
            # Unavailable CPU remains -1/false, not a fabricated zero or valid pair.
            if paired and (wall < 0 or cpu < 0) or not paired and cpu != -1:
                return False
    return True


def collect(stream, emit, input_limit=INPUT_LIMIT, line_limit=LINE_LIMIT,
            record_limit=RECORD_LIMIT, source_record_limit=SOURCE_RECORD_LIMIT):
    counts = {kind: 0 for kind in PREFIXES}
    dropped = {kind: 0 for kind in PREFIXES}
    rejected = consumed = 0
    oversized = unterminated = False
    while consumed < input_limit:
        raw = stream.readline(min(line_limit + 1, input_limit - consumed))
        if not raw:
            break
        consumed += len(raw)
        ended = raw.endswith(b'\n')
        kind = next((k for k, prefix in PREFIXES.items() if raw.startswith(prefix)), None)
        if oversized or len(raw) > line_limit or not ended:
            if not oversized and kind:
                rejected += 1
            oversized = not ended
            unterminated = not ended
            continue
        unterminated = False
        if not kind:
            continue
        try:
            line = raw.rstrip(b'\r\n').decode('ascii')
        except UnicodeDecodeError:
            rejected += 1
            continue
        if not valid(kind, line):
            rejected += 1
        elif counts[kind] < (source_record_limit if kind == 'source' else record_limit):
            emit(line)
            counts[kind] += 1
        else:
            dropped[kind] += 1
    budget_reached = consumed >= input_limit
    incomplete = budget_reached or unterminated or rejected > 0 or any(dropped.values())
    return {'schema': 1, 'records': counts, 'dropped_valid_records': dropped,
            'rejected_prefix_records': rejected, 'input_bytes_scanned': consumed,
            'scan_budget_reached': budget_reached, 'unterminated_input': unterminated,
            'status': ('unavailable' if not any(counts.values()) else
                       'partial' if incomplete else 'observed'),
            'test_outcome': 'not_inferred', 'physical_authority': False}


def main():
    print(f'SEATED_CANDIDATE_TIMING_BEGIN max_phase_records={RECORD_LIMIT} '
          f'max_worker_records={RECORD_LIMIT} max_source_records={SOURCE_RECORD_LIMIT} '
          f'max_input_bytes={INPUT_LIMIT} max_line_bytes={LINE_LIMIT}')
    try:
        path = Path(sys.argv[1])
        if path.is_symlink() or not stat.S_ISREG(path.stat().st_mode):
            raise ValueError('regular owned log required')
        with path.open('rb') as stream:
            summary = collect(stream, print)
    except (OSError, ValueError, IndexError) as error:
        # Never include an arbitrary OS/parser message or private path.
        summary = {'schema': 1, 'status': 'unavailable',
                   'error_type': type(error).__name__, 'test_outcome': 'not_inferred',
                   'physical_authority': False}
    print('SEATED_CANDIDATE_TIMING_SUMMARY=' + json.dumps(summary, separators=(',', ':'), sort_keys=True))


if __name__ == '__main__':
    main()
