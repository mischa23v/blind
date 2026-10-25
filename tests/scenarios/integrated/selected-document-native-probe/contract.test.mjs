// Source/generator checks only. This does not execute native code or the runner.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, rmSync, cpSync, appendFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const read = path => readFileSync(join(here, path), 'utf8');
test('three exact snapshots and fourteen native tests remain pinned', () => {
  const pins = JSON.parse(read('source-pins.json'));
  assert.equal(Object.keys(pins.files).length, 3);
  for (const [path, pin] of Object.entries(pins.files)) {
    assert.equal(createHash('sha256').update(readFileSync(join(here, path))).digest('hex'), pin.sha256);
  }
  assert.equal(pins.expectedNativeTests, 14);
  assert.equal((read('Tests/SelectedDocumentPDFTests.swift').match(/func test\w*\(/g) || []).length, 14);
  assert.match(read('Tests/SelectedDocumentPDFTests.swift'), /@testable import BlindAssist/);
});
test('generator copies unchanged snapshots into a scene-backed isolated host without packages or resources', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'selected-pdf-packet-'));
  try {
    const out = join(tmp, 'fresh');
    const run = spawnSync(process.execPath, [join(here, 'generate-project.mjs'), out], { encoding: 'utf8' });
    assert.equal(run.status, 0, run.stdout + run.stderr);
    const project = readFileSync(join(out, 'SelectedDocumentProbe.xcodeproj/project.pbxproj'), 'utf8');
    assert.match(project, /PRODUCT_MODULE_NAME = BlindAssist/);
    assert.match(project, /org\.blindassist\.selectedpdfprobe\.host/);
    assert.match(project, /ONLY_ACTIVE_ARCH = YES/);
    assert.match(project, /TEST_HOST = "\$\(BUILT_PRODUCTS_DIR\)\/BlindAssist.app\/BlindAssist"/);
    assert.doesNotMatch(project, /SwiftPackage|GRDB|NavigationModel|Feedback.swift|BlindCore|PBXResourcesBuildPhase|CODE_SIGN_ENTITLEMENTS/);
    assert.match(readFileSync(join(out, 'Host.swift'), 'utf8'), /WindowGroup \{ Color.clear \}/);
    for (const path of Object.keys(JSON.parse(read('source-pins.json')).files)) {
      assert.deepEqual(readFileSync(join(out, path)), readFileSync(join(here, path)));
    }
    const again = spawnSync(process.execPath, [join(here, 'generate-project.mjs'), out], { encoding: 'utf8' });
    assert.notEqual(again.status, 0); assert.match(again.stderr, /Output exists/);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});
test('modified snapshot fails before creating generated output', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'selected-pdf-pin-'));
  try {
    const packet = join(tmp, 'packet'), out = join(tmp, 'output');
    cpSync(here, packet, { recursive: true });
    appendFileSync(join(packet, 'Sources/SelectedDocumentPDFAdapter.swift'), '\n// mutation\n');
    const run = spawnSync(process.execPath, [join(packet, 'generate-project.mjs'), out], { encoding: 'utf8' });
    assert.notEqual(run.status, 0); assert.match(run.stderr, /Exact snapshot review required/);
    assert.equal(existsSync(out), false);
  } finally { rmSync(tmp, { recursive: true, force: true }); }
});
test('runner is hosted-only with one fixed invocation and cleanup of only its owned simulator', () => {
  const shell = read('run-native.sh'), once = read('run-once.py'), exporter = read('export-receipt.py');
  assert.match(shell, /RUNNER_ENVIRONMENT:-\} == github-hosted/);
  assert.match(shell, /rev-parse HEAD\) == "\$GITHUB_SHA"/);
  assert.match(shell, /simctl create/); assert.match(shell, /simctl shutdown "\$sim"/); assert.match(shell, /simctl delete "\$sim"/);
  assert.doesNotMatch(shell, /simctl (?:shutdown|delete) all|downloadPlatform|downloadComponent/);
  assert.match(shell, /bootstatus.*timeout=120/);
  assert.equal((once.match(/subprocess\.Popen\(/g) || []).length, 1);
  assert.match(once, /process.wait\(timeout=600\)/);
  assert.match(once, /-only-testing:SelectedDocumentNativeTests\/SelectedDocumentPDFTests/);
  assert.match(exporter, /'totalTestCount': 14, 'passedTests': 14, 'failedTests': 0, 'skippedTests': 0/);
  assert.doesNotMatch(exporter, /['"]export['"].*['"]attachments['"]|copytree\(|rglob\(/);
  assert.match(exporter, /handle.read\(64 \* 1024\)/);
});
