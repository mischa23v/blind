#!/usr/bin/env python3
"""Source contracts only: no Swift execution, build or app patch application."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
pins = json.loads((HERE / 'SOURCE_PINS.json').read_text())
for name, digest in pins.items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
fixture = (HERE / 'tests/main.swift').read_text()
assert 'import MeshCandidateIngress83' in fixture
assert 'try owner.reset()\ncheck(delayedOldCallback()' in fixture
assert 'context.sessionID != testKnownOldOrigin' in fixture
assert 'context.captureUptime == nil' in fixture
assert 'owner.remove(anchorID: anchor, receiptUptime: 21)' in fixture
assert 'heldOwner.ingest' in fixture and 'old reservation survives reset' in fixture
assert all(token not in fixture for token in ['import ARKit', '@testable', 'class MeshCandidateIngress83', 'ARSession()'])
print(json.dumps({'sourcePinsMatched': len(pins), 'witnessAuthored': True,
                  'swiftCompiled': False, 'swiftExecuted': False,
                  'deviceExecuted': False, 'productionChanged': False}))
