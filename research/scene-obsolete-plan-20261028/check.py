"""Bounded source/provenance checks; not Swift execution or performance evidence."""
from pathlib import Path
import hashlib
import json
import re

P = Path(__file__).resolve().parent
R = P.parent.parent
checks = []

def check(name, condition):
    assert condition, name
    checks.append(name)

runtime_path = 'ios/BlindAssist/ObservedSceneRuntime.swift'
tests_path = 'ios/BlindAssistTests/ObservedSceneRuntimeTests.swift'
runtime = (R / runtime_path).read_text()
tests = (R / tests_path).read_text()
before_runtime = (P / 'ObservedSceneRuntime.swift.before').read_text()
before_tests = (P / 'ObservedSceneRuntimeTests.swift.before').read_text()
pins = {
    runtime_path: '44539a67d5739ca37e39d0a39e76ba34753467c9fb4d3e30a456e91ad55190e0',
    tests_path: '439648f8539e10fbfb88105e5beab14a41d964b29b321bbeaa25e7388384c527',
}
for path, digest in pins.items():
    check('2aded preimage retained: ' + path,
          hashlib.sha256((P / (Path(path).name + '.before')).read_bytes()).hexdigest() == digest)

original_tests = tests
for phase in ['goal', 'body', 'fresh']:
    original_tests = original_tests.replace(f'        XCTAssertEqual({phase}Timing?.planWasInvoked, false)\n', '')
original_tests = original_tests[:original_tests.index('    @MainActor func testQueuedObsoletePlanKeepsHistoryAndNextValidPlanStillRuns()')].rstrip() + '\n\n}\n'
check('all original test bytes retained except three additive assertions', original_tests == before_tests)
check('exactly two new native tests', tests.count(' func test') == before_tests.count(' func test') + 2)
check('no timeout QoS or freshness relaxation',
      'qos: .utility' in runtime and 'now - observation.timestamp <= 0.5' in runtime
      and 'now - captured > 0.5' in runtime and 'XCTAssertLessThanOrEqual(elapsed, 1.2,' in tests)
check('actual planner call retained', (R / 'BlindCore/Sources/BlindCore/ObservedScene.swift').exists()
      and 'worker.scene.planCurrent(floor: floor, body: body, now: now)' in runtime)
check('bounded seven timing slots', 'private var times: [TimeInterval?] = [nil, nil, nil, nil, nil, nil, nil]' in runtime)
check('no callback printing', 'print(' not in runtime)
check('only one extra valid-work timing line', tests.count('phase=validCurrent') == 1)
check('valid-work print follows exact fence', re.search(
    r'try await runtime.waitForCurrentWorkForTesting\(\)\s*let currentTiming = runtime.diagnosticLastWorkTimingForTesting\(\)[\s\S]*?phase=validCurrent', tests) is not None)
check('existing bounded extraction prefix and cap retained',
      "grep -E '^OBSERVED_SCENE_FENCE_(PHASE|LATENCY) '" in (R / 'tools/ci/native-apple.sh').read_text()
      and '| head -8 | cut -c 1-1500' in (R / 'tools/ci/native-apple.sh').read_text())

result = {
    'checks_passed': len(checks), 'checks': checks,
    'source_sha256': {path: hashlib.sha256((R / path).read_bytes()).hexdigest() for path in pins},
    'native_tests_authored': 2, 'native_tests_executed': 0,
    'swift_compiled': False, 'speed_claimed': False,
    'status': 'source candidate; native validation required',
}
(P / 'CHECK_RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
