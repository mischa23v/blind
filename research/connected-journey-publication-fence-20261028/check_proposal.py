"""Portable source/provenance checks, NOT Swift compilation or runtime proof."""
import hashlib,json,re
from pathlib import Path
P=Path(__file__).resolve().parent
ROOT=P.parent.parent
baseline=json.loads((P/'BASELINE.json').read_text())
checks=[]
def check(label, condition):
    assert condition,label
    checks.append(label)
applied=(P/'ConnectedJourneyRuntime.swift.before').exists()
for path,digest in baseline['baseline_local_sha256'].items():
    source=P/(Path(path).name+'.before') if applied else ROOT/path
    check('preserved baseline source: '+path,hashlib.sha256(source.read_bytes()).hexdigest()==digest)
    if applied:
        check('canonical matches reviewed proposal: '+path,(ROOT/path).read_bytes()==(P/(Path(path).name+'.proposed')).read_bytes())
runtime=(P/'ConnectedJourneyRuntime.swift.before' if applied else ROOT/'ios/BlindAssist/ConnectedJourneyRuntime.swift').read_text()
proposed=(P/'ConnectedJourneyRuntime.swift.proposed').read_text()
def release(s):
    return re.sub(r'#if DEBUG\n.*?#endif\n','',s,flags=re.S)
check('release task bodies/priority/publication unchanged',release(proposed).replace('let completion = Task {','Task {')==release(runtime))
check('three actual outer task handles retained',proposed.count('let completion = Task {')==3)
check('exactly three typed completion handles',proposed.count('(UUID, Task<Void, Never>)?')==3)
check('no diagnostic seam in release',not re.search('diagnostic.*Completion|waitForPendingOperationsForTesting|DiagnosticCompletionError',release(proposed)))
check('same-ID completion explicitly errors',all(f'guard {key} != id else {{ throw DiagnosticCompletionError.unfinishedOperation }}' in proposed for key in ('loadID','mapWorkID','writing')))
check('successor drain includes each operation', 'while loadID != nil || mapWorkID != nil || writing != nil' in proposed)
tests=(P/'ConnectedJourneyRuntimeTests.swift.before' if applied else ROOT/'ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift').read_text()
ptests=(P/'ConnectedJourneyRuntimeTests.swift.proposed').read_text()
start='    private func until(';end='    private func installed('
old=tests[tests.index(start):tests.index(end)]
new=ptests[ptests.index(start):ptests.index('    /// Wait for the actual operations')]
check('original three-second wait helper byte-identical',old==new)
for name in ('testCancelIsSynchronousAndLatestOnlyWhileWriterIsBlocked','testDeleteWhileRestoreIsPendingCannotReinstallQueuedOldMap','testReplacementOrHoldDuringDelayedRestoreOwnsLatestIntent'):
    def body(s):
        a=s.index('    func '+name);b=s.find('\n    func ',a+1);return s[a:b if b>=0 else len(s)]
    check('held-IO scenario untouched: '+name,body(tests)==body(ptests))
check('all test cases retained', re.findall(r'func (test\w+)\(',tests)==re.findall(r'func (test\w+)\(',ptests))
check('fence asserts storage success and durability','XCTAssertFalse(runtime.storageError, file: file, line: line)' in ptests and 'XCTAssertTrue(runtime.durable, file: file, line: line)' in ptests)
raw=(P/'fee8-first-failure-traces.txt').read_bytes()
check('first-failure traces immutable',hashlib.sha256(raw).hexdigest()==baseline['failure_trace_sha256'])
trace=raw.decode()
q=float(re.search(r'phase=restore-detached-queued uptime=([0-9.]+)',trace)[1]);b=float(re.search(r'phase=restore-detached-begin uptime=([0-9.]+)',trace)[1]);e=float(re.search(r'phase=restore-detached-end uptime=([0-9.]+)',trace)[1])
check('first restore admission exceeded unchanged3s',b-q>3)
check('first restore body under1ms',e-b<.001)
result={'checks_passed':len(checks),'checks':checks,'scope':'portable proposal source/provenance only','swift_compiled':False,'native_executed':False,'first_failure_queue_delay_seconds':b-q,'first_failure_detached_work_seconds':e-b}
(P/('APPLIED_CHECK_RESULT.json' if applied else 'CHECK_RESULT.json')).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
