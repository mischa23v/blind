// Source/wiring checks plus executable project graph generation, not Apple playback.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { generateProject } from '../generate-xcode-project.mjs';
const read = name => readFileSync(new URL(`../../ios/BlindAssist/${name}.swift`, import.meta.url), 'utf8');
const section = (text, start, end) => text.slice(text.indexOf(start), text.indexOf(end, text.indexOf(start)));
test('registered route files and hosted fixtures are actual source-phase members', () => {
  const project = generateProject(['RegisteredIndoorNavigation.swift', 'SpatialRouteOutputController.swift', 'SpatialMapIO.swift']);
  const objects = new Map([...project.matchAll(/^([A-F0-9]{24}) = \{ (.*) \};$/gm)].map(x => [x[1], x[2]]));
  for (const file of ['BlindAssist/RegisteredIndoorNavigation.swift', 'BlindAssist/SpatialRouteOutputController.swift', 'BlindAssist/SpatialMapIO.swift',
    'BlindAssistTests/SpatialIntegrationFixture.swift', 'BlindAssistTests/RegisteredIndoorNavigationTests.swift',
    'BlindAssistTests/SpatialRouteOutputControllerTests.swift', 'BlindAssistTests/SpatialMapIOTests.swift',
    'BlindAssistTests/IndoorNavigatorAsyncTests.swift']) {
    const ref = [...objects].find(([,body]) => body.includes(`path = "${file}";`))?.[0];
    assert.ok(ref, file);
    const build = [...objects].find(([,body]) => body.includes(`fileRef = ${ref};`))?.[0];
    assert.ok(build, `${file} build membership`);
    assert.equal([...objects.values()].filter(body => body.includes('isa = PBXSourcesBuildPhase;') && body.includes(build)).length, 1);
    assert.ok([...objects.values()].some(body => body.includes('isa = PBXGroup;') && body.includes(ref)));
  }
});
test('registered route dispatch retains ticket, exact output IDs and final playback gate', () => {
  const model = read('NavigationModel'), feedback = read('Feedback');
  const owner = section(model, 'func indoorBeacon(', '/// No mode selection:');
  assert.match(owner, /if connectedJourneyOwnsNavigation \{ connectedJourneyBeacon\(automatic: automatic\); return \}/);
  assert.doesNotMatch(owner, /indoor\.next\(|spatialRouteOutput\.deliver/);
  const route = section(model, 'private func connectedJourneyBeacon(', 'func stopReturn()');
  assert.match(route, /spatialRouteOutput\.deliver\(ticket: ticket, goalRevision: revision/);
  assert.match(route, /speechID: id, spatialRouteID: id/);
  assert.match(route, /feedback\.spatialRouteBeacon\([\s\S]*id: id/);
  assert.doesNotMatch(route, /speakMobility\(|feedback\.beacon\(/);
  const start = section(feedback, 'func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart', 'func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish');
  assert.match(start, /utterance === currentUtterance/);
  assert.match(start, /spatialRoutePermission\?\(routeID\) != true/);
  const stop = section(feedback, 'func stopSpatialRouteSpeech(', '@discardableResult func stopInformation(');
  assert.match(stop, /currentSpatialRouteID == id/);
  assert.match(stop, /active\.destination == \.requested\(id\), !active\.independentAlert/);
  assert.doesNotMatch(stop, /stopInformation\(|player\.stop/);
});
test('route watchdog, goal controls and JSON importer preserve independent ownership', () => {
  const model = read('NavigationModel'), indoor = read('IndoorNavigator'), ui = read('DashboardView');
  const watchdog = section(model, 'private func startWatchdog()', 'func session(_ session: ARSession, didUpdate frame:');
  assert.ok(watchdog.indexOf('spatialRouteOutput.revalidate()') < watchdog.indexOf('guard self.running'));
  assert.match(watchdog, /RunLoop\.main\.add\(watchdog, forMode: \.common\)/);
  for (const start of ['func setAssistantObjective()', 'func clearAssistantConversation()']) {
    const body = model.slice(model.indexOf(start), model.indexOf('\n    }', model.indexOf(start)));
    assert.match(body, /indoor\.cancelRoute\(\)/);
    assert.doesNotMatch(body, /feedback\.stop\(|indoor\.invalidatePosition\(|detector\.reset\(/);
  }
  assert.match(ui, /model\.planIndoor\(from:/);
  assert.match(ui, /model\.indoor\.importMapFile\(url\)/);
  const importer = section(ui, '.fileImporter(isPresented: $importing', '/// Settings, most-used');
  assert.doesNotMatch(importer, /Data\(contentsOf:|resourceValues\(/);
  const io = read('SpatialMapIO');
  assert.match(io, /guard size <= UInt64\(maximumBytes\)/);
  assert.match(io, /read\(upToCount: count\)/);
  assert.match(io, /guard bytes\.count <= maximumBytes/);

  assert.match(indoor, /if let caption = self\.registeredCueCaption, self\.message == caption/);
  assert.match(indoor, /registered\.install\(data, completion: \$0\)/);
  const adapter = read('RegisteredIndoorNavigation');
  assert.match(adapter, /object\["mapBytes"\] != nil \|\| object\["snapshot"\] != nil/);
  const remove = section(indoor, 'func removeKeepOutZone(', 'func blockNextLeg(');
  assert.match(remove, /guard !mapIOPending, let registered, !registered\.ioBlocked,\s*registered\.installation == nil/);
  assert.match(remove, /completion\(\.failure\(SpatialInstallationError\.historyRewrite\)\)/);
});
