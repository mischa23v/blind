// Authored ownership/history fixtures, not localization or camera accuracy.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {tmpdir} from 'node:os';
import {spawnSync} from 'node:child_process';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const read=p=>readFileSync(join(root,p),'utf8');
function section(text,start,end){const a=text.indexOf(start);assert.ok(a>=0,start);const b=text.indexOf(end,a);assert.ok(b>a,end);return text.slice(a,b);}
function release(text){return text.replace(/^[ \t]*#if DEBUG\n[\s\S]*?^[ \t]*#endif\n/gm,'');}
test('all native find consumers honor current scope and historical routing precedes task mutations',()=>{
 const nav=read('ios/BlindAssist/NavigationModel.swift'),local=read('ios/BlindAssist/LocalImageAssistant.swift');
 const find=section(nav,'    private func handleItemOrLocate(','    /// Native RGB evidence');
 assert.doesNotMatch(find,/factBook\.latest\(|let recall = observedObjects\.recall/);
 assert.equal((find.match(/items\.find\(/g)||[]).length,1);assert.match(find,/case \.forget\(let name\):\s*guard let saved = items\.find\(name\)/);
 assert.match(find,/currentContextFact\(for: name\)/);assert.match(find,/currentContextItem\(name, in: items\)/);assert.match(find,/taskContextObservations\(observedObjects\)/);
 assert.match(find,/if item\.scope == nil, itemAppearance\.viewCount/);
 const receive=section(nav,'    func receiveCompanionUtterance(','    private func ');
 const history=receive.indexOf('routeHistoricalLocationInquiry(text, origin: origin)');assert.ok(history>receive.indexOf('guard CommandAuthority.permits(.changeGoal'));
 assert.ok(history<receive.indexOf('let pendingRetake'));assert.ok(history<receive.indexOf('routeEverydayTask('));
 const scene=section(nav,'    func readScene(','    private func ');assert.ok(scene.indexOf('routeHistoricalLocationInquiry')<scene.indexOf('routeUnverifiedPhysicalRequest'));
 const route=section(nav,'    /// Explicit past-location recall','    private func handleItemOrLocate(');
 assert.match(route,/Self.wordCount\(summary\) <= 30 \? summary : fallback/);assert.match(route,/message = history; sceneAnswer = history; currentReply = history/);
 assert.equal((route.match(/queueConversationSpeech\(/g)||[]).length,1);assert.doesNotMatch(route,/historicalSpeechParts|for part in/);
 assert.match(route,/request: requestID, generation: assistantSession\.generation, codeOwned: true/);
 assert.doesNotMatch(route,/changeGoal\(|beginFindGoal\(|locate\(|cancel\(|transitionMemoryScope\(/);
 assert.match(local,/guard !hasScopedMemoryHistory \|\| memoryScope != nil else \{ return nil \}/);
 assert.match(local,/factBook.latest\(for: object\).flatMap \{ \$0.scope == nil \? \$0 : nil \}/);
});
test('actual state, complete native lookup methods and historical entry execute scope regressions',{
 skip:!process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC for executable Swift replay.',timeout:240_000,
},()=>{
 const work=mkdtempSync(join(process.env.BLIND_TEST_SCRATCH||tmpdir(),'blind-scoped-lookup-'));
 const sourceDir=join(work,'Sources/NativeLookupReplay'),tests=join(work,'Tests/NativeLookupReplayTests');mkdirSync(sourceDir,{recursive:true});mkdirSync(tests,{recursive:true});
 const local=read('ios/BlindAssist/LocalImageAssistant.swift'),nav=read('ios/BlindAssist/NavigationModel.swift'),fixture='tools/test/fixtures/scoped-memory-lookup/';
 writeFileSync(join(sourceDir,'WorkingState.swift'),'import Foundation\nimport BlindCore\n'+section(local,'struct CompanionTaskUpdate:','\n#if canImport(FoundationModels)'));
 const helper=section(nav,'    /// Explicit past-location recall','    private func handleItemOrLocate(');
 for(const [name,end] of [['ExtractedAfterItemRecall','    /// Saved item (by look'],['ExtractedAfterFullItemRecall','    /// Native RGB evidence']]){
  writeFileSync(join(sourceDir,name+'.swift'),read(fixture+name+'Prefix.swift')+helper+section(nav,'    private func handleItemOrLocate(',end)+'\n}\n');
 }
 const ingress=section(nav,'    func receiveCompanionUtterance(','        if routeHistoricalLocationInquiry(text, origin: origin) { return }')+'        if routeHistoricalLocationInquiry(text, origin: origin) { return }\n';
 // Extract only the native turn bookkeeping declarations actually referenced by
 // this ingress revision. Narrow-only source has neither field; broad review does.
 const turnFields=['recordingCompanionTurn','recordedCompanionSourceID'].map(name=>{
  const fields=nav.split('\n').filter(line=>line.trim().startsWith('private var '+name+' ') || line.trim().startsWith('private var '+name+':'));
  assert.ok(fields.length<=1,name);
  if(ingress.includes(name)) assert.equal(fields.length,1,`Missing native ingress field: ${name}`);
  return fields.length ? fields[0]+'\n' : '';
 }).join('');
 writeFileSync(join(sourceDir,'Ingress.swift'),read(fixture+'ExtractedHistoricalIngressPrefix.swift')+turnFields+helper+release(ingress)+' taskCalls += 1\n }\n}\n');
 for(const file of ['NativeContextRecallAfterTests.swift','NativeSensorScopeAfterTests.swift','NativeHistoricalRecallTests.swift','MixedStoreHistoryTests.swift'])writeFileSync(join(tests,file),read(fixture+file));
 writeFileSync(join(work,'Package.swift'),`// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(name: "NativeLookupReplay", dependencies: [.package(path: ${JSON.stringify(join(root,'BlindCore'))})], targets: [.target(name: "NativeLookupReplay", dependencies: [.product(name: "BlindCore", package: "BlindCore")]), .testTarget(name: "NativeLookupReplayTests", dependencies: ["NativeLookupReplay", .product(name: "BlindCore", package: "BlindCore")])])\n`);
 const result=spawnSync(join(dirname(process.env.BLIND_SWIFTC),'swift'),['test','--package-path',work,'--jobs','2'],{encoding:'utf8',timeout:235_000,maxBuffer:8*1024*1024});
 const output=(result.stdout||'')+'\n'+(result.stderr||'');writeFileSync(join(work,'execution.log'),output);assert.equal(result.status,0,`Replay retained at ${work}\n${output.slice(-12000)}`);assert.match(output,/Executed 15 tests, with 0 failures/);
});
