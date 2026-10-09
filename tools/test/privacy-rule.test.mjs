// Static guard for the permanent privacy rule (AGENTS.md): camera pictures never leave the phone
// in the app build, and public place packages carry no photos or personal memory.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';

const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');

test('the app build cannot send a camera picture off the phone', async () => {
  const model = await read('ios/BlindAssist/NavigationModel.swift');
  const start = model.indexOf('func readScene(');
  const gate = model.indexOf('#if !BLIND_DEVELOPER_CLOUD', start);
  const forced = model.indexOf('let cloud = false', gate);
  assert.ok(start > 0 && gate > start && forced > gate && forced - start < 400, 'readScene forces on-device answers unless the developer flag is set');
  // Every use of the picture-sending client sits inside a developer-only block.
  for (const file of (await readdir(new URL('../../ios/BlindAssist/', import.meta.url))).filter(name => name.endsWith('.swift') && name !== 'SceneQuestionClient.swift')) {
    const source = await read(`ios/BlindAssist/${file}`);
    let index = source.indexOf('SceneQuestionClient(');
    while (index >= 0) {
      const before = source.slice(0, index);
      assert.ok(before.lastIndexOf('#if BLIND_DEVELOPER_CLOUD') > before.lastIndexOf('#endif'), `${file}: SceneQuestionClient used outside a developer-only block`);
      index = source.indexOf('SceneQuestionClient(', index + 1);
    }
  }
  const project = await read('tools/generate-xcode-project.mjs');
  assert.doesNotMatch(project, /BLIND_DEVELOPER_CLOUD/, 'the generated app project never enables the developer cloud flag');
});

test('room memory and items stay in protected on-phone storage', async () => {
  const recall = await read('ios/BlindAssist/RoomRecall.swift');
  assert.doesNotMatch(recall, /URLSession|https?:\/\//, 'room memory makes no network calls');
  const store = await read('ios/BlindAssist/PlaceStore.swift');
  assert.match(store, /isExcludedFromBackup = true/);
  assert.match(store, /completeUntilFirstUserAuthentication/);
});

test('public place packages have no photo or personal-memory fields', async () => {
  const pkg = await read('BlindCore/Sources/BlindCore/PlacePackage.swift');
  assert.doesNotMatch(pkg, /photo|image|picture|thumbnail|featurePrint|RememberedItem|people/i);
});
