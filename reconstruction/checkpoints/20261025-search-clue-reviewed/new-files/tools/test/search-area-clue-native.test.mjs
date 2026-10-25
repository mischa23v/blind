// Exact production ingress/response adapters with platform service boundaries.
// Not an Apple SDK, real-model, actual audio, camera or participant result.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const read = path => readFileSync(join(root, path), 'utf8');
function declaration(source, signature) {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, signature);
  // A default callback (for example forgetItem's completion) may itself
  // contain braces before the actual function body. Skip parameter nesting.
  let parens = 0, brace = -1;
  for (let i = start; i < source.length; i++) {
    if (source[i] === '(') parens++;
    if (source[i] === ')') parens--;
    if (source[i] === '{' && parens === 0) { brace = i; break; }
  }
  assert.ok(brace >= 0, `Missing body: ${signature}`);
  let depth = 0;
  for (let i = brace; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}') { depth--; if (!depth) return source.slice(start, i + 1); }
  }
  throw new Error(`Unclosed ${signature}`);
}
// Strip unavailable compile configurations, not runtime behavior.
function release(source) {
  const stack = []; let live = true;
  return source.split('\n').filter(line => {
    if (/^\s*#if /.test(line)) { stack.push(live); live = false; return false; }
    if (/^\s*#else/.test(line)) { live = stack.at(-1) && !live; return false; }
    if (/^\s*#endif/.test(line)) { live = stack.pop(); return false; }
    return live;
  }).join('\n');
}

test('search area ownership is wired to actual code reply and exact speech completion', () => {
  const nav = read('ios/BlindAssist/NavigationModel.swift');
  assert.match(declaration(nav, 'private func cancelDescription('), /companionWorkingState\.searchAreaClue\.retireAnswerWindow\(\)/);
  for (const lifecycle of ['func startConversation(', 'func muteConversation(', 'func endConversation(']) {
    assert.match(declaration(nav, lifecycle), /companionWorkingState\.searchAreaClue\.clear\(\)/);
  }
  const finished = declaration(nav, 'feedback.onRequestedSpeechFinished =');
  assert.match(finished, /finishSearchAreaQuestion\(pending\.searchAreaQuestionID, text: text, outcome: outcome/);
  const apply = declaration(nav, 'private func applyCompanion(');
  assert.ok(apply.indexOf('findWithSensors(') < apply.indexOf('searchAreaClue.prepare('));
  assert.match(apply, /searchAreaClarificationTarget/);
  const receive = declaration(nav, 'func receiveCompanionUtterance(');
  for (const route of ['handleConversationTaskControl(', 'routeEverydayTask(', 'CompanionUtterance.parse(text)', 'handleItemOrLocate(']) {
    assert.ok(receive.indexOf(route) < receive.indexOf('acceptSearchAreaClue('), route);
  }
  assert.match(receive, /CommandAuthority\.permits\(\.changeGoal, from: origin\)[\s\S]*\? companionWorkingState.searchAreaClue : nil/);
  const deliver = declaration(nav, 'private func deliverConversationReply(');
  assert.match(deliver, /if textOnly, let id = searchAreaQuestionID/);
  assert.match(deliver, /presentTrustedText/);
  // Saved-place deletion is a source-adapter contract here; its actual native
  // persistence workflow is not extracted by this replay.
  const deletePlace = declaration(nav, 'func deletePlace(');
  const placeRetirement = 'companionWorkingState.retireSearchClue(placeID: place.id.uuidString)';
  assert.ok(deletePlace.includes(placeRetirement));
  assert.ok(deletePlace.indexOf(placeRetirement) < deletePlace.indexOf('nativeObservations.clearHistory('));
  assert.doesNotMatch(declaration(nav, 'private func deletePlaceAfterNativePurge('), /retireSearchClue/);
  const local = read('ios/BlindAssist/LocalImageAssistant.swift');
  const keys = local.match(/private enum CodingKeys: String, CodingKey \{ case memoryScope[^\n]+/)[0];
  assert.doesNotMatch(keys, /searchAreaClue|searchAreaClarificationTarget/);
});

test('exact native ingress and reply adapters retain provisional user clues without model fallback', {
  skip: !process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC to run extracted production controller replay.', timeout: 240_000,
}, () => {
  // Explicit opt-in baseline path supports preserved before-regression evidence.
  // The normal repository aggregate always tests the current source.
  const inputRoot = process.env.BLIND_SEARCH_CLUE_BASELINE_ROOT || root;
  const nav = readFileSync(join(inputRoot, 'ios/BlindAssist/NavigationModel.swift'), 'utf8');
  const local = readFileSync(join(inputRoot, 'ios/BlindAssist/LocalImageAssistant.swift'), 'utf8');
  const current = nav.includes('private func acceptSearchAreaClue(');
  const work = process.env.BLIND_SEARCH_CLUE_REPLAY_WORK || mkdtempSync(join(process.env.BLIND_TEST_SCRATCH || tmpdir(), 'blind-search-clue-'));
  const sources = join(work, 'Sources/SearchAreaReplay'), tests = join(work, 'Tests/SearchAreaReplayTests');
  mkdirSync(sources, {recursive:true}); mkdirSync(tests, {recursive:true}); mkdirSync(join(work, 'home'), {recursive:true});
  const stateStart = local.indexOf('/// App-owned state:'), stateEnd = local.indexOf('#if canImport(FoundationModels)', stateStart);
  assert.ok(stateStart >= 0 && stateEnd > stateStart);
  writeFileSync(join(sources, 'WorkingState.swift'), 'import Foundation\nimport BlindCore\n' + local.slice(stateStart, stateEnd));
  const signatures = ['func receiveCompanionUtterance(', 'private func recordCompanionMessage(',
    'private func answerCompanionUtterance(', 'private func applyCompanion(', 'private func deliverConversationReply(',
    'private func routeUnverifiedPhysicalRequest(', 'private func handleConversationTaskControl(',
    'private func handleItemOrLocate(', 'func forgetItem(', 'private func forgetItemAfterNativePurge(',
    'private func retireHeldSearchForPrivacyDeletion(', 'func clearAssistantConversation(',
    'func stopDescriptions(', 'func resumeDescriptions(', 'private func handleAssistantControl('];
  if (current) signatures.push('private func searchAreaBinding(', 'private func finishSearchAreaQuestion(', 'private func acceptSearchAreaClue(');
  const methods = signatures.map(s => release(declaration(nav, s)).replace(/^private func/, 'func'));
  const retirement = declaration(nav, 'private func cancelDescription(').split('\n').filter(line => /companionWorkingState\.searchAreaClue\.(clear|retireAnswerWindow)\(\)/.test(line));
  assert.equal(retirement.length, current ? 1 : 0);
  const cancel = `func cancelDescription() { ${retirement.join('\n')}\n pendingSpeech = nil; requestID = UUID() }`;
  writeFileSync(join(sources, 'Controller.swift'), read('tools/test/fixtures/search-area-clue/ReplayPrefix.swift') + '\n' + cancel + '\n' + methods.join('\n\n') + '\n}\n');
  writeFileSync(join(tests, 'CommonTests.swift'), read('tools/test/fixtures/search-area-clue/CommonTests.swift'));
  if (current) {
    writeFileSync(join(tests, 'CurrentTests.swift'), read('tools/test/fixtures/search-area-clue/CurrentTests.swift'));
    writeFileSync(join(tests, 'PrivacyTests.swift'), read('tools/test/fixtures/search-area-clue/PrivacyTests.swift'));
  }
  writeFileSync(join(work, 'Package.swift'), `// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(name: "SearchAreaReplay", dependencies: [.package(path: ${JSON.stringify(join(inputRoot,'BlindCore'))})], targets: [.target(name: "SearchAreaReplay", dependencies: [.product(name: "BlindCore", package: "BlindCore")]), .testTarget(name: "SearchAreaReplayTests", dependencies: ["SearchAreaReplay", .product(name: "BlindCore", package: "BlindCore")])])\n`);
  const result = spawnSync(join(dirname(process.env.BLIND_SWIFTC), 'swift'), ['test', '--package-path', work, '--scratch-path', join(work,'build'), '--cache-path', join(work,'cache'), '--jobs', '1'], {
    encoding:'utf8', timeout:235_000, maxBuffer:8*1024*1024,
    env:{...process.env, HOME:join(work,'home'), XDG_CACHE_HOME:join(work,'cache'), SWIFTPM_MODULECACHE_OVERRIDE:join(work,'modules'), CLANG_MODULE_CACHE_PATH:join(work,'clang')},
  });
  const output = (result.stdout || '') + '\n' + (result.stderr || ''); writeFileSync(join(work,'execution.log'),output);
  assert.equal(result.status, 0, `Extracted controller replay retained at ${work}\n${output.slice(-18000)}`);
  assert.match(output, /Executed 29 tests, with 0 failures/);
});
