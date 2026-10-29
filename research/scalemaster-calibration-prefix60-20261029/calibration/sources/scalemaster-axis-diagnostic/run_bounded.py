"""One admitted axis-diagnostic attempt, no archives/network or automatic retry."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import resource
import subprocess
import sys
import time


def main():
    start = time.monotonic()
    resource.setrlimit(resource.RLIMIT_AS, (64 * 2**20, 256 * 2**20))
    resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
    if hasattr(os, 'sched_getaffinity'):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    parser = argparse.ArgumentParser()
    parser.add_argument('--previous-run', required=True)
    parser.add_argument('--output-root', required=True)
    parser.add_argument('--root-reviewed-and-slot-clear', action='store_true')
    args = parser.parse_args()
    if not args.root_reviewed_and_slot_clear:
        raise SystemExit('No execution before root source review and CPU-slot clearance')
    src = Path(__file__).resolve().parent
    freeze = src / 'SOURCE_FREEZE.json'
    snapshot = json.loads(freeze.read_text())
    previous = Path(args.previous_run).resolve()
    out = Path(args.output_root).resolve()
    if str(previous) != snapshot['previous_run_absolute_path']:
        raise SystemExit('Not the frozen run-001 input')
    if previous == out or previous in out.parents or out in previous.parents:
        raise SystemExit('Output must not overlap the preserved previous run')
    if out.exists():
        raise SystemExit('Fresh output root required; no overwrite/retry')
    private = previous.parent
    if out.parent != private:
        raise SystemExit('Output must remain a private sibling of run-001')
    for name, expected in snapshot['scripts_sha256'].items():
        if hashlib.sha256((src / name).read_bytes()).hexdigest() != expected:
            raise SystemExit('Source freeze mismatch')
    for path, expected in snapshot['frozen_inputs_sha256'].items():
        if hashlib.sha256(Path(path).read_bytes()).hexdigest() != expected:
            raise SystemExit('Pinned input changed: ' + path)
    # PNG hashes are bound by the pinned extraction receipt; the real child
    # verifies each PNG when its split is loaded, never loading holdout early.
    out.mkdir()
    stages = [
        ['--synthetic-only', '--output-root', str(out)],
        ['--approve-real-run', '--previous-run', str(previous), '--output-root', str(out)],
    ]
    env = dict(os.environ)
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    env['PYTHONOPTIMIZE'] = '0'
    for key in ('OPENBLAS_NUM_THREADS', 'OMP_NUM_THREADS', 'MKL_NUM_THREADS', 'NUMEXPR_NUM_THREADS'):
        env[key] = '1'
    results = []
    for index, stage in enumerate(stages):
        child = resource.getrusage(resource.RUSAGE_CHILDREN)
        own = resource.getrusage(resource.RUSAGE_SELF)
        used = child.ru_utime + child.ru_stime + own.ru_utime + own.ru_stime
        cpu_left = 30. - used
        wall_left = 45. - (time.monotonic() - start)
        if cpu_left < 2 or wall_left < 2:
            results.append({'stage': index, 'error': 'cumulative resource budget exhausted'})
            break
        def limits():
            # Reserve one CPU second for parent accounting/receipt; no soft-cap handler.
            allowance = math.floor(cpu_left - 1)
            resource.setrlimit(resource.RLIMIT_CPU, (allowance, allowance))
            resource.setrlimit(resource.RLIMIT_AS, (192 * 2**20, 192 * 2**20))
            resource.setrlimit(resource.RLIMIT_FSIZE, (20 * 2**20, 20 * 2**20))
        try:
            result = subprocess.run([sys.executable, str(src / 'axis_diagnostic.py'), *stage],
                                    env=env, preexec_fn=limits, timeout=wall_left - 1,
                                    capture_output=True, text=True)
            results.append({'stage': index, 'returncode': result.returncode,
                            'stdout': result.stdout, 'stderr': result.stderr})
        except subprocess.TimeoutExpired:
            results.append({'stage': index, 'error': 'cumulative 45-second wall cap'})
            break
        if result.returncode:
            break
    child = resource.getrusage(resource.RUSAGE_CHILDREN)
    own = resource.getrusage(resource.RUSAGE_SELF)
    cpu_seconds = child.ru_utime + child.ru_stime + own.ru_utime + own.ru_stime
    wall_seconds = time.monotonic() - start
    resource_violations = []
    if cpu_seconds > 30:
        resource_violations.append('measured_cumulative_CPU_exceeded_30s')
    if wall_seconds > 45:
        resource_violations.append('measured_wall_exceeded_45s')
    if child.ru_maxrss + own.ru_maxrss > 256 * 1024:
        resource_violations.append('conservative_peak_RSS_sum_exceeded_256MiB')
    receipt = {'stages': results,
               'cpu_seconds': cpu_seconds,
               'wall_seconds': wall_seconds,
               'max_child_rss_KiB': child.ru_maxrss,
               'controller_max_rss_KiB': own.ru_maxrss,
               'sum_of_peak_RSS_upper_bound_KiB': child.ru_maxrss + own.ru_maxrss,
               'all_stages_completed': len(results) == len(stages) and all(r.get('returncode') == 0 for r in results) and not resource_violations,
               'resource_violations': resource_violations,
               'source_freeze_sha256': hashlib.sha256(freeze.read_bytes()).hexdigest(),
               'limits': {'cumulative_CPU_seconds': 30, 'wall_seconds': 45, 'CPU_affinity_count': 1,
                          'controller_address_space_MiB': 64, 'child_address_space_MiB': 192,
                          'sum_address_space_reservations_MiB': 256, 'per_artifact_size_MiB': 20,
                          'new_extraction_bytes': 0, 'archive_reads': 0},
               'failure_policy': 'inconclusive; no gate changes, pair reselection or automatic retry'}
    with (out / 'execution-receipt.json').open('x') as f:
        json.dump(receipt, f, indent=2)
    print(json.dumps(receipt, indent=2))
    if not receipt['all_stages_completed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
