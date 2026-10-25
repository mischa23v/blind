"""Metadata and bounded textual failures only; never export PDF/font attachments."""
from pathlib import Path
import json
import subprocess
import sys

out, pins_path = Path(sys.argv[1]), Path(sys.argv[2])
status = int(sys.argv[3])
artifacts = out / 'artifacts'
artifacts.mkdir(exist_ok=True)
pins = json.loads(pins_path.read_text())
receipt = {'scope': 'Actual PDFKit byte extraction and direct picker-delegate tests only',
           'expectedTests': 14, 'exitCode': status, 'sourcePins': pins,
           'appControllerAcceptance': False, 'osPickerGrantAcceptance': False,
           'voiceOverOrAudioAcceptance': False, 'participantAcceptance': False}
bundle = out / 'probe.xcresult'
if bundle.is_dir():
    try:
        result = subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(bundle)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        result = None
    if result is not None and result.returncode == 0 and len(result.stdout) <= 2 * 1024 * 1024:
        try:
            summary = json.loads(result.stdout)
            receipt['counts'] = {key: summary.get(key) for key in ('totalTestCount', 'passedTests', 'failedTests', 'skippedTests')}
        except (ValueError, AttributeError):
            receipt['summaryUnavailable'] = True
    else:
        receipt['summaryUnavailable'] = True
else:
    receipt['summaryUnavailable'] = True
# Read only a bounded tail, not arbitrarily large compiler/test output.
for name in ('test.log', 'prepare.log', 'simulator.log'):
    log = out / name
    if not log.is_file():
        continue
    with log.open('rb') as handle:
        handle.seek(max(0, log.stat().st_size - 64 * 1024))
        tail = handle.read(64 * 1024).decode('utf-8', errors='replace')
    bounded = '\n'.join(line[:1024] for line in tail.splitlines()[-80:])
    bounded = bounded.encode('utf-8')[-(32 * 1024 - 1):].decode('utf-8', errors='ignore')
    (artifacts / ('bounded-' + name + '.txt')).write_text(bounded + '\n')
expected = {'totalTestCount': 14, 'passedTests': 14, 'failedTests': 0, 'skippedTests': 0}
receipt['accepted'] = status == 0 and receipt.get('counts') == expected
(artifacts / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({'accepted': receipt['accepted'], 'counts': receipt.get('counts'), 'exitCode': status}))
sys.exit(0 if receipt['accepted'] else 1)
