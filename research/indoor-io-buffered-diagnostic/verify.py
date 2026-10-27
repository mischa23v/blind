#!/usr/bin/env python3
"""Lightweight static harness checks only; never invokes a Swift/Apple toolchain."""
import ast
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from instrument import FILES, instrument

PIN = 'e9e18d15fe1fdac1ff1487b3c2a8a2e731607427'
ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
for filename in ('instrument.py', 'refine.py', 'resolution.py', 'run.py', 'verify.py', 'recorder.py', 'verify_recorder.py'):
    ast.parse(Path(__file__).with_name(filename).read_text())
original = {p: subprocess.check_output(['git', 'show', f'{PIN}:{p}'], cwd=ROOT).decode() for p in FILES}

def materialize(root, texts):
    for p, text in texts.items():
        target = root / p
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    materialize(root, original)
    assert instrument(root) == FILES
    patched = {p: (root / p).read_text() for p in FILES}
    assert all(patched[p] != original[p] for p in FILES)
    for p in FILES:
        for marker in ('timeout: 10', 'XCTAssert', 'XCTUnwrap', 'qos: .utility',
                       'queue.async', 'DispatchQueue.main.async', 'done.fulfill()'):
            assert patched[p].count(marker) == original[p].count(marker), (p, marker)
    test = patched[FILES[-1]]
    assert test.count('IndoorIOPhaseTrace.flushAfterWait()') == 2
    assert 'await fulfillment(of: [done], timeout: 10)\n        IndoorIOPhaseTrace.emit("test.wait.end")\n        IndoorIOPhaseTrace.flushAfterWait()\n        try XCTUnwrap(result).get()' in test
    assert 'wait(for: [done], timeout: 10); IndoorIOPhaseTrace.emit("test.wait.end"); IndoorIOPhaseTrace.flushAfterWait(); try XCTUnwrap(result).get()' in test
    assert all('flushAfterWait()' not in patched[p] for p in FILES[1:-1])
    try:
        instrument(root)
    except AssertionError:
        pass
    else:
        raise AssertionError('Double application accepted')
    assert patched == {p: (root / p).read_text() for p in FILES}, 'Failed patch partially wrote source'
    materialize(root, original)
    instrument(root, arm="userInitiated")
    treatment = {p: (root / p).read_text() for p in FILES}
    assert treatment[FILES[0]].count('qos: .userInitiated') == 1
    assert treatment[FILES[0]].replace('qos: .userInitiated', 'qos: .utility') == patched[FILES[0]]
    assert all(treatment[p] == patched[p] for p in FILES[1:])
    materialize(root, original)
    try:
        instrument(root, arm="unexpected")
    except AssertionError:
        pass
    else:
        raise AssertionError('Unknown arm accepted')
    assert original == {p: (root / p).read_text() for p in FILES}
    broken = dict(original)
    broken[FILES[-1]] = original[FILES[-1]].replace('timeout: 10', 'timeout: 11')
    materialize(root, broken)
    try:
        instrument(root)
    except AssertionError:
        pass
    else:
        raise AssertionError('Drifted anchors accepted')
    assert broken == {p: (root / p).read_text() for p in FILES}, 'Drift failure partially wrote source'
print(json.dumps({'source_pin': PIN, 'python_ast': 'passed', 'exact_four_file_instrumentation': 'passed',
                  'original_wait_assertion_qos_dispatch_counts': 'preserved',
                  'double_application_and_anchor_drift': 'rejected_without_writes',
                  'treatment_diff': 'exactly_one_QoS_line', 'swift_apple_execution': 'not_run'}, indent=2))
