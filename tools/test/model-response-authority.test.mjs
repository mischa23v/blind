// Source contracts + exact JavaScript guard execution only. Native XCTest,
// Foundation Models and AVFoundation are separate acceptance stages.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { containsSpatialClaim, normalizeArabic } from '../../server/src/spatial-guard.mjs';

const read = p => readFile(new URL('../../' + p, import.meta.url), 'utf8');
const [nav, feedback, adapter, authority, domain, swiftGuard, mirror, route, controller, fixtureText] = await Promise.all([
  'ios/BlindAssist/NavigationModel.swift', 'ios/BlindAssist/Feedback.swift', 'ios/BlindAssist/LocalImageAssistant.swift',
  'BlindCore/Sources/BlindCore/ModelResponseAuthority.swift', 'BlindCore/Sources/BlindCore/ConversationDomainPolicy.swift',
  'BlindCore/Sources/BlindCore/SpatialClaimGuard.swift', 'server/src/spatial-guard.mjs',
  'BlindCore/Sources/BlindCore/SpatialRouteOwner.swift', 'ios/BlindAssist/SpatialRouteOutputController.swift',
  'BlindCore/Tests/BlindCoreTests/Fixtures/spatial-claims.json'
].map(read));

test('shared bilingual output fixtures remain blocked/allowed without weakening expectations', () => {
  const f = JSON.parse(fixtureText);
  for (const text of f.blocked) assert.equal(containsSpatialClaim(text), true, text);
  for (const text of f.allowed) assert.equal(containsSpatialClaim(text), false, text);
  for (const text of ['Continue straight.', 'Continue straight through the doorway.', 'Head straight.',
    'Sidestep twice.', 'كمل على طول.', 'واصل على طول.']) assert.ok(f.blocked.includes(text));
});

test('new continuation expression is exactly shared by Swift and JavaScript', () => {
  const a = swiftGuard.match(/private static let continuation = regex\(#"(.*?)"#\)/s)?.[1];
  const b = mirror.match(/const CONTINUATION = \/(.*?)\/i;/s)?.[1];
  assert.ok(a); assert.equal(a, b);
});

test('new request expressions catch concrete locomotion without banning story/appliance continuation', () => {
  const block = domain.split('// A continuation toward')[1].split('// Local object/person')[0];
  const expressions = [...block.matchAll(/has\(#"(.*?)"#\)/gs)].map(m => new RegExp(m[1], 'u'));
  assert.equal(expressions.length, 2);
  const normalize = text => normalizeArabic(text.toLowerCase()).replace(/ى/g, 'ي').replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
  for (const text of ['How do I continue to the kitchen?', 'كيف أكمل للمطبخ؟', 'كيف أواصل للمطبخ؟']) {
    assert.ok(expressions.some(re => re.test(normalize(text))), text);
  }
  for (const text of ['How do I continue my story?', 'كيف أكمل قصتي؟', 'How do I continue the dishwasher program?']) {
    assert.ok(expressions.every(re => !re.test(normalize(text))), text);
  }
});

test('model leases retain private creation, physical ownership and exact binding/text/deadline', () => {
  assert.match(authority, /fileprivate init\(binding:/);
  assert.match(authority, /request\.owner == \.conversation/);
  for (const term of ['request.id == lease.ownerID', 'lease.binding == binding', 'now < lease.expiresAt',
    'lease.text.utf8.elementsEqual(text.utf8)']) assert.ok(authority.includes(term), term);
  assert.doesNotMatch(authority, /SpatialRouteTicket|isNavigationReady|geometryReady/);
  assert.match(authority, /request\.producer == producer/);
  assert.match(authority, /let originalStart = min\(createdAt, request\.startedAt\)/);
  assert.match(authority, /expiresAt: originalStart \+ lifetime\(producer\)/);
});

test('ordinary interruptions retire model ownership without changing sensor identities or a scene owner', () => {
  assert.match(authority, /func invalidateConversation\(\) \{\s*if request\?\.producer == \.conversation \{ request = nil \}/);
  const interrupt = nav.split('private func interruptOrdinaryConversation(')[1].split('private func unverifiedConversationReply')[0];
  assert.match(interrupt, /modelResponseAuthority\.invalidateConversation\(\)/);
  assert.match(interrupt, /feedback\.revalidateModelReply\(\)/);
  assert.doesNotMatch(interrupt, /requestID =|assistantSession\./);
});

test('camera-independent playback expiry is model-deadline and delivery-attempt owned', () => {
  assert.match(feedback, /max\(0, min\(120, modelReply\.expiresAt - now\)\)/);
  assert.match(feedback, /armOutputTimeout\(token: attempt\.token, modelReply: modelReply\)/);
  const timeout = feedback.split('private func armOutputTimeout(')[1].split('func interruptAmbient')[0];
  assert.match(timeout, /self\.delivery\.active\?\.token == token/);
  assert.match(timeout, /model\.originalDeadlineExpired/);
});

test('model producer cannot choose codeOwned Boolean and both model paths attach the typed lease', () => {
  const signature = nav.split('private func queueConversationSpeech(')[1].split('{')[0];
  assert.doesNotMatch(signature, /codeOwned/);
  assert.match(nav, /enqueueConversationSpeech\(\.model\(lease\)/);
  assert.match(nav, /self\.deliverCandidate\(candidate, narrationID: currentRequest, modelReply: modelReply\)/);
  assert.match(nav, /beginModelResponse\(question: question\)/);
  assert.match(nav, /modelResponseAuthority\.begin\(question: question, binding: modelResponseBinding, producer: producer, at: modelResponseNow\)/);
  assert.match(nav, /if let modelReply \{\s*guard candidate.kind == \.answer \|\| candidate.kind == \.discovery,/);
});

test('Feedback enforces model owner before dispatch, before platform queue, at start and while active', () => {
  assert.match(feedback, /modelReplyPermission\?\(lease, text\) == true/);
  assert.equal([...feedback.matchAll(/modelReplyIsCurrent\(/g)].length, 5); // declaration + four boundaries
  assert.match(feedback, /spatialRouteID == nil, alert == nil, !independentAlert/);
  const prepared = feedback.split('let utterance = AVSpeechUtterance')[1].split('private func reserveUrgentOutput')[0];
  assert.ok(prepared.indexOf('modelReplyIsCurrent') < prepared.indexOf('speech.speak(utterance)'));
  assert.ok(prepared.indexOf('modelReplyIsCurrent') < prepared.indexOf('debugModelTestQueued.append'));
  assert.match(nav, /feedback\.modelReplyPermission =/);
  assert.match(nav, /feedback\.revalidateModelReply\(\)/);
});

test('display receives the same evidence before it can render model text', () => {
  assert.match(nav, /showModelConversationReply\(displayed, settled: false, reports: reports, evidence: evidence\)/);
  assert.match(nav, /showModelConversationReply\(text, settled: true, reports: self\.latestModelReports, evidence: self\.latestModelEvidence\)/);
  for (const text of ['chunk', 'suffix', 'fallback']) {
    const first = adapter.indexOf('await onSpeechCandidate?(' + text + ', reports, evidence)');
    assert.ok(first >= 0);
    assert.ok(first < adapter.indexOf('await onPartial?(' + text + ')', first));
  }
});

test('scene admission keeps capture-time deadline and revalidates capture before model playback', () => {
  assert.match(nav, /producer: \.sceneDescription,[\s\S]*?createdAt: capturedAt, now: now/);
  assert.match(nav, /capture\.id == lease\.id/);
  assert.match(nav.split('private func modelReplyAllowed')[1].split('private func retainedModelReply')[0], /SceneDelivery\.allowed/);
});

test('repeat cannot remint a model lease or launder old navigation wording as history', () => {
  const live = nav.split('func speakRequested(')[1].split('// Prefer the ORIGINAL')[0];
  assert.match(live, /suppliedReply \?\? \(speechID == nil && narrationID == nil \? retainedModelReply/);
  assert.match(live, /enqueueConversationSpeech\(\.model\(modelReply\)/);
  assert.doesNotMatch(live, /\.admit\(/);
  const history = nav.split('func repeatDescription()')[1].split('// Developer comparison builds')[0];
  assert.match(history, /retainedNarrationModelReply\(for: original\)/);
  assert.match(history, /guard !SpatialClaimGuard\.containsSpatialClaim\(original\)/);
});

test('route speech is code rendered and borrowed model text fails exact sink validation', () => {
  const speech = route.split('public struct SpatialRouteSpeech')[1].split('public enum SpatialRouteError')[0];
  assert.match(speech, /init\?\(ticket: SpatialRouteTicket, arabic: Bool\)/);
  assert.doesNotMatch(speech, /init[^\n]*text:/);
  assert.doesNotMatch(speech, /target\.name|localizedName/);
  assert.match(speech, /Next waypoint, approximately/);
  assert.match(speech, /نقطة المسار التالية/);
  assert.match(controller, /speech\(attempt\.id, message\.text\)/);
  assert.match(controller, /active\.message\.text\.utf8\.elementsEqual\(text\.utf8\)/);
  assert.match(nav, /SpatialRouteSpeech\(ticket: ticket, arabic: arabic\)/);
  assert.match(nav, /validateSpeechStart\(spatialRouteID, text: candidate\.text\)/);
  assert.match(feedback, /spatialRouteSpeechPermission\?\(spatialRouteID, admitted\.text\)/);
  assert.match(feedback, /spatialRouteSpeechPermission\?\(routeID, active\.text\)/);
});


test('current model displays retire as explicit history only while their exact revisions remain owned', () => {
  const retire = nav.split('private func revalidateModelDisplays()')[1].split('private func armModelDisplayExpiry')[0];
  assert.match(retire, /display\.revision != sceneAnswerRevision/);
  assert.match(retire, /display\.revision != currentReplyRevision/);
  assert.match(retire, /sceneAnswer = modelHistoryLabel\(display\.lease\)/);
  assert.match(retire, /currentReply = modelHistoryLabel\(display\.lease\)/);
  assert.match(retire, /historical: true/);
  const retained = nav.split('private func retainedModelReply')[1].split('private func modelHistoryLabel')[0];
  assert.match(retained, /display\.text\.utf8\.elementsEqual\(text\.utf8\) \|\| display\.lease\.text\.utf8\.elementsEqual\(text\.utf8\)/);
});

test('display expiry is camera independent, timer owned, and wired to cancellation and replacement', () => {
  const timer = nav.split('private func armModelDisplayExpiry()')[1].split('#if DEBUG')[0];
  assert.match(timer, /modelDisplayTimerOwner == owner/);
  assert.match(timer, /deadline - modelResponseNow/);
  assert.match(timer, /revalidateModelDisplays\(\)/);
  for (const name of ['cancelDescription', 'interruptOrdinaryConversation', 'beginModelResponse']) {
    const method = nav.split('private func ' + name + '(')[1].split('\n    }')[0];
    assert.match(method, /revalidateModelDisplays\(\)/, name);
  }
});

test('native controller fixture reaches real queue and sink with an XCTest-only silent platform boundary', () => {
  const seam = nav.split('func debugBeginModelResponseTest')[1].split('private struct ConversationSpeech')[0];
  assert.match(seam, /guard textOnly, ProcessInfo\.processInfo\.environment\["XCTestConfigurationFilePath"\] != nil/);
  assert.match(seam, /feedback\.debugEnableSilentModelTestTransport\(\)/);
  assert.match(seam, /showModelConversationReply\(text/);
  assert.match(seam, /queueModelConversationSpeech\(text/);
  assert.match(nav, /guard \(!textOnly \|\| silentModelTestDelivery\), assistantSession\.state == \.active/);
  assert.match(feedback, /speechSynthesizer\(speech, didStart: utterance\)/);
  assert.match(feedback, /if debugSilentModelTestTransport \{\s*debugModelTestQueued\.append\(attempt\.text\)\s*return true/);
  assert.match(feedback, /test\.injectedDidStart\.silent/);
});
