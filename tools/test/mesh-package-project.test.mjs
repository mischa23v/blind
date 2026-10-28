// In-memory project graph checks only: no Xcode, package resolution, capture or activation.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { generateProject, generateScheme, parseProjectArguments } from '../generate-xcode-project.mjs';

const meshIDs = {
  package: 'DD2FA2D57E5C6E1A7D616284',
  product: 'D1B43D902579482AF65E0FAE',
  library: '969CE00EF21E6E841975C27C',
};
const files = ['BlindAssistApp.swift', 'NavigationModel.swift', 'MeshCandidateDiagnostics.swift'];
const list = (body, key) => (body.match(new RegExp(`\\b${key} = \\(([^)]*)\\);`))?.[1] ?? '').split(',').filter(Boolean);
function objects(project) {
  const entries = [...project.matchAll(/^([A-F0-9]{24}) = \{ (.*) \};$/gm)].map(([, key, body]) => [key, body]);
  assert.equal(new Set(entries.map(([key]) => key)).size, entries.length, 'unique object IDs');
  return new Map(entries);
}
function meshLinkage(project) {
  const graph = objects(project);
  const one = pattern => {
    const found = [...graph].filter(([, body]) => pattern.test(body));
    assert.equal(found.length, 1, `one ${pattern}`);
    return found[0];
  };
  const [packageID, pkg] = one(/isa = XCLocalSwiftPackageReference; relativePath = "?\.\.\/research\/mesh-candidate-ingress-83"?;/);
  const [productID, product] = one(/isa = XCSwiftPackageProductDependency; .*productName = MeshCandidateIngress83;/);
  assert.match(product, new RegExp(`package = ${packageID};`));
  const [libraryID] = one(new RegExp(`isa = PBXBuildFile; productRef = ${productID};`));
  const [appID, app] = one(/isa = PBXNativeTarget; .*name = BlindAssist;/);
  assert.ok(list(app, 'packageProductDependencies').includes(productID), 'app owns mesh product');
  const [frameworksID, frameworks] = one(new RegExp(`isa = PBXFrameworksBuildPhase; .*files = \\([^)]*${libraryID}`));
  assert.ok(list(app, 'buildPhases').includes(frameworksID), 'mesh framework phase belongs to app');
  assert.ok(list(frameworks, 'files').includes(libraryID));
  const [, root] = one(/isa = PBXProject;/);
  assert.ok(list(root, 'packageReferences').includes(packageID), 'project owns mesh package');
  assert.ok(list(root, 'targets').includes(appID));
  for (const [targetID, target] of graph) {
    if (!target.startsWith('isa = PBXNativeTarget;') || targetID === appID) continue;
    assert.ok(!list(target, 'packageProductDependencies').includes(productID), 'no direct mesh dependency on test/extension targets');
    assert.ok(!list(target, 'buildPhases').includes(frameworksID), 'no shared mesh framework phase');
  }
  assert.deepEqual({ package: packageID, product: productID, library: libraryID }, meshIDs, 'preserve stage85 IDs');
  return { pkg, product, packageID, productID, libraryID, appID, frameworksID,
    packages: list(root, 'packageReferences'), products: list(app, 'packageProductDependencies'), libraries: list(frameworks, 'files') };
}

test('regeneration preserves the existing app mesh package/product/framework linkage', async () => {
  const committed = await readFile(new URL('../../ios/BlindAssist.xcodeproj/project.pbxproj', import.meta.url), 'utf8');
  const generated = generateProject(files);
  assert.deepEqual(meshLinkage(generated), meshLinkage(committed));
  for (const name of ['BlindCore', 'BlindMemory']) assert.match(generated, new RegExp(`productName = ${name};`));
});

test('linkage assertions reject missing graph edges, not just missing package text', () => {
  const project = generateProject(files);
  const linkage = meshLinkage(project);
  for (const [key, value] of [
    ['packageReferences', meshIDs.package], ['packageProductDependencies', meshIDs.product],
    ['files', meshIDs.library], ['buildPhases', linkage.frameworksID],
  ]) {
    const broken = project.replace(new RegExp(`(${key} = \\([^)]*)${value},`), '$1');
    assert.notEqual(broken, project);
    assert.throws(() => meshLinkage(broken), undefined, `missing ${key} edge must fail`);
  }
  for (const key of ['package', 'productRef']) {
    const value = key === 'package' ? meshIDs.package : meshIDs.product;
    assert.throws(() => meshLinkage(project.replace(`${key} = ${value};`, `${key} = 000000000000000000000000;`)));
  }
});

test('ordinary generation includes the fenced bridge but leaves every feature flag opt-in', async () => {
  const sourceFiles = (await readdir(new URL('../../ios/BlindAssist/', import.meta.url))).filter(file => file.endsWith('.swift')).sort();
  const project = generateProject(sourceFiles, parseProjectArguments([]));
  assert.equal(project, generateProject(sourceFiles));
  meshLinkage(project);
  const graph = objects(project);
  const refs = [...graph].filter(([, body]) => /path = "BlindAssist\/MeshCandidateDiagnostics.swift";/.test(body));
  assert.equal(refs.length, 1);
  const builds = [...graph].filter(([, body]) => body === `isa = PBXBuildFile; fileRef = ${refs[0][0]};`);
  assert.equal(builds.length, 1);
  const app = [...graph.values()].find(body => /isa = PBXNativeTarget; .*name = BlindAssist;/.test(body));
  assert.ok(list(app, 'buildPhases').some(id => graph.get(id).startsWith('isa = PBXSourcesBuildPhase;') && list(graph.get(id), 'files').includes(builds[0][0])));
  const conditions = [...project.matchAll(/SWIFT_ACTIVE_COMPILATION_CONDITIONS = "([^"]*)"/g)].map(([, value]) => value);
  assert.equal(conditions.length, 6);
  assert.deepEqual(new Set(conditions), new Set(['$(inherited)', '$(inherited) DEBUG']));
  assert.doesNotMatch(project + generateScheme(), /BLIND_MESH_CANDIDATE_DIAGNOSTICS|BLIND_DEVELOPER_CLOUD|BLIND_RTABMAP/);
  // Hosted Store tests now explicitly link the SAME GRDB version already used by BlindMemory.
  // Do not permit arbitrary remote dependencies, shell steps or changed versions.
  const remote = [...graph].filter(([, body]) => body.startsWith('isa = XCRemoteSwiftPackageReference;'));
  assert.equal(remote.length, 1);
  assert.equal(remote[0][1], 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/groue/GRDB.swift.git"; requirement = { kind = exactVersion; version = 7.11.1; };');
  const memoryManifest = await readFile(new URL('../../BlindMemory/Package.swift', import.meta.url), 'utf8');
  assert.ok(memoryManifest.includes('.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")'));
  assert.doesNotMatch(project.replace(`${remote[0][0]} = { ${remote[0][1]} };`, ''), /XCRemoteSwiftPackageReference|PBXShellScriptBuildPhase|https?:\/\//);
  assert.throws(() => parseProjectArguments(['--mesh-candidate-diagnostics']), /Unknown/);
});

const people = { familiarPeople: true, opencvFramework: '/external/opencv2.framework', familiarModels: '/external/models' };
const currency = { currencyReference: true, opencvFramework: '/external/opencv2.framework' };
const trial = { ...currency, currencyDeviceTest: true, currencyReferencePack: '/private/SaudiBanknoteReferences', currencyReferencePackSHA256: 'a'.repeat(64) };
const detector = { objectDetector: '/external/Detector.mlmodel', objectDetectorSHA256: 'b'.repeat(64), objectDetectorManifestSHA256: 'c'.repeat(64) };
for (const [name, options] of Object.entries({
  multimodal: { multimodal: true }, liveActivity: { liveActivity: true }, sface: people,
  auraface: { ...people, familiarBackend: 'auraface' }, currency, currencyDeviceTest: trial, detector,
  combined: { ...people, ...trial, ...detector, familiarBackend: 'auraface', liveActivity: true, multimodal: true },
})) {
  test(`${name} options preserve mesh linkage without enabling diagnostics or developer cloud`, () => {
    const project = generateProject(files, options);
    meshLinkage(project);
    assert.doesNotMatch(project + generateScheme(), /BLIND_MESH_CANDIDATE_DIAGNOSTICS|BLIND_DEVELOPER_CLOUD|BLIND_RTABMAP/);
    assert.equal(project, generateProject(files, options), 'deterministic generation');
  });
}


test('hosted Store tests explicitly own existing Memory and GRDB products without adding them to app', () => {
  const graph = objects(generateProject(files));
  const only = pattern => { const entries = [...graph].filter(([, body]) => pattern.test(body)); assert.equal(entries.length, 1); return entries[0]; };
  const [, unit] = only(/isa = PBXNativeTarget; .*name = BlindAssistTests;/);
  const [, app] = only(/isa = PBXNativeTarget; .*name = BlindAssist;/);
  for (const productName of ['BlindMemory', 'GRDB']) {
    const matches = [...graph].filter(([id, body]) => body.includes(`productName = ${productName};`) && list(unit, 'packageProductDependencies').includes(id));
    assert.equal(matches.length, 1);
    const [productID, product] = matches[0];
    const packageID = product.match(/package = ([A-F0-9]{24});/)[1];
    assert.ok(graph.has(packageID));
    const [libraryID] = only(new RegExp(`isa = PBXBuildFile; productRef = ${productID};`));
    assert.ok(list(unit, 'buildPhases').some(id => graph.get(id).startsWith('isa = PBXFrameworksBuildPhase;') && list(graph.get(id), 'files').includes(libraryID)));
    assert.ok(!list(app, 'packageProductDependencies').includes(productID), 'test product linkage is not app linkage');
  }
});
