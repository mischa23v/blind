"""Source/timing attribution checks, not Swift compilation or performance evidence."""
from pathlib import Path
import re,json,hashlib
P=Path(__file__).resolve().parent;R=P.parent.parent
checks=[]
def check(name,condition):
 assert condition,name
 checks.append(name)
r=(P/'ObservedSceneRuntime.swift.proposed').read_text();before=(P/'ObservedSceneRuntime.swift.before').read_text();t=(P/'ObservedSceneRuntimeTests.swift.proposed').read_text();old=(P/'ObservedSceneRuntimeTests.swift.before').read_text()
release=lambda s:re.sub(r'#if DEBUG\n.*?#endif\n','',s,flags=re.S)
check('release runtime byte-identical',release(r)==release(before))
check('fixed4 slots only','private var times: [TimeInterval?] = [nil, nil, nil, nil]' in r)
check('sync timestamp writes locked and single assignment','lock.lock(); defer { lock.unlock() }\n            if times[phase.rawValue] == nil { times[phase.rawValue] = now }' in r)
check('numeric snapshots under lock then returned unlocked','lock.lock(); let values = times; lock.unlock()' in r)
check('no timed callback stdout','print(' not in r)
check('four marker calls exactly once',all(r.count('timing.mark(.'+x+')')==1 for x in ['admitted','workerStarted','workerFinished','mainDelivered']))
check('worker markers bracket real processing',r.index('timing.mark(.workerStarted)')<r.index('worker.scene.setIntent(intent')<r.index('let snapshot = worker.scene.observe')<r.index('let plan = body.flatMap')<r.index('timing.mark(.workerFinished)'))
check('main entry marker inside actual callback',r.index('DispatchQueue.main.async { [weak self] in')<r.index('timing.mark(.mainDelivered)')<r.index('guard let self, self.workID == id'))
check('elapsed captured before optional phase printing',t.index('let elapsed = ProcessInfo.processInfo.systemUptime - started')<t.index('if elapsed > 1.2 {')<t.index('OBSERVED_SCENE_FENCE_PHASE'))
check('unchanged1.2s latency assertion', 'XCTAssertLessThanOrEqual(elapsed, 1.2, "Original latency budget exceeded; functional completion is not a speed claim")' in t)
case=t[t.index('func testGoalAndBodyChangesFenceQueuedPlansWithoutRetiringScene'):]
parts=case.split('try await runtime.waitForCurrentWorkForTesting()')
check('each distinct job captured immediately after own fence',len(parts)==4 and all(parts[i+1].lstrip().startswith('let '+name+'Timing = runtime.diagnosticLastWorkTimingForTesting()') for i,name in enumerate(['goal','body','fresh'])))
check('all prior assertions retained',all(t.count(x)>=old.count(x) for x in re.findall(r'XCTAssert\w+\([^\n;]*',old)))
check('formatting invoked only after elapsed captured',t.index('let elapsed = ProcessInfo.processInfo.systemUptime - started')<t.index('timing?.report()'))
check('numeric snapshot has no formatting', 'String(' not in r[r.index('func snapshot(id:'):r.index('    // Exact completion')])
applied=True
for path,digest in json.loads((P/'BASELINE.json').read_text())['source_sha256'].items():
 check('preimage source retained '+path,hashlib.sha256((P/(Path(path).name+'.before')).read_bytes()).hexdigest()==digest)
 if hashlib.sha256((R/path).read_bytes()).hexdigest()==digest:
  applied=False
  check('frozen canonical source untouched '+path,True)
 else:
  check('canonical equals reviewed proposal '+path,(R/path).read_bytes()==(P/(Path(path).name+'.proposed')).read_bytes())
result={'checks_passed':len(checks),'checks':checks,'swift_executed':False,'native_executed':False,'speed_claimed':False,'status':'applied source candidate' if applied else 'proposal only'}
(P/('APPLIED_CHECK_RESULT.json' if applied else 'CHECK_RESULT.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
