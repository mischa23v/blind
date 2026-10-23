// Generator/preflight tests only. Synthetic framework and image bytes below cannot
// establish Apple linking, reference suitability, recognition quality or approval.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { generateProject, parseProjectArguments, verifyProjectInputs } from '../generate-xcode-project.mjs';

const digest = value => createHash('sha256').update(value).digest('hex');
const expected = 'a'.repeat(64);
const native = { currencyReference: true, opencvFramework: '/external/opencv2.framework', currencyReferencePack: '/private/SaudiBanknoteReferences' };
const trial = { ...native, currencyDeviceTest: true, currencyReferencePackSHA256: expected };
function appConfiguration(project, name) {
  const line = project.split('\n').find(value => value.includes(`name = ${name}; buildSettings`)
    && value.includes('PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility;'));
  assert.ok(line, `Missing app ${name} configuration`);
  return line;
}
async function temporary(t) {
  const root = await mkdtemp(join(tmpdir(), 'blind-currency-device-project-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  return root;
}
async function inputs(root, { empty = false } = {}) {
  const opencvFramework = join(root, 'opencv2.framework');
  await mkdir(join(opencvFramework, 'Headers/core'), { recursive: true });
  await writeFile(join(opencvFramework, 'Headers/core/version.hpp'), '#define CV_VERSION_MAJOR 4\n#define CV_VERSION_MINOR 14\n#define CV_VERSION_REVISION 0\n');
  await writeFile(join(opencvFramework, 'opencv2'), 'Synthetic layout fixture, not a framework binary');
  const currencyReferencePack = join(root, 'SaudiBanknoteReferences');
  await mkdir(currencyReferencePack, { recursive: true });
  const bytes = Buffer.from('Synthetic photo bytes, not recognition evidence');
  const manifest = { schema_version: 2, reference_kind: 'private_banknote_photos', currency: 'SAR',
    labels: [1, 5, 10, 20, 50, 100, 200, 500], references: empty ? [] : [{ path: 'fixture.png', sha256: digest(bytes) }] };
  await writeFile(join(currencyReferencePack, 'manifest.json'), JSON.stringify(manifest));
  if (!empty) await writeFile(join(currencyReferencePack, 'fixture.png'), bytes);
  return { currencyReference: true, currencyDeviceTest: true, opencvFramework, currencyReferencePack };
}

test('ordinary configurations have no device-test flag or manifest pin', () => {
  for (const options of [{}, native]) {
    const project = generateProject([], options);
    assert.doesNotMatch(project, /BLIND_CURRENCY_DEVICE_TEST|CURRENCY_REFERENCE_PACK_SHA256/);
  }
});

test('only opted-in app Debug gets both compile gates and the verified manifest pin', () => {
  const project = generateProject(['SaudiBanknoteReferenceRecognition.swift'], trial);
  const debug = appConfiguration(project, 'Debug'), release = appConfiguration(project, 'Release');
  assert.match(debug, /SWIFT_ACTIVE_COMPILATION_CONDITIONS = "[^"\n]*\bDEBUG\b[^"\n]*\bBLIND_CURRENCY_DEVICE_TEST\b/);
  assert.match(debug, /BLIND_CURRENCY_REFERENCE/);
  assert.ok(debug.includes(`CURRENCY_REFERENCE_PACK_SHA256 = "${expected}"`));
  assert.doesNotMatch(release, /BLIND_CURRENCY_DEVICE_TEST|CURRENCY_REFERENCE_PACK_SHA256|\bDEBUG\b/);
  assert.equal((project.match(/CURRENCY_REFERENCE_PACK_SHA256 =/g) ?? []).length, 1);
  assert.equal((project.match(/BLIND_CURRENCY_DEVICE_TEST/g) ?? []).length, 1);
  assert.match(debug, /ONLY_ACTIVE_ARCH = YES/);
  assert.match(release, /ONLY_ACTIVE_ARCH = NO/);
});

test('device-test choice preserves combined AuraFace multimodal and Live Activity variants', () => {
  const project = generateProject([], { ...trial, familiarPeople: true, familiarBackend: 'auraface',
    familiarModels: '/external/models', multimodal: true, liveActivity: true });
  for (const name of ['Debug', 'Release']) {
    const configuration = appConfiguration(project, name);
    for (const flag of ['BLIND_FAMILIAR_PEOPLE', 'BLIND_FAMILIAR_AURAFACE', 'BLIND_APPLE_MULTIMODAL', 'BLIND_LIVE_ACTIVITY', 'BLIND_CURRENCY_REFERENCE']) {
      assert.ok(configuration.includes(flag), `${name}: ${flag}`);
    }
  }
  assert.match(project, /glintr100.onnx/);
  assert.match(project, /BlindAssistLiveActivity.appex/);
  assert.equal((project.match(/path = "\/external\/opencv2.framework"/g) ?? []).length, 1);
  const otherConfigurations = project.split('\n').filter(line => line.includes('isa = XCBuildConfiguration')
    && !line.includes('PRODUCT_BUNDLE_IDENTIFIER = org.blindassist.mobility;'));
  for (const configuration of otherConfigurations) assert.doesNotMatch(configuration, /BLIND_CURRENCY_DEVICE_TEST|CURRENCY_REFERENCE_PACK_SHA256/);
});

test('device-test flags require explicit reference pack and native build, with no unchecked CLI hash', () => {
  const valid = ['--currency-device-test', '--currency-reference', '--opencv-framework', '/external/opencv2.framework',
    '--currency-reference-pack', '/private/SaudiBanknoteReferences'];
  assert.equal(parseProjectArguments(valid).currencyDeviceTest, true);
  for (const args of [
    ['--currency-device-test'], ['--currency-device-test', '--currency-reference', '--opencv-framework', '/external/opencv2.framework'],
    ['--currency-device-test', '--currency-reference', '--currency-reference-pack', '/private/SaudiBanknoteReferences'],
    [...valid, '--currency-device-test'], [...valid, '--currency-reference-pack-sha256', expected]
  ]) assert.throws(() => parseProjectArguments(args), args.join(' '));
  for (const options of [
    { ...trial, currencyReference: false }, { ...trial, currencyReferencePack: undefined }, { ...trial, opencvFramework: undefined },
    { ...trial, currencyReferencePackSHA256: undefined }, { ...trial, currencyReferencePackSHA256: 'wrong' },
    { ...trial, currencyReferencePackSHA256: `${expected}; OTHER = YES;` }, { ...trial, currencyDeviceTest: false }
  ]) assert.throws(() => generateProject([], options));
});

test('device-test preflight pins verified bytes and rejects empty or changed reference packs', async t => {
  const root = await temporary(t), options = await inputs(root);
  const pack = await verifyProjectInputs(options);
  assert.equal(pack.manifestSHA256, digest(await readFile(join(options.currencyReferencePack, 'manifest.json'))));
  assert.equal(pack.references, 1);
  const project = generateProject([], { ...options, currencyReferencePackSHA256: pack.manifestSHA256 });
  assert.ok(appConfiguration(project, 'Debug').includes(pack.manifestSHA256));
  await writeFile(join(options.currencyReferencePack, 'fixture.png'), 'changed');
  await assert.rejects(verifyProjectInputs(options), /hash mismatch/);
  const emptyRoot = join(root, 'empty');
  const empty = await inputs(emptyRoot, { empty: true });
  await assert.rejects(verifyProjectInputs(empty), /nonempty/);
  await assert.rejects(verifyProjectInputs({ ...options, currencyReference: false }), /explicit native currency/);
});

test('Info metadata binds to the build setting rather than committing a reference hash', async () => {
  const plist = await readFile(new URL('../../ios/BlindAssist/Info.plist', import.meta.url), 'utf8');
  assert.match(plist, /<key>BACurrencyDeviceTestManifestSHA256<\/key>\s*<string>\$\(CURRENCY_REFERENCE_PACK_SHA256\)<\/string>/);
  assert.doesNotMatch(plist, /<string>[a-f0-9]{64}<\/string>/);
});

test('CLI generates only an isolated temporary project and derives its pin from verified manifest bytes', async t => {
  const root = await temporary(t), options = await inputs(root);
  await mkdir(join(root, 'tools'), { recursive: true });
  await mkdir(join(root, 'ios/BlindAssist'), { recursive: true });
  const source = await readFile(new URL('../generate-xcode-project.mjs', import.meta.url), 'utf8');
  const script = join(root, 'tools/generate-xcode-project.mjs');
  await writeFile(script, source);
  const args = [script, '--currency-reference', '--currency-device-test', '--opencv-framework', options.opencvFramework,
    '--currency-reference-pack', options.currencyReferencePack, '--live-activity', '--multimodal'];
  const result = spawnSync(process.execPath, args, { cwd: root, encoding: 'utf8', timeout: 20_000 });
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  const pin = digest(await readFile(join(options.currencyReferencePack, 'manifest.json')));
  const projectPath = join(root, 'ios/BlindAssist.xcodeproj/project.pbxproj');
  const project = await readFile(projectPath, 'utf8');
  assert.ok(appConfiguration(project, 'Debug').includes(pin));
  assert.doesNotMatch(appConfiguration(project, 'Release'), /BLIND_CURRENCY_DEVICE_TEST|CURRENCY_REFERENCE_PACK_SHA256/);
  assert.match(result.stdout, /Debug-only adult-supervised device-test profile/);
  await writeFile(join(options.currencyReferencePack, 'fixture.png'), 'tampered');
  const invalid = spawnSync(process.execPath, args, { cwd: root, encoding: 'utf8', timeout: 20_000 });
  assert.notEqual(invalid.status, 0);
  assert.equal(await readFile(projectPath, 'utf8'), project, 'Failed preflight cannot overwrite the prior project');
});
