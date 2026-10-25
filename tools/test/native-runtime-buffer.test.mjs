import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const root=new URL('../../',import.meta.url);
const source=await readFile(new URL('ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift',root),'utf8');
test('stdout exists only in unlocked teardown snapshot flush',()=>{
 const before=source.slice(0,source.indexOf('private actor RuntimeIO:'));
 assert.equal((source.match(/print\(/g)||[]).length,2);
 assert.equal((before.match(/print\(/g)||[]).length,2);
 assert.ok(before.indexOf('lock.unlock()',before.indexOf('records.removeAll'))<before.indexOf('print(record)'));
 assert.match(source,/addTeardownBlock \{ buffer.flushAfterTest\(\) \}/);
});
test('bounded lock-protected test-local recorder has no task or actor hop',()=>{
 const buffer=source.slice(source.indexOf('private final class RuntimeTraceBuffer'),source.indexOf('private actor RuntimeIO'));
 assert.match(buffer,/capacity = 512/);assert.match(buffer,/message.prefix\(2048\)/);
 assert.match(buffer,/guard !closed else \{ return \}/);assert.match(buffer,/dropped \+= 1/);
 assert.match(buffer,/late_events=uncaptured_after_teardown/);
 assert.doesNotMatch(buffer,/Task\s*[.{(]|DispatchQueue|async |static var/);
});
test('every RuntimeIO is constructed by test-owned factory, including default installed path',()=>{
 assert.equal((source.match(/RuntimeIO\(/g)||[]).length,1);
 assert.match(source,/return RuntimeIO\(data, holdRead: holdRead, traceBuffer: traceBuffer\)/);
 assert.match(source,/let io = suppliedIO \?\? makeIO\(\)/);
 assert.equal((source.match(/func test\w+/g)||[]).length,17);
 assert.match(source,/makeIO\(bytes,holdRead:true\)/);
});
test('original fulfillment condition and three-second bound remain unchanged',()=>{
 assert.match(source,/await fulfillment\(of: \[done\], timeout: 3\)/);
 const callback=source.slice(source.indexOf('runtime.onChange = {'),source.indexOf('defer { runtime.onChange'));
 assert.match(callback,/guard !completed, condition\(\) else \{ return \}/);
 assert.match(callback,/completed = true; done.fulfill\(\)/);
 assert.doesNotMatch(callback,/print|Task\s*[.{(]|sleep/);
 assert.ok(callback.indexOf('done.fulfill()')<callback.indexOf('traceBuffer.record('));
});
test('extractor retains buffer drop and late-event marker',async()=>{
 const text=await readFile(new URL('tools/ci/extract-native-unit-failures.py',root),'utf8');
 assert.match(text,/IO\|WAIT\|PHASE\|TRACE/);
});
