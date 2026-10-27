#!/usr/bin/env python3
"""Pure harness policy fixtures; no Apple build, simulator or sensor execution."""
import importlib.util
from pathlib import Path
spec = importlib.util.spec_from_file_location('stage85', Path(__file__).resolve().parents[1]/'apple/ci.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
base = dict(exitCode=65, timedOut=False, scratchCapExceeded=False, fileSizeLimitSignal=False,
            scratchScanComplete=True, exceptionType=None, terminationSignal=None)
unknown = dict(diagnosticReports=[], resourceLimitEvidence='unknown')
marker = 'error: ' + m.SERVICE_CRASH_MARKER + '\n** BUILD FAILED **\n'
cases = [
 ('exact marker with unknown reports', base, unknown, marker, True, True),
 ('compiler error plus marker', base, unknown, 'Thing.swift:9: error: type mismatch\n'+marker, True, False),
 ('linker error plus marker', base, unknown, 'ld: error: undefined symbol\n'+marker, True, False),
 ('fatal compiler diagnostic', base, unknown, 'fatal error: module missing\n'+marker, True, False),
 ('file signal report', base, {'termination': {'indicator':'SIGXFSZ'}}, marker, True, False),
 ('CPU signal report', base, {'termination': {'indicator':'SIGXCPU'}}, marker, True, False),
 ('numeric CPU termination', base, {'termination': {'namespace':'SIGNAL','code':24}}, marker, True, False),
 ('numeric file termination', base, {'termination': {'namespace':'SIGNAL','code':25}}, marker, True, False),
 ('resource exception', base, {'exception': {'type':'EXC_RESOURCE'}}, marker, True, False),
 ('collector observed resource signal', base, {'diagnosticReports':[{'resourceLimitObserved':True}]}, marker, True, False),
 ('timeout', dict(base,timedOut=True), unknown, marker, True, False),
 ('scratch cap', dict(base,scratchCapExceeded=True), unknown, marker, True, False),
 ('parent file limit', dict(base,fileSizeLimitSignal=True), unknown, marker, True, False),
 ('parent CPU signal', dict(base,terminationSignal='SIGXCPU'), unknown, marker, True, False),
 ('incomplete log', base, unknown, marker, False, False),
 ('missing marker', base, unknown, '** BUILD FAILED **', True, False),
 ('duplicate marker', base, unknown, marker+marker, True, False),
]
for name, receipt, diagnostics, log, complete, expected in cases:
 assert m.service_retry_allowed(receipt, diagnostics, log, complete) == expected, name
# Exercise the actual collector encoding boundary with numeric-only IPS metadata.
import json
import tempfile
from unittest.mock import patch
with tempfile.TemporaryDirectory(prefix='stage85-collector-') as folder:
 home = Path(folder); directory = home/'Library/Logs/DiagnosticReports'
 directory.mkdir(parents=True); out = home/'out'; out.mkdir()
 with patch.object(m.Path, 'home', return_value=home):
  for signal in (24, 25):
   report = directory/f'XCBBuildService-{signal}.ips'
   report.write_text('{}\n'+json.dumps({'termination':{'namespace':'SIGNAL','code':signal}}))
   summary = m.service_crash_diagnostics(out, f'numeric-{signal}', 0)
   assert summary['diagnosticReports'][0]['resourceLimitObserved'] is True
   assert summary['resourceLimitEvidence'] == 'observed'
   assert not m.service_retry_allowed(base, summary, marker, True)
   # Also verify the serialized summary consumed on later review preserves the flag.
   saved = json.loads((out/f'numeric-{signal}-diagnostic.json').read_text())
   assert not m.service_retry_allowed(base, saved, marker, True)
   report.unlink()
  outside = home/'outside.ips'
  outside.write_text('{}\n'+json.dumps({'termination':{'namespace':'SIGNAL','code':25}}))
  (directory/'XCBBuildService-link.ips').symlink_to(outside)
  summary = m.service_crash_diagnostics(out, 'symlink', 0)
  assert summary['diagnosticReports'] == []
  assert summary['resourceLimitEvidence'].startswith('unknown')
print(f'PASS: {len(cases)} pure retry-policy fixtures + 3 collector fixtures; no Apple execution')
