import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, mkdir, readFile, writeFile, rm, symlink, open } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { generateProject, parseProjectArguments, verifyOpenCVFramework, verifyProjectInputs, verifyCurrencyReferencePack } from '../generate-xcode-project.mjs';

const currency = { currencyReference: true, opencvFramework: '/external/opencv2.framework' };
const face = { familiarPeople: true, opencvFramework: '/external/opencv2.framework', familiarModels: '/external/models' };
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const read = path => readFile(new URL(`../../${path}`, import.meta.url), 'utf8');
async function temporary(t) {
  const root = await mkdtemp(join(tmpdir(), 'blind-currency-project-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  return root;
}
async function framework(root, version = '14') {
  const path = join(root, 'opencv2.framework');
  await mkdir(join(path, 'Headers/core'), { recursive: true });
  await writeFile(join(path, 'Headers/core/version.hpp'), `#define CV_VERSION_MAJOR 4\n#define CV_VERSION_MINOR ${version}\n#define CV_VERSION_REVISION 0\n`);
  // Deliberately not a usable framework. This fixture tests layout/version
  // preflight only, never framework provenance, linking or native inference.
  await writeFile(join(path, 'opencv2'), 'synthetic layout fixture');
  return path;
}
async function pack(root, references = []) {
  const path = join(root, 'SaudiBanknoteReferences');
  await mkdir(path, { recursive: true });
  const manifest = { schema_version: 2, reference_kind: 'private_banknote_photos', currency: 'SAR', labels: [1, 5, 10, 20, 50, 100, 200, 500], references };
  await writeFile(join(path, 'manifest.json'), JSON.stringify(manifest));
  return path;
}
const fixtureBytes = Buffer.from('synthetic packaging fixture; not image or banknote evidence');
function reference(path = 'images/test.png', sha256 = hash(fixtureBytes)) {
  return { id: 'fixture', path, sha256, label: 5, side: 'front', issue: 'synthetic', material: 'paper',
    physical_note_id: 'fixture-note', capture_session_id: 'fixture-session', source: 'synthetic test only', rights: 'not image evidence',
    verification: { verified: true, verification_kind: 'assistant_visual_review', verified_by: 'fixture', verified_on: '2026-10-22', method: 'synthetic assertion, not actual review' },
    boundary: { source_size: [512, 256], corners_tl_tr_br_bl: [[0, 0], [511, 0], [511, 255], [0, 255]] } };
}

test('default remains without native currency, framework, pack or activation', async () => {
  const project = generateProject(['SaudiBanknoteReferenceRecognition.swift']);
  assert.doesNotMatch(project, /BLIND_CURRENCY_REFERENCE|BACurrencyReferenceEngine\.mm|wrapper\.framework|SaudiBanknoteReferences|SWIFT_OBJC_BRIDGING_HEADER/);
  assert.match(await read('ios/BlindAssist/SaudiBanknoteReferenceRecognition.swift'), /static let selected: SaudiBanknoteReferenceProfile\? = nil/);
});
test('currency-only links the engine and shared static OpenCV without face models', () => {
  const project = generateProject([], currency);
  for (const literal of ['BACurrencyReferenceEngine.mm', 'THIRD_PARTY_NOTICES.txt', 'BLIND_CURRENCY_REFERENCE=1', 'BlindAssist-Currency-Bridging-Header.h', 'CLANG_CXX_LANGUAGE_STANDARD = "c++17"', 'ImageIO.framework', '"-lc++"']) assert.ok(project.includes(literal), literal);
  assert.match(project, /SWIFT_ACTIVE_COMPILATION_CONDITIONS = "\$\(inherited\) BLIND_CURRENCY_REFERENCE"/);
  assert.doesNotMatch(project, /BAFaceEngine\.mm|face_detection_yunet|face_recognition_sface|glintr100|BLIND_FAMILIAR_PEOPLE|SaudiBanknoteReferences|PBXCopyFilesBuildPhase|CodeSignOnCopy/);
});
test('face-only retains its old bridge and model resources without currency code', () => {
  const project = generateProject([], face);
  assert.match(project, /BlindAssist\/FamiliarNative\/BlindAssist-Bridging-Header\.h/);
  assert.match(project, /BAFaceEngine\.mm/);
  assert.match(project, /face_recognition_sface_2021dec\.onnx/);
  assert.doesNotMatch(project, /BACurrency|BLIND_CURRENCY|Currency-Bridging|SaudiBanknoteReferences/);
});
test('combined SFace and AuraFace variants link OpenCV and each system framework only once', () => {
  for (const familiarBackend of ['sface', 'auraface']) {
    const project = generateProject([], { ...face, ...currency, familiarBackend, multimodal: true });
    assert.match(project, /BAFaceEngine\.mm/); assert.match(project, /BACurrencyReferenceEngine\.mm/);
    assert.match(project, /BLIND_FAMILIAR_PEOPLE=1/); assert.match(project, /BLIND_CURRENCY_REFERENCE=1/);
    assert.equal((project.match(/path = "\/external\/opencv2\.framework"/g) || []).length, 1);
    for (const name of ['UIKit', 'Accelerate', 'CoreGraphics', 'QuartzCore', 'ImageIO']) assert.equal((project.match(new RegExp(`path = System/Library/Frameworks/${name}\\.framework`, 'g')) || []).length, 1);
    const ids = [...project.matchAll(/^([A-F0-9]{24}) = /gm)].map(match => match[1]);
    assert.equal(ids.length, new Set(ids).size);
    for (const match of project.matchAll(/(?:fileRef|productRef|package|rootObject|productReference|mainGroup) = ([A-F0-9]{24});/g)) assert.ok(ids.includes(match[1]));
    assert.doesNotMatch(project, /PBXCopyFilesBuildPhase|CodeSignOnCopy/);
  }
});
test('private folder resource preserves its fixed name and is optional', () => {
  const project = generateProject([], { ...currency, currencyReferencePack: '/private/SaudiBanknoteReferences' });
  assert.match(project, /lastKnownFileType = folder; path = "\/private\/SaudiBanknoteReferences"; sourceTree = "<absolute>"/);
  assert.doesNotMatch(project, /manifest\.json|\.png|\.jpg/); // no flattened contents
  assert.throws(() => generateProject([], { currencyReferencePack: '/private/SaudiBanknoteReferences' }));
  assert.throws(() => generateProject([], { ...currency, currencyReferencePack: '/private/OtherName' }));
  assert.throws(() => generateProject([], { ...currency, currencyReferencePack: 'SaudiBanknoteReferences' }));
  assert.throws(() => generateProject([], { currencyReference: true }));
  assert.throws(() => generateProject([], { ...currency, opencvFramework: '/wrong/framework' }));
});
test('Mac architecture fix remains Debug YES and Release NO in every feature combination', () => {
  for (const options of [{}, currency, face, { ...currency, ...face }, { ...currency, ...face, familiarBackend: 'auraface' }]) {
    const project = generateProject([], options);
    for (const [name, value] of [['Debug', 'YES'], ['Release', 'NO']]) {
      const configuration = project.split('\n').find(line => line.includes(`name = ${name}; buildSettings`) && line.includes('SWIFT_ACTIVE_COMPILATION_CONDITIONS'));
      assert.ok(configuration?.includes(`ONLY_ACTIVE_ARCH = ${value};`));
    }
    assert.equal((project.match(/ONLY_ACTIVE_ARCH = /g) || []).length, 2);
  }
});
test('argument parsing supports currency without familiar models and combined backend selection', () => {
  const options = parseProjectArguments(['--currency-reference', '--opencv-framework', '/external/opencv2.framework']);
  assert.equal(options.currencyReference, true); assert.equal(options.familiarPeople, false); assert.equal(options.familiarModels, undefined);
  const combined = parseProjectArguments(['--currency-reference', '--familiar-people', '--familiar-backend', 'auraface', '--familiar-models', '/models', '--opencv-framework', '/external/opencv2.framework', '--currency-reference-pack', '/private/SaudiBanknoteReferences', '--multimodal']);
  assert.equal(combined.familiarBackend, 'auraface'); assert.equal(combined.multimodal, true);
  assert.equal(combined.currencyReferencePack, '/private/SaudiBanknoteReferences');
});
test('missing, repeated, unknown and incompatible generator arguments fail closed', () => {
  for (const args of [
    ['--currency-reference'], ['--currency-reference', '--opencv-framework'],
    ['--currency-reference-pack', '/private/SaudiBanknoteReferences'], ['--opencv-framework', '/x/opencv2.framework'],
    ['--currency-reference', '--familiar-models', '/models'], ['--currency-reference', '--familiar-backend', 'auraface'],
    ['--familiar-people', '--opencv-framework', '/x/opencv2.framework'], ['--currency-reference', '--currency-reference'],
    ['--curreny-reference'], ['--familiar-people', '--familiar-backend', 'other', '--opencv-framework', '/x/opencv2.framework', '--familiar-models', '/models'],
  ]) assert.throws(() => parseProjectArguments(args), args.join(' '));
});
test('currency-only preflight requires framework version/layout but no face assets', async t => {
  const root = await temporary(t), path = await framework(root);
  await verifyProjectInputs({ currencyReference: true, opencvFramework: path });
  await assert.rejects(verifyProjectInputs({ familiarPeople: true, opencvFramework: path, familiarModels: join(root, 'absent') }));
  await assert.rejects(verifyOpenCVFramework(join(root, 'missing.framework')));
  await writeFile(join(path, 'Headers/core/version.hpp'), '#define CV_VERSION_MAJOR 4\n#define CV_VERSION_MINOR 13\n#define CV_VERSION_REVISION 0\n');
  await assert.rejects(verifyOpenCVFramework(path), /4\.14\.0/);
  await framework(root); await rm(join(path, 'opencv2'));
  await assert.rejects(verifyOpenCVFramework(path));
});
test('empty private inventory is parseable for packaging but does not activate recognition', async t => {
  const root = await temporary(t), path = await pack(root);
  const result = await verifyCurrencyReferencePack(path);
  assert.equal(result.references, 0);
  assert.equal(result.manifestSHA256, hash(await readFile(join(path, 'manifest.json'))));
});
test('packaging verifies exact nested file bytes and manifest digest, not image accuracy', async t => {
  const root = await temporary(t), path = await pack(root, [reference()]);
  await mkdir(join(path, 'images')); await writeFile(join(path, 'images/test.png'), fixtureBytes);
  const result = await verifyCurrencyReferencePack(path);
  assert.equal(result.references, 1); assert.equal(result.manifestSHA256, hash(await readFile(join(path, 'manifest.json'))));
  await writeFile(join(path, 'images/test.png'), 'changed');
  await assert.rejects(verifyCurrencyReferencePack(path), /hash mismatch/);
});
test('pack rejects missing files, wrong folder name, wrong schema and bounded manifest violations', async t => {
  const root = await temporary(t);
  await assert.rejects(verifyCurrencyReferencePack(join(root, 'SaudiBanknoteReferences')));
  await assert.rejects(verifyCurrencyReferencePack(join(root, 'wrong-name')));
  const path = await pack(root, [reference()]);
  await assert.rejects(verifyCurrencyReferencePack(path));
  await writeFile(join(path, 'manifest.json'), '{"schema_version":1}');
  await assert.rejects(verifyCurrencyReferencePack(path), /schema/);
  await writeFile(join(path, 'manifest.json'), Buffer.alloc(256 * 1024 + 1, 32));
  await assert.rejects(verifyCurrencyReferencePack(path), /byte limit/);
  await pack(root, Array.from({ length: 49 }, () => reference()));
  await assert.rejects(verifyCurrencyReferencePack(path), /inventory/);
});
test('pack rejects traversal, URL escapes, control characters and ambiguous relative paths', async t => {
  const root = await temporary(t);
  for (const name of ['../x.png', '/x.png', 'a//x.png', './x.png', 'a/../x.png', 'a\\x.png', 'file:x.png', 'x%20.png', 'x\n.png', 'x\u0085.png']) {
    const path = await pack(root, [reference(name)]);
    await assert.rejects(verifyCurrencyReferencePack(path), /path\/hash/, name);
  }
});
test('pack rejects duplicate image paths/hashes and oversized source files before reading', async t => {
  const root = await temporary(t), ref = reference('test.png');
  const path = await pack(root, [ref, { ...ref, id: 'second' }]);
  await writeFile(join(path, 'test.png'), fixtureBytes);
  await assert.rejects(verifyCurrencyReferencePack(path), /duplicate/);
  await pack(root, [ref]);
  const file = await open(join(path, 'test.png'), 'r+'); await file.truncate(8 * 1024 * 1024 + 1); await file.close();
  await assert.rejects(verifyCurrencyReferencePack(path), /byte limit/);
});
test('folder preflight refuses unlisted private members and symlinks', async t => {
  const root = await temporary(t), path = await pack(root);
  await writeFile(join(path, 'unlisted-private.txt'), 'must not bundle');
  await assert.rejects(verifyCurrencyReferencePack(path), /Unlisted/);
  await rm(join(path, 'unlisted-private.txt')); await mkdir(join(path, 'unlisted'));
  await assert.rejects(verifyCurrencyReferencePack(path), /Unlisted/);
  await rm(join(path, 'unlisted'), { recursive: true });
  await writeFile(join(root, 'outside.png'), fixtureBytes);
  await pack(root, [reference('test.png')]); await symlink(join(root, 'outside.png'), join(path, 'test.png'));
  await assert.rejects(verifyCurrencyReferencePack(path), /symlinks/);
  const linkedParent = join(root, 'linked'); await mkdir(linkedParent);
  await symlink(path, join(linkedParent, 'SaudiBanknoteReferences'));
  await assert.rejects(verifyCurrencyReferencePack(join(linkedParent, 'SaudiBanknoteReferences')), /symlink/);
});
test('combined bridge imports declarations and notices identify source rights, not reference rights', async () => {
  const bridge = await read('ios/BlindAssist/CurrencyNative/BlindAssist-Currency-Bridging-Header.h');
  assert.match(bridge, /FamiliarNative\/BlindAssist-Bridging-Header\.h/);
  assert.match(bridge, /BACurrencyReferenceEngine\.h/);
  assert.doesNotMatch(bridge, /\.mm|\.hpp/);
  const notice = await read('ios/BlindAssist/CurrencyNative/THIRD_PARTY_NOTICES.txt');
  assert.match(notice, /OpenCV 4\.14\.0/); assert.match(notice, /Apache License/);
  assert.match(notice, /No banknote images are licensed here/);
});
