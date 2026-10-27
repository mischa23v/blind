#!/usr/bin/env python3
"""Bounded Apple execution of the unchanged extracted body-profile verification."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import selectors
import time
from body_profile_evidence import Evidence, required_names
import subprocess
import tempfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    repo = Path(__file__).resolve().parents[2]
    if platform.system() != 'Darwin':
        raise SystemExit('Apple runner required; no toolchain installation or fallback.')
    temp = Path(os.environ['RUNNER_TEMP']).resolve()
    expected_commit = os.environ['GITHUB_SHA']
    actual_commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
    if actual_commit != expected_commit:
        raise SystemExit('Checkout does not match workflow commit.')
    evidence = temp / 'body-profile-current-evidence'
    evidence.mkdir(exist_ok=False)
    stage = Path(tempfile.mkdtemp(prefix='body-profile-current-', dir=temp))
    verification = stage / 'verification'
    origin = repo / 'research/evaluations/body-aware-warning/verification'
    shutil.copytree(origin, verification, ignore=shutil.ignore_patterns('compiled-inputs.json', '__pycache__'))
    assert not (stage / 'source').exists(), 'Historical overlay must never be present.'
    work = stage / 'work'
    env = dict(os.environ, BLIND_SOURCE_ROOT=str(repo), BODY_WARNING_WORK=str(work))
    script = verification / 'run-tests.sh'
    assert sha(script) == sha(origin / 'run-tests.sh')
    io = repo / 'ios/BlindAssist/SpatialMapIO.swift'
    manifest = json.loads((repo / 'research/indoor-io-qos-proposal/manifest.json').read_text())
    assert sha(io) == manifest['candidate_sha256'], 'Unexpected candidate source.'
    result = {'commit': actual_commit, 'spatial_map_io_sha256': sha(io),
              'harness_sha256': sha(script), 'source_root': str(repo),
              'historical_overlay': False, 'timeout_seconds': 600,
              'compiler_jobs': 2, 'status': 'pending', 'compiled_inputs_verified': False}
    subprocess.run(['xcrun', '--find', 'swift'], check=True)
    with (evidence / 'toolchain.txt').open('w') as log:
        subprocess.run(['xcrun', 'swift', '--version'], stdout=log, stderr=subprocess.STDOUT, check=True)
    # Stream the whole log through a bounded parser; save only 512 KiB head/tail.
    # No global file-size limit: Swift's sparse build cache remains unaffected.
    capture = Evidence(required_names((verification / 'Tests/BodyProfileStoreTests.swift').read_text()))
    run = subprocess.Popen(['bash', str(script)], cwd=repo, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
    timed_out = False
    deadline = time.monotonic() + 600
    with selectors.DefaultSelector() as selector:
        selector.register(run.stdout, selectors.EVENT_READ)
        while selector.get_map():
            if time.monotonic() >= deadline:
                os.killpg(run.pid, signal.SIGKILL)
                timed_out = True
                break
            for key, _ in selector.select(timeout=min(1, max(0, deadline - time.monotonic()))):
                data = os.read(key.fd, 65536)
                if data:
                    capture.feed(data)
                else:
                    selector.unregister(key.fileobj)
        # A child may close stdout then hang; remaining runtime is still bounded.
        try:
            code = run.wait(timeout=max(0.01, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            os.killpg(run.pid, signal.SIGKILL)
            run.wait()
            timed_out = True
            code = 124
    run.stdout.close()
    capture.write_log(evidence / 'verification.log')
    coverage = capture.finish()
    (evidence / 'body-profile-coverage.json').write_text(json.dumps(coverage, indent=2) + '\n')
    result.update(exit_code=124 if timed_out else code,
                  status='timeout' if timed_out else ('passed' if code == 0 and coverage['verified'] else 'failed'),
                  body_profile_coverage_verified=coverage['verified'],
                  log_truncated=coverage['log_truncated'], log_bytes_seen=coverage['log_bytes_seen'])
    inputs = verification / 'compiled-inputs.json'
    try:
        if not inputs.is_file():
            raise ValueError('Compiled-input manifest was not produced.')
        if inputs.stat().st_size > 256 * 1024:
            raise ValueError('Compiled-input manifest exceeds 256 KiB evidence cap.')
        shutil.copy2(inputs, evidence / 'compiled-inputs.json')
        compiled = json.loads(inputs.read_text())
        if compiled.get(str(io)) != sha(io):
            raise ValueError('Current SpatialMapIO is absent or has the wrong SHA.')
        if sha(work / 'Sources/NativeBodyProfile/SpatialMapIO.swift') != sha(io):
            raise ValueError('Compiled SpatialMapIO copy differs from checkout.')
        for name, digest in compiled.items():
            # The unchanged harness extracts the leading DetectorTests verbatim.
            path, marker, fragment = name.partition('#')
            source = Path(path)
            if not (source.is_relative_to(repo) or source.is_relative_to(verification)):
                raise ValueError('Compiled input outside current checkout/fresh verification.')
            data = source.read_bytes()
            if marker:
                if fragment != 'exact-leading-DetectorTests':
                    raise ValueError('Unknown extracted input.')
                data = source.read_text().split('final class ProtocolTests:', 1)[0].encode()
            if hashlib.sha256(data).hexdigest() != digest:
                raise ValueError('Compiled input SHA mismatch: ' + name)
        result['compiled_inputs_verified'] = True
    except (ValueError, OSError) as error:
        result.update(status='failed', manifest_error=str(error))
    # Bound the complete upload, not build/cache files. Unexpected evidence growth
    # fails closed and is explicitly marked rather than silently discarded.
    evidence_bytes = sum(p.stat().st_size for p in evidence.iterdir() if p.is_file())
    if evidence_bytes > 2 * 1024 * 1024:
        result.update(status='failed', artifact_truncated=True,
                      artifact_error='Evidence exceeded 2 MiB cap.')
        for path in evidence.iterdir():
            if path.is_file() and path.stat().st_size > 16384:
                with path.open('rb') as handle:
                    head = handle.read(16384)
                path.write_bytes(head + b'\n[ARTIFACT TRUNCATED: size cap; run failed]\n')
    (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['status'] == 'passed' and result['compiled_inputs_verified'] else 1)


if __name__ == '__main__':
    main()
