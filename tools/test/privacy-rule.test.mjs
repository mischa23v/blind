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

// Walks every source file (including FamiliarNative/ and CurrencyNative/) and tracks the
// #if/#elseif/#else/#endif stack, so code in an #else branch is not mistaken for developer-only.
async function appSources(dir = new URL('../../ios/BlindAssist/', import.meta.url), prefix = '') {
  const files = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) files.push(...await appSources(new URL(`${entry.name}/`, dir), `${prefix}${entry.name}/`));
    else if (/\.(swift|mm|m|h|cpp)$/.test(entry.name)) files.push(`${prefix}${entry.name}`);
  }
  return files;
}
function developerOnlyLines(source) {
  const stack = [];
  return source.split('\n').map(line => {
    const directive = line.trim().match(/^#(if|elseif|else|endif)\b\s*(.*)$/);
    if (directive) {
      const [, kind, condition] = directive;
      if (kind === 'if') stack.push(condition.trim() === 'BLIND_DEVELOPER_CLOUD');
      else if (kind === 'elseif' || kind === 'else') { stack[stack.length - 1] = false; }
      else stack.pop();
      return true;
    }
    return stack.some(Boolean);
  });
}

test('no network upload path exists outside developer-only code, except public map downloads', async () => {
  for (const file of await appSources()) {
    if (file === 'PublicMapClient.swift') continue; // downloads public venue packages only
    const source = await read(`ios/BlindAssist/${file}`);
    const developer = developerOnlyLines(source);
    source.split('\n').forEach((line, index) => {
      if (/URLSession|\.upload\(|uploadTask|SceneQuestionClient\(/.test(line) && !line.trim().startsWith('//')) {
        assert.ok(developer[index], `${file}:${index + 1}: network or photo upload outside #if BLIND_DEVELOPER_CLOUD`);
      }
    });
  }
  const client = await read('ios/BlindAssist/SceneQuestionClient.swift');
  const developer = developerOnlyLines(client);
  const at = client.split('\n').findIndex(line => line.startsWith('struct SceneQuestionClient'));
  assert.ok(at >= 0 && developer[at], 'the photo client itself only exists in developer builds');
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
