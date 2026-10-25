"""One fixed native test invocation with a bounded owned process group."""
from pathlib import Path
import os
import signal
import subprocess
import sys

out = Path(sys.argv[1])
sim = sys.argv[2]
command = ['xcodebuild', '-project', str(out / 'project/SelectedDocumentProbe.xcodeproj'),
           '-scheme', 'SelectedDocumentProbe', '-configuration', 'Debug', '-jobs', '2',
           '-derivedDataPath', str(out / 'DerivedData'), '-disableAutomaticPackageResolution', '-skipPackageUpdates',
           '-destination', 'platform=iOS Simulator,id=' + sim, '-destination-timeout', '120',
           '-only-testing:SelectedDocumentNativeTests/SelectedDocumentPDFTests',
           '-parallel-testing-enabled', 'NO', '-maximum-concurrent-test-simulator-destinations', '1',
           '-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '60',
           '-maximum-test-execution-time-allowance', '90',
           '-resultBundlePath', str(out / 'probe.xcresult'), 'CODE_SIGNING_ALLOWED=NO', 'test']
with (out / 'test.log').open('wb') as log:
    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        status = process.wait(timeout=600)
    except subprocess.TimeoutExpired:
        # Only this invocation's newly-created process group, never other jobs.
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        status = 124
(out / 'artifacts/test-exit-code.txt').write_text(str(status) + '\n')
sys.exit(status if 0 <= status <= 255 else 1)
