// Generator/input-contract checks with synthetic bytes, not actual Core ML models.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdtemp, mkdir, readFile, writeFile, rm, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, basename } from 'node:path';
import { generateProject, parseProjectArguments, verifyObjectDetector, verifyProjectInputs } from '../generate-xcode-project.mjs';
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const id = name => digest(name).slice(0, 24).toUpperCase();
async function temporary(t) {
  const root = await mkdtemp(join(tmpdir(), 'blind-detector-project-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  return root;
}
async function fixture(root, compiled = false) {
  await mkdir(root, { recursive: true });
  const objectDetector = join(root, compiled ? 'Detector.mlmodelc' : 'Detector.mlmodel');
  const objectDetectorManifest = join(root, 'detector-manifest.json');
  const bytes = Buffer.from('Synthetic packaging fixture, not model or recognition evidence');
  if (compiled) await mkdir(objectDetector);
  const path = compiled ? 'coremldata.bin' : 'Detector.mlmodel';
  await writeFile(compiled ? join(objectDetector, path) : objectDetector, bytes);
  const files = [{ path, sha256: digest(bytes) }];
  const manifest = {
    schema_version: 1, resource_kind: 'vision_object_detector', artifact_name: basename(objectDetector),
    artifact_sha256: compiled ? digest(`${path}\0${files[0].sha256}\n`) : files[0].sha256,
    vision_output: 'VNRecognizedObjectObservation', postprocessing: 'model_embedded_nms',
    input: { type: 'image', name: 'image', width: 640, height: 640, color_space: 'RGB' },
    labels: ['cup', 'chair'], source_url: 'https://example.test/fixture-only', source_revision: 'synthetic-v1',
    model_license: 'Synthetic fixture only; not a model license', data_license: 'No training data; synthetic fixture',
    reviewed_for_bundling: true, files
  };
  const save = () => writeFile(objectDetectorManifest, JSON.stringify(manifest));
  await save();
  return { objectDetector, objectDetectorManifest, manifest, save };
}
function generatedOptions(f, receipt) {
  return { objectDetector: f.objectDetector, objectDetectorSHA256: receipt.artifactSHA256,
    objectDetectorManifestSHA256: receipt.manifestSHA256 };
}

test('object detector is off by default and opt-in flags are paired, bounded and exact', () => {
  assert.doesNotMatch(generateProject([]), /Detector\.mlmodel|OBJECT_DETECTOR/);
  const args = ['--object-detector', '/external/Detector.mlmodel', '--object-detector-manifest', '/external/review.json'];
  assert.equal(parseProjectArguments(args).objectDetector, '/external/Detector.mlmodel');
  for (const invalid of [args.slice(0, 2), args.slice(2), [...args, '--object-detector', '/else/Detector.mlmodel'], ['--object-detector']]) {
    assert.throws(() => parseProjectArguments(invalid));
  }
  assert.throws(() => generateProject([], { objectDetector: '/external/Detector.mlmodel' }), /verified/);
  assert.throws(() => generateProject([], { objectDetectorSHA256: 'a'.repeat(64) }));
});

test('only the verified model artifact is linked in its correct Xcode build phase', async t => {
  const root = await temporary(t);
  for (const compiled of [false, true]) {
    const f = await fixture(join(root, String(compiled)), compiled);
    const receipt = await verifyObjectDetector(f.objectDetector, f.objectDetectorManifest);
    const project = generateProject(['BlindAssistApp.swift'], generatedOptions(f, receipt));
    const sources = project.split('\n').find(line => line.startsWith(id('sources') + ' ='));
    const resources = project.split('\n').find(line => line.startsWith(id('resources') + ' ='));
    assert.equal(sources.includes(id('build:object-detector')), !compiled);
    assert.equal(resources.includes(id('build:object-detector')), compiled);
    assert.match(project, compiled ? /lastKnownFileType = folder; path = .*Detector\.mlmodelc/ : /lastKnownFileType = file\.mlmodel; path = .*Detector\.mlmodel/);
    assert.ok(project.includes(receipt.artifactSHA256));
    assert.doesNotMatch(project, /detector-manifest\.json|fixture-only|Synthetic packaging/);
  }
});

test('detector options preserve combined native, image and Live Activity flags', async t => {
  const f = await fixture(await temporary(t));
  const receipt = await verifyObjectDetector(f.objectDetector, f.objectDetectorManifest);
  const project = generateProject([], { ...generatedOptions(f, receipt), multimodal: true, liveActivity: true,
    familiarPeople: true, familiarBackend: 'auraface', familiarModels: '/external/models', opencvFramework: '/external/opencv2.framework', currencyReference: true });
  for (const flag of ['BLIND_APPLE_MULTIMODAL', 'BLIND_LIVE_ACTIVITY', 'BLIND_FAMILIAR_AURAFACE', 'BLIND_CURRENCY_REFERENCE']) assert.ok(project.includes(flag));
});

test('preflight pins actual artifact and external-manifest bytes and detects tampering', async t => {
  const f = await fixture(await temporary(t));
  const receipt = await verifyProjectInputs(f);
  assert.equal(receipt.objectDetector.manifestSHA256, digest(await readFile(f.objectDetectorManifest)));
  assert.equal(receipt.objectDetector.artifactSHA256, digest(await readFile(f.objectDetector)));
  await writeFile(f.objectDetector, 'changed model bytes');
  await assert.rejects(verifyProjectInputs(f), /hash mismatch/);
});

test('raw tensors, missing provenance, invalid labels and image declarations fail closed', async t => {
  const root = await temporary(t);
  const mutations = [
    m => { m.vision_output = 'MLMultiArray'; }, m => { m.postprocessing = 'host_yolo_decoder'; },
    m => { m.labels = ['cup', 'CUP']; }, m => { m.labels = ['cup\nsecret']; }, m => { m.labels = []; },
    m => { m.input.type = 'multiArray'; }, m => { m.input.width = 0; },
    m => { delete m.model_license; }, m => { delete m.data_license; }, m => { m.reviewed_for_bundling = false; },
    m => { m.source_url = 'https://example.test/file?token=secret'; }, m => { m.source_url = 'https://user:secret@example.test/model'; }
  ];
  for (const [index, mutate] of mutations.entries()) {
    const f = await fixture(join(root, String(index))); mutate(f.manifest); await f.save();
    await assert.rejects(verifyObjectDetector(f.objectDetector, f.objectDetectorManifest));
  }
});

test('compiled folders reject unlisted images, secrets, symlinks and arbitrary metadata', async t => {
  const root = await temporary(t);
  for (const name of ['photo.jpg', '.env', 'credentials.json', 'secret.key', 'unexpected.bin']) {
    const f = await fixture(join(root, name.replaceAll('.', '_')), true);
    await writeFile(join(f.objectDetector, name), 'not a model');
    await assert.rejects(verifyObjectDetector(f.objectDetector, f.objectDetectorManifest), /unsafe detector/);
  }
  const f = await fixture(join(root, 'link'), true);
  await symlink(f.objectDetectorManifest, join(f.objectDetector, 'metadata.json'));
  await assert.rejects(verifyObjectDetector(f.objectDetector, f.objectDetectorManifest), /unsafe detector/);
  f.manifest.files.push({ path: 'credentials.json', sha256: 'a'.repeat(64) }); await f.save();
  await assert.rejects(verifyObjectDetector(f.objectDetector, f.objectDetectorManifest), /unsafe detector/);
});

test('inventory traversal, duplicate members, root symlinks and internal manifests are rejected', async t => {
  const root = await temporary(t);
  for (const path of ['../coremldata.bin', '/coremldata.bin', 'weights\\weight.bin', 'weights/../../secret.bin']) {
    const f = await fixture(join(root, digest(path)), true);
    f.manifest.files[0].path = path; await f.save();
    await assert.rejects(verifyObjectDetector(f.objectDetector, f.objectDetectorManifest));
  }
  const f = await fixture(join(root, 'duplicate'), true);
  f.manifest.files.push(f.manifest.files[0]); await f.save();
  await assert.rejects(verifyObjectDetector(f.objectDetector, f.objectDetectorManifest), /duplicate/);
  const other = await fixture(join(root, 'other'), true);
  const linked = join(root, 'Detector.mlmodelc'); await symlink(other.objectDetector, linked);
  await assert.rejects(verifyObjectDetector(linked, other.objectDetectorManifest), /symlink/);
  const inside = join(other.objectDetector, 'metadata.json'); await writeFile(inside, JSON.stringify(other.manifest));
  await assert.rejects(verifyObjectDetector(other.objectDetector, inside), /external/);
});

test('CLI verifies before writing only an isolated temporary project and keeps previous project on failure', async t => {
  const root = await temporary(t), f = await fixture(join(root, 'external'));
  const projectRoot = join(root, 'project');
  await mkdir(join(projectRoot, 'tools'), { recursive: true });
  await mkdir(join(projectRoot, 'ios/BlindAssist'), { recursive: true });
  const script = join(projectRoot, 'tools/generate-xcode-project.mjs');
  await writeFile(script, await readFile(new URL('../generate-xcode-project.mjs', import.meta.url)));
  const args = [script, '--object-detector', f.objectDetector, '--object-detector-manifest', f.objectDetectorManifest, '--multimodal', '--live-activity'];
  const result = spawnSync(process.execPath, args, { cwd: projectRoot, encoding: 'utf8', timeout: 20_000 });
  assert.equal(result.status, 0, result.stderr || result.error?.message);
  assert.match(result.stdout, /Packaging declaration checked/);
  const projectPath = join(projectRoot, 'ios/BlindAssist.xcodeproj/project.pbxproj');
  const project = await readFile(projectPath, 'utf8');
  await writeFile(f.objectDetector, 'tampered');
  const invalid = spawnSync(process.execPath, args, { cwd: projectRoot, encoding: 'utf8', timeout: 20_000 });
  assert.notEqual(invalid.status, 0);
  assert.equal(await readFile(projectPath, 'utf8'), project);
});
test('all Debug targets define DEBUG while Release omits it and retains feature flags', () => {
  for (const options of [{}, { liveActivity: true }, { multimodal: true, liveActivity: true,
    familiarPeople: true, familiarBackend: 'auraface', familiarModels: '/external/models',
    opencvFramework: '/external/opencv2.framework', currencyReference: true }]) {
    const project = generateProject([], options);
    const configurations = project.split('\n').filter(line => line.includes('isa = XCBuildConfiguration;'));
    assert.equal(configurations.length, options.liveActivity ? 8 : 6);
    for (const configuration of configurations) {
      const conditions = configuration.match(/SWIFT_ACTIVE_COMPILATION_CONDITIONS = "([^"]*)"/)?.[1];
      assert.ok(conditions?.includes('$(inherited)'));
      assert.equal((conditions.match(/\bDEBUG\b/g) ?? []).length, configuration.includes('name = Debug;') ? 1 : 0);
    }
    if (options.multimodal) assert.equal(configurations.filter(line => line.includes('BLIND_APPLE_MULTIMODAL')).length, 2);
    if (options.liveActivity) assert.equal(configurations.filter(line => line.includes('BLIND_LIVE_ACTIVITY')).length, 4);
  }
});

