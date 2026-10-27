#!/usr/bin/env python3
"""Lightweight static harness checks only; never invokes a Swift/Apple toolchain."""
import ast
import json
from pathlib import Path
import subprocess
import tempfile
from instrument import FILES, instrument

PIN = 'e9e18d15fe1fdac1ff1487b3c2a8a2e731607427'
ROOT = Path(__file__).resolve().parents[2]
for filename in ('instrument.py', 'run.py', 'verify.py'):
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
    try:
        instrument(root)
    except AssertionError:
        pass
    else:
        raise AssertionError('Double application accepted')
    assert patched == {p: (root / p).read_text() for p in FILES}, 'Failed patch partially wrote source'
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
                  'swift_apple_execution': 'not_run'}, indent=2))
