import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const s=await readFile(new URL('../../ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift',import.meta.url),'utf8');
test('priority observation remains synchronous, task-presence explicit, no unsafe handle escape',()=>{
 const helper=s.slice(s.indexOf('private func runtimeTaskContext'),s.indexOf('// Per-test metadata only'));
 assert.match(helper,/let hasTask = withUnsafeCurrentTask \{ \$0 != nil \}/);
 assert.match(helper,/Task.currentPriority.rawValue/);assert.match(helper,/hasTask=/);
 assert.doesNotMatch(helper,/\bTask\s*\{|Task.detached|await|sleep|print|return \$0/);
});
test('IO, phase and wait records include current task context without callback I/O',()=>{
 const records=s.split('\n').filter(x=>/traceBuffer.record\("NATIVE_RUNTIME_(IO|PHASE|WAIT) /.test(x));
 assert.equal(records.length,5);for(const line of records)assert.ok(line.includes('runtimeTaskContext()'));
 assert.equal((s.match(/print\(/g)||[]).length,2);
});
test('fulfillment timestamp follows unchanged condition and fulfill, no time-bound change',()=>{
 const callback=s.slice(s.indexOf('runtime.onChange = {'),s.indexOf('defer { runtime.onChange'));
 assert.match(callback,/guard !completed, condition\(\) else \{ return \}/);
 assert.ok(callback.indexOf('completed = true; done.fulfill()')<callback.indexOf('phase=fulfilled'));
 assert.match(callback,/line=\\\(line\)/);
 assert.match(s,/await fulfillment\(of: \[done\], timeout: 3\)/);
 assert.equal((s.match(/func test\w+/g)||[]).length,17);
});
