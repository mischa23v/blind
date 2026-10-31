"""Execute only the proposed bounded extraction fragment, never Apple CI."""
from pathlib import Path
import json
import subprocess
import tempfile

P = Path(__file__).resolve().parent
R = P.parent.parent
fragment = (P / 'EXTRACTION.proposed').read_text()
source = (R / 'tools/ci/native-apple.sh').read_text()
before = (P / 'native-apple.sh.before').read_text()
start = source.index("      echo 'RECORDED_ROUTE_TIMING_BEGIN")
end = source.index("      echo 'RECORDED_ROUTE_TIMING_END'", start) + len("      echo 'RECORDED_ROUTE_TIMING_END'\n")
assert source[start:end] == fragment
assert source[:start] + source[end:] == before
checks = ['helper diff exactly approved three extraction lines; existing scene extraction preserved']
with tempfile.TemporaryDirectory() as directory:
    log = Path(directory) / 'unit.log'
    log.write_text('PRIVATE_CAMERA_PAYLOAD secretA\nMODEL_REPLY secretB\nxRECORDED_ROUTE_WAIT_FAILURE secretC\n'
                   + ''.join('RECORDED_ROUTE_WAIT_FAILURE fixture=activeTrip index=' + str(i)
                             + ' numeric=' + ('9' * 1800 if i == 0 else '1') + '\n' for i in range(12)))
    script = 'set -euo pipefail\nout="$1"\nlabel=unit\nstatus=65\n' + fragment + 'test "$status" -eq 65\n'
    result = subprocess.run(['bash', '-c', script, 'test', directory], capture_output=True, text=True, check=True)
    lines = [line for line in result.stdout.splitlines() if line.startswith('RECORDED_ROUTE_WAIT_FAILURE ')]
    assert len(lines) == 8 and max(map(len, lines)) <= 1500
    checks += ['eight-line cap', '1500-character cap']
    assert all(token not in result.stdout for token in ['secret', 'PRIVATE_CAMERA_PAYLOAD', 'MODEL_REPLY'])
    checks += ['unrelated private/model/near-prefix lines excluded', 'existing failure status65 preserved']
    log.write_text('MODEL_REPLY private text only\n')
    result = subprocess.run(['bash', '-c', script, 'test', directory], capture_output=True, text=True, check=True)
    assert len(result.stdout.splitlines()) == 2 and 'private' not in result.stdout
    checks += ['missing matches cannot abort later extraction']
    function = source[source.index('run_logged() {'):source.index('\ncase "$mode"')]
    fixture = Path(directory) / 'fixture.log'
    fixture.write_text('RECORDED_ROUTE_WAIT_FAILURE fixture=clearRetirement wait=clear originalBudget=5 metadata=synthetic\n')
    for status in [0, 65]:
        command = ('set -euo pipefail\nout="$1"\nfixture_path="$2"\n' + function
                   + f'\nfixture() {{ cat "$fixture_path"; return {status}; }}\nrun_logged unit fixture\n')
        result = subprocess.run(['bash', '-c', command, 'test', directory, str(fixture)],
                                cwd=R, capture_output=True, text=True, timeout=5)
        assert result.returncode == status
        assert ('RECORDED_ROUTE_TIMING_BEGIN' in result.stdout) == (status != 0)
    checks += ['real helper emits probe excerpt only on failure', 'real helper preserves status0 and status65']
output = {'checks_passed': len(checks), 'checks': checks, 'apple_ci_executed': False,
          'fragment_applied_to_helper': True}
(P / 'EXTRACTION_CHECK_RESULT.json').write_text(json.dumps(output, indent=2) + '\n')
print(json.dumps(output, indent=2))
