// Structural counterexamples only; native timing discrimination requires Apple execution.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../../'+path,import.meta.url),'utf8');
const phases=['restore-task-queued','restore-task-entered','restore-read-resumed','restore-detached-queued','restore-detached-begin','restore-detached-end','restore-main-resumed','restore-main-error-resumed','catalog-task-queued','catalog-task-entered','catalog-detached-queued','catalog-detached-begin','catalog-detached-end','catalog-main-resumed'];
function debugOnly(source){
 const blocks=[...source.matchAll(/#if DEBUG\n([\s\S]*?)#endif/g)].map(m=>m[1]);
 const release=source.replace(/#if DEBUG\n[\s\S]*?#endif\n/g,'');
 assert.doesNotMatch(release,/diagnosticPhaseRecorder|trace\?|NATIVE_RUNTIME_PHASE/);
 assert.match(blocks.join('\n'),/var diagnosticPhaseRecorder: \(@Sendable \(String, UUID, TimeInterval\) -> Void\)\?/);
 assert.doesNotMatch(source,/diagnosticPhaseRecorder\s*=|print\(|os_log|Logger\(/);
 for(const phase of phases)assert.equal((blocks.join('\n').match(new RegExp('"'+phase+'"','g'))||[]).length,1,phase);
 assert.equal((source.match(/Task\.detached\(priority: \.utility\)/g)||[]).length,2);
 for(const line of source.split('\n').filter(l=>l.includes('trace?('))){
  assert.match(line,/, (?:id|input\.0), ProcessInfo.processInfo.systemUptime\)/);
  assert.doesNotMatch(line,/data|payload|snapshot|goal|status/);
 }
}
test('phase recorder is DEBUG only, nil by default and metadata only',async()=>debugOnly(await read('ios/BlindAssist/ConnectedJourneyRuntime.swift')));
test('default-active, release-visible and payload telemetry counterexamples reject',async()=>{
 const source=await read('ios/BlindAssist/ConnectedJourneyRuntime.swift');
 for(const changed of [source.replace('var diagnosticPhaseRecorder:', 'var diagnosticPhaseRecorder = { _ in } //'),source.replace('#if DEBUG','#if RELEASE'),source.replace('"restore-detached-begin", id,','"restore-detached-begin", data,')])assert.throws(()=>debugOnly(changed));
});
test('actual source positions separate detached admission, work and MainActor return',async()=>{
 const source=await read('ios/BlindAssist/ConnectedJourneyRuntime.swift');
 for(const scope of ['restore','catalog']){
  const queued=source.indexOf(`"${scope}-detached-queued"`),detached=source.indexOf('Task.detached(priority: .utility)',queued),begin=source.indexOf(`"${scope}-detached-begin"`,detached),end=source.indexOf(`defer { trace?("${scope}-detached-end"`,begin),value=source.indexOf('}.value',end),resumed=source.indexOf(`"${scope}-main-resumed"`,value);
  assert.ok(queued<detached&&detached<begin&&begin<end&&end<value&&value<resumed);
 }
 assert.ok(source.indexOf('"restore-read-resumed"')>source.indexOf('let data = try await io.read()'));
 assert.match(source,/let trace = diagnosticPhaseRecorder/);
});
test('all runtime test instances install immutable callback before return without changing timeout',async()=>{
 const source=await read('ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift');
 assert.equal((source.match(/ConnectedJourneyRuntime\(io:/g)||[]).length,1);
 assert.equal((source.match(/makeRuntime\(io:/g)||[]).length,9); // helper plus all eight instances
 assert.match(source,/#if DEBUG\s+let testName = name\s+let traceBuffer = traceBuffer\s+runtime.diagnosticPhaseRecorder = \{ phase, operation, uptime in/);
 assert.match(source,/NATIVE_RUNTIME_PHASE test=\\\(testName\) operation=\\\(operation\) phase=\\\(phase\) uptime=\\\(uptime\)/);
 assert.match(source,/await fulfillment\(of: \[done\], timeout: 3\)/);assert.match(source,/throw WaitError.timedOut/);
});
