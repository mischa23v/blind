// Source contracts, not a native VoiceOver or RoomPlan runtime acceptance test.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const read = file => readFile(new URL(`../../${file}`, import.meta.url), 'utf8');
const slice = (source, from, to) => source.slice(source.indexOf(from), source.indexOf(to, source.indexOf(from) + from.length));

test('child home is one settled reply with no streaming observer or control tree', async () => {
  const view = await read('ios/BlindAssist/DashboardView.swift');
  const home = slice(view, 'private struct CompanionHomeView', 'private struct CompanionControlsView');
  assert.equal((home.match(/Text\(/g) ?? []).length, 1);
  assert.match(home, /model.currentReply/);
  assert.doesNotMatch(home, /sceneAnswer|homePrompt|Button\(|Toggle\(|TextField\(|NavigationLink|accessibilityActions|onChange|announcement/);
  assert.match(home, /toolbar\(\.hidden, for: \.navigationBar\)/);
  assert.doesNotMatch(view, /toolbar\(\.hidden, for: \.tabBar\)/);
  const settings = slice(view, 'private var settings:', 'private var settingsDetails:');
  assert.ok((settings.match(/NavigationLink/g) ?? []).length <= 4);
  assert.match(settings, /CompanionControlsView\(model: model\)/);
  assert.match(settings, /frame\(minHeight: 44\)/);
});

test('Rooms has saved names and explicit real scan controls instead of advanced map administration', async () => {
  const view = await read('ios/BlindAssist/DashboardView.swift');
  const rooms = slice(view, 'private var places:', 'private func scanSummary');
  assert.match(rooms, /NavigationLink\(place.name\)/);
  for (const id of ['room-scan-start', 'room-scan-stop', 'room-scan-cancel', 'room-scan-progress']) assert.ok(rooms.includes(id), id);
  assert.match(rooms, /model.places.finishScan\(\)/);
  assert.match(rooms, /model.places.cancelScanAndResume\(\)/);
  assert.match(rooms, /model.places.liveScanLayout/);
  assert.match(rooms, /FloorPlanPreview\(layout: layout\)/);
  assert.match(rooms, /accessibilityHidden\(true\)/);
  assert.match(rooms, /Text\(scanSummary\(layout\)\)/);
  assert.match(rooms, /confirmationDialog/);
  assert.doesNotMatch(rooms, /CommunityMapsView|journeys|model.mapping|ProgressView\(value:|percent|percentage/i);
});

test('live scan map comes from current RoomPlan observations and cannot replace saved rooms', async () => {
  const store = await read('ios/BlindAssist/PlaceStore.swift');
  const update = slice(store, 'func captureSession(_ session: RoomCaptureSession, didUpdate room:', 'func worldMap(');
  assert.match(update, /Thread.isMainThread/);
  assert.match(update, /capture === session, scanning, !finishing/);
  assert.match(update, /RoomLayoutAdapter.layout\(room, name: name\)/);
  assert.match(update, /layout.validate\(\)/);
  assert.match(update, /liveScanLayout = layout/);
  assert.doesNotMatch(update, /places.insert|\.write\(|saveLayout|onMessage/);
  const cancel = slice(store, 'func cancelScan()', 'func worldMap(');
  assert.match(cancel, /liveScanLayout = nil/);
  assert.match(cancel, /func cancelScanAndResume\(\)[\s\S]*cancelScan\(\)[\s\S]*onScanFinished\?\(\)/);
});

test('People landing is names and Add person while the existing consent workflow remains intact', async () => {
  const view = await read('ios/BlindAssist/FamiliarPeopleView.swift');
  const landing = slice(view, 'struct FamiliarPeopleView:', 'private struct FamiliarPeopleToolsView:');
  assert.match(landing, /NavigationLink\(person.label\)/);
  assert.match(landing, /familiar-add-person/);
  assert.doesNotMatch(landing, /cosineThreshold|minimumMargin|dualPipeline|Toggle\(/);
  assert.match(view, /experiment.requestEnable\(\)/);
  assert.match(view, /experiment.requestUnnamedEnrollment\(\)/);
  assert.match(view, /experiment.draftExamples.count >= 3/);
  assert.match(view, /experiment.setDraftLabel\(label\)/);
  assert.match(view, /experiment.confirm\(\)/);
  assert.match(view, /experiment.finishEnrollment\(\)/);
  assert.match(view, /Helper setup and full limitations/);
  assert.match(view, /Child enrollment is unavailable/);
});

 test('face camera entry explicitly enables sensing and does not wait forever after denial',async()=>{
  const view=await read('ios/BlindAssist/FamiliarPeopleView.swift');
  assert.match(view,/Turn on camera and take photos/);
  assert.match(view,/if !model.cameraAwareness \{ model.cameraAwareness = true \} else \{ model.start\(\) \}/);
  assert.match(view,/authorizationStatus\(for: \.video\) == \.denied/);
  assert.match(view,/awaitingCameraForEnrollment = false/);
  assert.match(view,/guard model.supported, !model.textOnly/);
 });
