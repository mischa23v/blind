#!/usr/bin/env python3
"""Bounded, serial Apple proof of a standalone source adapter; no app/runtime activation."""
import hashlib
import json
import os
from pathlib import Path
import platform
import resource
import signal
import subprocess
import time

HOME = Path(__file__).resolve().parent.parent
BRANCH = 'refs/heads/codex/recovery-hazard-order-20261027'
FILE_CAP = 128 << 20


def run(command, label, out, expected_failure=False):
    log = out / (label + '.log')
    started = time.monotonic()
    code = None
    expired = False
    error = None
    def limits():
        os.setsid()
        resource.setrlimit(resource.RLIMIT_CPU, (180, 180))
        resource.setrlimit(resource.RLIMIT_FSIZE, (FILE_CAP, FILE_CAP))
    try:
        with log.open('wb') as stream:
            child = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT,
                                     env=dict(os.environ, TMPDIR=str(out / 'tmp') + '/'), preexec_fn=limits)
            try:
                code = child.wait(timeout=240)
            except subprocess.TimeoutExpired:
                expired = True
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                code = child.wait()
    except Exception as exc:
        error = type(exc).__name__
    tail = ''
    if log.exists():
        with log.open('rb') as stream:
            stream.seek(0, 2)
            stream.seek(max(0, stream.tell() - 8192))
            tail = stream.read(8192).decode('utf-8', errors='replace')
    # Stage-end scratch accounting only, not a live disk quota/RSS guarantee.
    total = 0
    entries = 0
    for directory, dirs, files in os.walk(out, followlinks=False):
        entries += len(dirs) + len(files)
        if entries > 20_000:
            break
        for filename in files:
            path = Path(directory) / filename
            if not path.is_symlink():
                total += path.stat().st_size
    successful = (code == 0 if not expected_failure else code is not None and code > 0)
    successful = successful and not expired and error is None and entries <= 20_000 and total <= 512 << 20
    receipt = dict(label=label, command=command, exitCode=code, expectedFailure=expected_failure,
                   timedOut=expired, exception=error, wallSeconds=time.monotonic()-started,
                   scratchBytesAfterCommand=total, scratchEntries=entries,
                   fileCapBytes=FILE_CAP, cpuCapSeconds=180, wallTimeoutSeconds=240,
                   scratchAccounting='stage end only; not a live quota or RAM cap',
                   logTail=tail, passed=successful)
    (out / (label + '-receipt.json')).write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))
    if not successful:
        raise RuntimeError(label + ' failed')
    return tail


def output(command):
    return subprocess.check_output(command, text=True, timeout=30).strip()


def main():
    assert platform.system() == 'Darwin', 'Apple host required'
    assert os.environ.get('GITHUB_REPOSITORY') == 'mischa23v/blind'
    assert os.environ.get('GITHUB_REF') == BRANCH
    root = Path(os.environ['GITHUB_WORKSPACE'])
    assert output(['git', '-C', str(root), 'rev-parse', 'HEAD']) == os.environ['GITHUB_SHA']
    assert output(['xcodebuild', '-version']).splitlines()[0] == 'Xcode 27.0'
    assert output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version']) == '27.0'
    pins = json.loads((HOME / 'SOURCE_PINS.json').read_text())
    for name, digest in pins.items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, name
    out = Path(os.environ['RUNNER_TEMP']) / 'blind-mesh-decoder-81'
    out.mkdir(exist_ok=False)
    (out / 'tmp').mkdir()
    source = HOME / 'Sources/MeshBufferDecoder.swift'
    host_sdk = output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'])
    base = ['xcrun', '--sdk', 'macosx', 'swiftc', '-sdk', host_sdk,
            '-module-cache-path', str(out / 'host-cache')]
    run(base + ['-emit-library', '-emit-module', '-module-name', 'MeshBufferDecoder81',
                '-emit-module-path', str(out / 'MeshBufferDecoder81.swiftmodule'), str(source),
                '-o', str(out / 'libMeshBufferDecoder81.dylib')], 'host-module', out)
    run(base + ['-I', str(out), '-L', str(out), '-lMeshBufferDecoder81',
                '-Xlinker', '-rpath', '-Xlinker', str(out), str(HOME / 'tests/main.swift'),
                '-o', str(out / 'fixtures')], 'host-fixtures-compile', out)
    fixture_log = run([str(out / 'fixtures')], 'host-fixtures-run', out)
    assert 'RESULT:' in fixture_log and 'fresh synthetic checks passed' in fixture_log
    negative = out / 'cannot-forge.swift'
    negative.write_text('import MeshBufferDecoder81\n'
        'let forged = MeshBufferDecoder.ValidatedRevision(revision: 1, localVertices: [], '
        'triangleIndices: [], anchorTransform: [], classifications: [], classificationDiagnostics: [])\n')
    negative_log = run(base + ['-I', str(out), '-typecheck', str(negative)],
                       'public-initializer-negative', out, expected_failure=True)
    assert 'inaccessible' in negative_log and 'protection level' in negative_log
    simulator_sdk = output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'])
    run(['xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-sdk', simulator_sdk,
         '-target', 'arm64-apple-ios17.0-simulator', '-module-cache-path', str(out / 'simulator-cache'),
         '-emit-library', '-emit-module', '-module-name', 'MeshBufferDecoder81',
         '-emit-module-path', str(out / 'simulator.swiftmodule'), str(source),
         '-o', str(out / 'libMeshBufferDecoder81-simulator.dylib')], 'simulator-compile-only', out)
    summary = dict(commit=os.environ['GITHUB_SHA'], toolchain=output(['xcrun', 'swiftc', '--version']),
                   hostFixtures='passed', protectedInitializer='passed', simulatorCompile='passed',
                   syntheticFixtureResult=[line for line in fixture_log.splitlines() if line.startswith('RESULT:')],
                   runtimeActivation=False, deviceValidation=False, physicalAuthority=False)
    (out / 'RESULT.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
