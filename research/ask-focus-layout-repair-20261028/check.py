#!/usr/bin/env python3
"""Checkpoint byte/source consistency only; does not execute or render SwiftUI."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
here = Path(__file__).resolve().parent
manifest = json.loads((here / 'verification.json').read_text())
for record in manifest['files']:
    path = root / record['path']
    data = path.read_bytes()
    assert len(data) == record['bytes'], record['path']
    assert hashlib.sha256(data).hexdigest() == record['sha256'], record['path']
    blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    assert blob == record['gitBlobSHA1'], record['path']

dashboard = (root / 'ios/BlindAssist/DashboardView.swift').read_text()
start = dashboard.index('                Picker(t("Look at", "انظر إلى"), selection: $focus) {')
end = dashboard.index('                Button(t("Ask about the camera view",', start)
picker = dashboard[start:end]
wrap = '\n                        .lineLimit(nil)\n                        .fixedSize(horizontal: false, vertical: true)'
style = ('                // Give each option a full row instead of squeezing the selected\n'
         '                // value beside "Look at". Keep native selection and text scaling.\n'
         '                .pickerStyle(.inline)\n')
assert picker.count(wrap) == 6
assert picker.count(style) == 1
restored = dashboard[:start] + picker.replace(wrap, '').replace(style, '') + dashboard[end:]
assert hashlib.sha256(restored.encode()).hexdigest() == manifest['baseline']['dashboardSHA256']
baseline_bytes = restored.encode()
assert hashlib.sha1(b'blob ' + str(len(baseline_bytes)).encode() + b'\0' + baseline_bytes).hexdigest() == manifest['baseline']['dashboardGitBlobSHA1']
assert len(dashboard.splitlines()) - len(restored.splitlines()) == 15
by_path = {record['path']: record for record in manifest['files']}
assert by_path['ios/BlindAssistUITests/LaunchTests.swift']['gitBlobSHA1'] == manifest['baseline']['unchangedAuditGitBlobSHA1']
assert by_path['tools/test/helpers/full-audit-contract.mjs']['gitBlobSHA1'] == manifest['baseline']['unchangedAuditHelperGitBlobSHA1']
assert manifest['checks']['sourceContracts'] == {'passed': 7, 'failed': 0, 'skipped': 0}
receipt = (here / 'source-tests.txt').read_text()
for summary in ['ℹ tests 7', 'ℹ pass 7', 'ℹ fail 0', 'ℹ skipped 0']:
    assert summary in receipt
assert manifest['checks']['nativeExecution'] == 'not run; no Swift/Xcode/Apple SDK/simulator'
print('PASS: exact 15-line source delta, baseline provenance, audit-source preservation and checkpoint hashes')
print('NOT PROVEN: native compilation, rendering, VoiceOver or accessibility audit')
