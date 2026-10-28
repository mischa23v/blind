#!/usr/bin/env python3
"""Narrow source contract, NOT Swift compilation or runtime race proof."""
import json, re, sys
from pathlib import Path
path = Path(sys.argv[1] if len(sys.argv) > 1 else 'ios/BlindAssistTests/RecordedRouteStoreTests.swift')
source = path.read_text()
checks = []
for name, transition in [
    ('testTrackingLossAndSameSessionRestartWithdrawPinUntilFreshCapture', 'store.breakContinuity()'),
    ('testOldSessionExtractionFailureCannotOwnReplacementSession', 'store.begin(sessionID: b)'),
    ('testDelayedClearCannotEraseLaterSessionSamples', 'store.clear {')
]:
    match = re.search(r'    func ' + re.escape(name) + r'\(.*?(?=\n    func |\Z)', source, re.S)
    assert match, f'missing fixture {name}'
    method = match.group()
    declaration = method.find('entered = DispatchSemaphore(value: 0)')
    offer = method.find('store.offer(', declaration)
    signal = method.find('entered.signal()', offer)
    blocked = method.find('release.wait(', signal)
    awaited = method.find('entered.wait(', blocked)
    change = method.find(transition, awaited)
    assert 0 <= declaration < offer < signal < blocked < awaited < change, f'{name}: entry scope/order invalid'
    assert method.count('entered = DispatchSemaphore(value: 0)') == 1, f'{name}: duplicate declaration'
    assert method.count('entered.signal()') == 1, f'{name}: missing/duplicate signal'
    checks.append(name)
print(json.dumps({'source_contract_checks_passed': checks, 'count': len(checks), 'swift_executed': False}, indent=2))
