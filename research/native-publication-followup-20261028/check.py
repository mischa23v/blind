"""Portable source/receipt checks only; not Swift execution."""
from pathlib import Path
import re,json,hashlib
P=Path(__file__).resolve().parent;R=P.parent.parent
checks=[]
def require(name, value):
 assert value,name
 checks.append(name)
def src(name):return (R/name).read_text()
r=src('ios/BlindAssist/ObservedSceneRuntime.swift');old=(P/'ObservedSceneRuntime.swift.before').read_text()
release=lambda s:re.sub(r'#if DEBUG\n.*?#endif\n','',s,flags=re.S)
require('release scene runtime byte-identical',release(r)==release(old))
require('completion created only after accepted workID',r.index('workID = id')<r.index('let completion = DiagnosticWorkCompletion()'))
require('actual main callback defers completion before rejection',r.index('DispatchQueue.main.async { [weak self] in')<r.index('defer { completion.finish() }')<r.index('guard let self, self.workID == id'))
require('single bounded continuation',r.count('private var waiter: CheckedContinuation<Void, Never>?')==1 and 'guard waiter == nil else { throw WaitError.alreadyWaiting }' in r)
require('idempotent complete and waiter release',all(x in r for x in ['guard !finished else { return }','finished = true','let pending = waiter; waiter = nil','pending?.resume()']))
require('no-work/completed waits return',all(x in r for x in ['guard let id = workID else { return }','if finished { return }']))
require('waiter matches exact work ID','completion.0 == id' in r)
require('no completion API in release','DiagnosticWorkCompletion' not in release(r) and 'waitForCurrentWorkForTesting' not in release(r))
t=src('ios/BlindAssistTests/ObservedSceneRuntimeTests.swift');ot=(P/'ObservedSceneRuntimeTests.swift.before').read_text()
require('all scene test names retained',re.findall(r'func (test\w+)',t)==re.findall(r'func (test\w+)',ot))
require('all original scene assertions retained',all(t.count(a)>=ot.count(a) for a in re.findall(r'XCTAssert\w+\([^\n;]*',ot)))
require('no sleep or assumed queue marker remains','Task.sleep' not in t and 'goalDrained' not in t and 'bodyDrained' not in t)
require('original1.2s actual latency assertion retained','XCTAssertLessThanOrEqual(elapsed, 1.2,' in t)
require('expiry1.6s remains','fresh.revalidate(now: 1.6); XCTAssertNil(fresh.plan)' in t)
c=src('ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift');oc=(P/'ConnectedJourneyRuntimeTests.swift.before').read_text()
a=oc.index('    func testDeleteWhileRestoreIsPendingCannotReinstallQueuedOldMap()');b=oc.index('    func testReplacementOrHoldDuringDelayedRestoreOwnsLatestIntent()',a)
oldblock=oc[a:b];newblock=oldblock.replace('try await until(runtime) { !runtime.loading && runtime.pendingMapWorkCount == 0 && runtime.pendingWriteCount == 0 }','// IO is released: fence actual restore, catalog and durable-write publication.\n        try await completedWork(runtime)')
require('journey changes exactly one postrelease waiter',c==oc[:a]+newblock+oc[b:])
require('journey release precedes fence',newblock.index('await io.releaseRead()')<newblock.index('try await completedWork(runtime)'))
result={'checks_passed':len(checks),'checks':checks,'swift_executed':False,'native_executed':False,'latency_improvement_claimed':False}
(P/'CHECK_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
