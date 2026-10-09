import { test } from 'node:test';
import assert from 'node:assert/strict';
import { importLandmarks } from '../import-imdf.mjs';
import { generateProject, generateScheme } from '../generate-xcode-project.mjs';
import { buildCommands } from '../mac-setup.mjs';
test('IMDF points preserve position without fabricating walkable edges', () => {
  const point = { id: 'entrance', geometry: { type: 'Point', coordinates: [46.7, 24.7] }, properties: { name: { en: 'Entrance' }, level_id: '0' } };
  const map = importLandmarks({ type: 'FeatureCollection', features: [point] }, 24.7, 46.7);
  assert.equal(map.nodes[0].position.x, 0); assert.equal(Math.abs(map.nodes[0].position.z), 0);
  assert.deepEqual(map.edges, []);
  assert.throws(() => importLandmarks({ type: 'FeatureCollection', features: [point, point] }, 24.7, 46.7));
  assert.throws(() => importLandmarks({ type: 'FeatureCollection', features: [point] }, NaN, 46.7));
});
test('Mac handoff builds both Apple SDK targets without requiring signing secrets', () => {
  const jobs = buildCommands(true);
  assert.equal(jobs.filter(([cmd]) => cmd === 'xcodebuild').length, 3);
  assert.ok(jobs.filter(([cmd]) => cmd === 'xcodebuild').every(([, args]) => args.includes('CODE_SIGNING_ALLOWED=NO')));
  const project = generateProject(['BlindAssistApp.swift']);
  const target = project.match(/([A-F0-9]{24}) = \{ isa = PBXNativeTarget/)[1];
  assert.ok(generateScheme().includes(`BlueprintIdentifier="${target}"`));
});
test('Xcode source references resolve to objects, with a local Swift package', () => {
  const project = generateProject(['BlindAssistApp.swift', 'NavigationModel.swift']);
  const ids = [...project.matchAll(/^([A-F0-9]{24}) = /gm)].map(match => match[1]);
  assert.equal(ids.length, new Set(ids).size);
  for (const match of project.matchAll(/(?:fileRef|productRef|package|rootObject|productReference|mainGroup) = ([A-F0-9]{24});/g)) assert.ok(ids.includes(match[1]), match[1]);
  assert.match(project, /relativePath = ..\/BlindCore/);
  assert.match(project, /relativePath = ..\/BlindMemory/);
  assert.match(project, /productName = BlindMemory/);
  assert.match(project, /productType = "com.apple.product-type.bundle.unit-test"/);
  assert.match(project, /TEST_HOST = "\$\(BUILT_PRODUCTS_DIR\)\/BlindAssist.app\/BlindAssist"/);
  assert.match(generateScheme(), /BuildableName="BlindAssistTests.xctest"/);
  assert.doesNotMatch(project, /BLIND_RTABMAP/);
});

test('on-device image APIs require explicit SDK-gated project selection', () => {
  const files = ['BlindAssistApp.swift', 'LocalImageAssistant.swift'];
  assert.doesNotMatch(generateProject(files), /BLIND_APPLE_MULTIMODAL/);
  const enabled = generateProject(files, { multimodal: true });
  assert.match(enabled, /SWIFT_ACTIVE_COMPILATION_CONDITIONS = "\$\(inherited\) BLIND_APPLE_MULTIMODAL"/);
  assert.doesNotMatch(enabled, /BLIND_RTABMAP/);
});
