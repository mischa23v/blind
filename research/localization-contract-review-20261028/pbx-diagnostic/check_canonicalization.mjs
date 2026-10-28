import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { generateProject } from '../../../tools/generate-xcode-project.mjs';
import assert from 'node:assert/strict';
const root = new URL('../../../', import.meta.url);
const read = p => readFile(new URL(p, root), 'utf8');
const current = await read('ios/BlindAssist.xcodeproj/project.pbxproj');
const names = (await readdir(new URL('ios/BlindAssist/', root))).filter(f => f.endsWith('.swift')).sort();
const generated = generateProject(names);
const patch = await read('research/native-candidate-app-integration-85/integrated/project-canonicalization.patch');
// Unified diff preserves every removed line. Only the two changed ranges are needed
// to reconstruct their original source records, package declarations and settings.
const removed = patch.split('\n').filter(l => l.startsWith('-') && !l.startsWith('---')).map(l => l.slice(1));
const added = patch.split('\n').filter(l => l.startsWith('+') && !l.startsWith('+++')).map(l => l.slice(1));
const oldRefs = removed.filter(l=>l.includes('PBXFileReference'));
const newRefs = added.filter(l=>l.includes('PBXFileReference'));
assert.equal(names.length, 61);
assert.equal(current, generated);
assert.equal(oldRefs.length, 1); assert.equal(newRefs.length, 1);
assert.ok([...oldRefs, ...newRefs].every(l=>l.includes('BlindAssist/MeshCandidateDiagnostics.swift')));
assert.ok([...removed, ...added].every(l=>/PBXFileReference|PBXBuildFile|PBXSourcesBuildPhase|PBXGroup/.test(l)));
assert.ok(![...removed, ...added].some(l=>/buildSettings|SWIFT_ACTIVE_COMPILATION_CONDITIONS|XCLocalSwiftPackageReference|XCSwiftPackageProductDependency|PBXFrameworksBuildPhase/.test(l)));
console.log(JSON.stringify({kind:'source-only-canonicalization', sourceMembershipCount:61,
 exactCurrentGeneratorParity:true, changedFileReferenceOnly:'MeshCandidateDiagnostics.swift',
 packageReferencesAndFrameworksUnchanged:true, buildFlagsUnchanged:true,
 currentSHA256:createHash('sha256').update(current).digest('hex'), nativeBuildExecuted:false},null,2));
