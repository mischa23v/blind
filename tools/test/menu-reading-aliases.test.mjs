// Source routing contracts, not execution of SwiftUI, ARKit, Vision or audio.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read = path => readFileSync(new URL('../../'+path, import.meta.url), 'utf8');
const nav = read('ios/BlindAssist/NavigationModel.swift');
const section = (source, start, end) => source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));
test('explicit menu parser is raw and separate from permissive legacy normalization', () => {
 const parser=read('BlindCore/Sources/BlindCore/ReadingTools.swift');
 assert.ok(parser.indexOf('if matchesMenuRequest(raw)') < parser.indexOf('let text = normalized(raw)'));
 const matcher=section(parser,'private static func matchesMenuRequest(', 'public static func parse(');
 assert.match(matcher, /read the menu/);
 assert.match(matcher, /اقرا قائمه الطعام/);
 assert.doesNotMatch(matcher, /normalized\(raw\)|\.punctuationCharacters/);
});
test('trusted UI dispatch reaches existing document adapter only after authority and review interception', () => {
 const ingress=section(nav,'func receiveCompanionUtterance(', 'private func receiveUnverifiedConversation(');
 const authority=ingress.indexOf('guard CommandAuthority.permits(.changeGoal, from: origin)');
 const route=ingress.indexOf('if routeEverydayTask(text)');
 assert.ok(authority>=0 && route>authority);
 assert.ok(ingress.indexOf('routeCapturedTextReview(text, origin: origin)')<ingress.indexOf('if capturedText.source != nil { stopReadingTool(announce: false) }'));
 assert.ok(ingress.indexOf('if capturedText.source != nil { stopReadingTool(announce: false) }')<route);
 const everyday=read('BlindCore/Sources/BlindCore/EverydayTaskCoordinator.swift');
 assert.match(everyday,/if case \.start\(let tool\) = ReadingToolCommand.parse\(text\)/);
 assert.match(everyday,/case \.document: capability = \.readDocument/);
 const routeBody=section(nav,'private func routeEverydayTask(', 'private func finishEverydayTask(');
 assert.match(routeBody,/if !everydayTasks.begin\(request\)/);
 assert.match(routeBody,/everydayTasks.pause\(\); everydayTasks.resume\(\)/);
 assert.match(routeBody,/case \.readDocument: startReadingTool\(\.document\); return true/);
});
test('document aliases retain captured OCR and private historical review rather than a semantic menu lane', () => {
 assert.match(nav,/private var usesCapturedText: Bool \{ readingTool == \.liveText \|\| readingTool == \.document \}/);
 const start=section(nav,'func startReadingTool(', 'func stopReadingTool(');
 assert.match(start,/capturedTextCameraAllowed\(\)/);
 assert.match(start,/Reading captured page text, not movement guidance/);
 const capture=section(nav,'private func updateCapturedText(', 'private struct ReadingCapture');
 assert.match(capture,/VisionService.capturedTextLines/);
 assert.match(capture,/Uncertain text in captured view only/);
 assert.match(capture,/\.historicalMemory/);
 assert.match(capture,/self.finishEverydayTask\(tool == \.document \? \.readDocument : \.readText, outcome: \.informationReady/);
 const review=section(nav,'private func routeCapturedTextReview(', 'private func updateCapturedText(');
 assert.match(review,/CommandAuthority.permits\(\.changeGoal, from: origin\)/);
 assert.match(review,/guard capturedTextPlaybackAllowed\(\)/);
 const permission=section(nav,'private func capturedTextPlaybackAllowed(', 'private func cancelCapturedTextBudgetWake(');
 assert.match(permission,/!assistantSession.privateAudioHeld/);
 assert.match(review,/capturedText.review\(/);
});
