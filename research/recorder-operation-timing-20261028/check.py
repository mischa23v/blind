"""Source/provenance checks only; not native Swift execution or latency evidence."""
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

def release(source):
    result, debug = [], 0
    for line in source.splitlines(True):
        if line.strip() == '#if DEBUG':
            debug += 1
        elif debug and line.lstrip().startswith('#if '):
            debug += 1
        elif debug and line.strip() == '#endif':
            debug -= 1
        elif not debug:
            result.append(line)
    assert debug == 0
    return re.sub(r'\s+', '', ''.join(result))

def ordered(source, *tokens):
    previous = 0
    for token in tokens:
        current = source.find(token, previous)
        assert current >= previous, token
        previous = current + len(token)

def checks_worker(source, name, end, kind, database_return):
    body = source[source.index(name):source.index(end, source.index(name))]
    ordered(body, 'diagnosticOperations.begin(.' + kind + ')',
            'timing?.mark(.inlineDelivered)', 'timing?.mark(.queued)', 'queue.async',
            'timing?.mark(.workerStarted)', 'timing?.mark(.loadFinished)',
            database_return, 'timing?.mark(.databaseReturned)',
            'timing?.mark(.workerFinished)', 'DispatchQueue.main.async',
            'timing?.mark(.mainDelivered)', 'completion(')

runtime_path = 'ios/BlindAssist/RecordedRouteStore.swift'
tests_path = 'ios/BlindAssistTests/RecordedRouteStoreTests.swift'
runtime = (R / runtime_path).read_text()
tests = (R / tests_path).read_text()
before = (P / 'RecordedRouteStore.swift.before').read_text()
old_tests = (P / 'RecordedRouteStoreTests.swift.before').read_text()
for name, pin in {
    'RecordedRouteStore.swift': '414c9416b6aa4dedc3a0bcd3ac51d8539a8b7a16a1879cd7fc7532310d398fde',
    'RecordedRouteStoreTests.swift': '47f565d7aa0e56c534d4cf5fde52744afbdc04dad2ee1591ef83ecbb04e291d5',
}.items():
    check('exact current-feature preimage: ' + name, hashlib.sha256((P / (name + '.before')).read_bytes()).hexdigest() == pin)
check('release runtime tokens unchanged', release(runtime) == release(before))
check('disabled by default; only explicit test opt-in', 'private var enabled = false' in runtime
      and 'guard enabled else { return nil }' in runtime
      and tests.count('enableOperationTimingForTesting()') == 3)
check('two latest handles, seven numeric slots, bounded monotonic index',
      'latest: [DiagnosticOperationTiming?] = [nil, nil]' in runtime
      and 'values: [TimeInterval?] = [nil, nil, nil, nil, nil, nil, nil]' in runtime
      and 'if index < Int.max { index += 1 }' in runtime)
check('first phase assignment is locked', 'lock.lock(); defer { lock.unlock() }\n            if values[phase.rawValue] == nil' in runtime)
check('snapshot copies under lock, formats later', 'lock.lock(); let times = values; lock.unlock()' in runtime)
check('no callback stdout', 'print(' not in runtime)

specs = [
    ('func page(cursor:', '    func pinLatest(', 'read', 'try repository.reversePage('),
    ('func clear(', '    private func openRepository()', 'clear', 'self.trip = try repository.state()'),
]
for spec in specs:
    checks_worker(runtime, *spec)
    check('actual marker boundaries: ' + spec[2], True)
    mutated = runtime.replace('timing?.mark(.databaseReturned)', '', 1 if spec[2] == 'read' else 2)
    try:
        checks_worker(mutated, *spec)
    except AssertionError:
        check('boundary mutation rejected: ' + spec[2], True)
    else:
        raise AssertionError('missing boundary was accepted')

for pattern, name in [
    (r'wait\(for:.*?timeout: 5\)', 'all original synchronous 5s waits'),
    (r'await fulfillment\(of:.*?timeout: 5\)', 'all original asynchronous 5s waits'),
    (r'Thread.sleep\(forTimeInterval: 0.05\)', 'original 50ms sleep'),
    (r'XCTAssert\w+\([^\n;]*', 'all original assertions'),
]:
    old, new = re.findall(pattern, old_tests), re.findall(pattern, tests)
    check(name + ' retained', all(new.count(token) >= old.count(token) for token in old))
check('one metadata-only native test added', tests.count('    func test') == old_tests.count('    func test') + 1)
helper = tests[tests.index('    private func snapshot('):tests.index('    func testDiagnosticRequiresOptIn')]
ordered(helper, 'store.preview', 'let receipt = store.diagnosticLastOperationForTesting(.read)',
        'wait(for: [done], timeout: 5)', 'if result == nil ||', 'reportOperation(receipt, wait: "snapshot")')
check('exact snapshot receipt captured before unchanged wait and printed only after failure', True)
clear = tests[tests.index('    func testClearRetiresQueuedRead'):tests.index('    func testOperationTimingReceipts')]
ordered(clear, 'store.preview', 'let oldReceipt =', 'Thread.sleep(forTimeInterval: 0.05)',
        'store.clear', 'let clearReceipt =', 'wait(for: [old,clear], timeout: 5)',
        'if (testRun?.failureCount ?? 0) > failuresBefore', 'reportOperation(oldReceipt', 'reportOperation(clearReceipt')
check('clear wait owns original read and clear receipts, not later overwritten slots', True)
check('separate inline-busy receipt has absent main boundary',
      'admission=rejectedBusy' in tests and 'mainDelivered=missing' in tests)

result = {'checks_passed': len(checks), 'checks': checks,
          'source_sha256': {path: hashlib.sha256((R / path).read_bytes()).hexdigest() for path in [runtime_path, tests_path]},
          'native_tests_authored': 1, 'native_tests_executed': 0, 'swift_compiled': False,
          'diagnosis_only': True, 'speed_or_timeout_fix_claimed': False}
(P / 'CHECK_RESULT.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
