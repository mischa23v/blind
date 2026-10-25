import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Source guard, not an Apple SDK compilation substitute. Keep package fixtures
// independent of XCTestCase's differing Apple/corelibs constructors.
function constructors(files) {
  const classes = new Set(files.flatMap(({ text }) =>
    [...text.matchAll(/\bclass\s+(\w+)\s*:\s*XCTestCase\b/g)].map(match => match[1])));
  return files.flatMap(({ path, text }) => [...classes].flatMap(name =>
    [...text.matchAll(new RegExp(`\\b${name}\\s*\\(`, 'g'))].map(() => `${path}: ${name}`)));
}
function swiftFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? swiftFiles(path) : entry.name.endsWith('.swift')
      ? [{ path, text: readFileSync(path, 'utf8') }] : [];
  });
}
test('guard detects cross-file XCTestCase fixture construction, not plain helpers', () => {
  const definitions = { path: 'tests.swift', text: 'final class ReadingTests: XCTestCase {}' };
  assert.equal(constructors([definitions, { path: 'other.swift', text: 'let f = ReadingTests(name: "fixtures") { _ in }' }]).length, 1);
  assert.equal(constructors([definitions, { path: 'other.swift', text: 'let f = ReadingTests()' }]).length, 1);
  assert.deepEqual(constructors([definitions, { path: 'helper.swift', text: 'struct ReadingFixtures {}\nlet f = ReadingFixtures()' }]), []);
});
test('portable BlindCore tests never construct XCTestCase subclasses as fixtures', () => {
  const root = process.env.BLIND_FIXTURE_PORTABILITY_ROOT || fileURLToPath(new URL('../../', import.meta.url));
  assert.deepEqual(constructors(swiftFiles(join(root, 'BlindCore/Tests'))), []);
});
