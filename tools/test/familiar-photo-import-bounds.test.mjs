import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const root=new URL('../../',import.meta.url),read=p=>readFileSync(new URL(p,root),'utf8');
const controller=read('ios/BlindAssist/FamiliarFaceExperiment.swift'),view=read('ios/BlindAssist/FamiliarPeopleView.swift');
function method(s,name){const at=s.indexOf('func '+name+'(');assert.ok(at>=0,name);const start=s.lastIndexOf('\n',at)+1;let end=s.indexOf('{',at)+1,depth=1;while(depth&&end<s.length){if(s[end]==='{')depth++;if(s[end]==='}')depth--;end++}assert.equal(depth,0);return s.slice(start,end)}
function check(s){
 const begin=method(s,'importSelectedPhotos'),cancel=method(s,'cancelSelectedPhotoImport'),inspect=method(s,'inspectSelectedPhoto');
 assert.match(s,/@MainActor private var photoImportLease: UUID\?/);
 assert.match(begin,/@MainActor @discardableResult func importSelectedPhotos/);
 for(const guard of ['photoImportLease == nil','draft?.token == enrollmentToken','photos.count <= 6','photos.count <= remainingExamples'])assert.ok(begin.includes(guard),guard);
 assert.ok(begin.indexOf('photoImportLease = lease')<begin.indexOf('Task {'));
 assert.match(begin,/if self.photoImportLease == lease \{\s+self.photoImportLease = nil/);
 assert.doesNotMatch(cancel,/photoImportLease = nil|photoImportInFlight = false/);
 assert.match(cancel,/photoImportRevision = UUID\(\)/);
 assert.match(begin,/for \(index, item\) in photos.enumerated\(\)/);
 assert.match(begin,/await inspectSelectedPhoto\(item, lease: lease, revision: revision/);
 assert.equal((begin.match(/draft\?\.token == enrollmentToken/g)||[]).length,3);
 assert.equal((begin.match(/photoImportRevision == revision/g)||[]).length,2);
 assert.ok(begin.lastIndexOf('photoImportRevision == revision')<begin.indexOf('try accept(result'));
 assert.match(inspect,/@MainActor private func inspectSelectedPhoto/);
 assert.match(inspect,/loadTransferable\(type: SelectedPhotoTransfer.self\)/);
 for(const token of ['}.value', 'guard photoImportLease == lease', 'photoImportRevision == revision', 'generation == ownerGeneration', 'enabled', 'draft?.token == enrollmentToken', 'inference.inspectPhoto'])assert.ok(inspect.includes(token),token);
 assert.ok(inspect.indexOf('}.value')<inspect.indexOf('guard photoImportLease == lease'));
 assert.ok(inspect.indexOf('draft?.token == enrollmentToken')<inspect.indexOf('inference.inspectPhoto'));
 assert.match(inspect,/loaded.data.count <= 20_000_000/);
 assert.doesNotMatch(begin+inspect,/\[Data\]|withTaskGroup|withThrowingTaskGroup|URLSession|\.write\(/);
}
test('one experiment-owned lane serializes bounded originals through transfer and inference',()=>check(controller));
test('replacement and view cancellation retire publication but not physical ownership',()=>{
 assert.match(view,/@MainActor private func cancelPhotoLoad/);
 assert.match(method(view,'cancelPhotoLoad'),/experiment.cancelSelectedPhotoImport\(\)/);
 assert.match(view,/private var photoLoading: Bool \{ experiment.photoImportInFlight \}/);
 assert.doesNotMatch(view,/photoTask|photoGeneration|loadTransferable|\[Data\]/);
 const load=method(view,'loadPhotos');assert.ok(load.indexOf('cancelSelectedPhotoImport()')<load.indexOf('importSelectedPhotos('));
 assert.match(load,/selectedPhotos = \[\]/);
 assert.match(view,/\.onDisappear \{[^\n]*cancelPhotoLoad\(\); experiment.leaveEnrollmentScreen\(\)/);
});
test('existing file transfer checks metadata before bounded read; default-off flag stays intact',()=>{
 const decoder=read('ios/BlindAssist/SelectedPhotoDecoder.swift');
 assert.ok(decoder.indexOf('size <= SelectedPhotoReference.maximumEncodedBytes')<decoder.indexOf('handle.read(upToCount:'));
 assert.match(decoder,/maximumEncodedBytes \+ 1/);assert.match(decoder,/data.count == size/);
 assert.ok(controller.startsWith('#if BLIND_FAMILIAR_PEOPLE\n'));assert.ok(view.startsWith('#if BLIND_FAMILIAR_PEOPLE\n'));
});
test('authored cancellation harness contains exact production ownership methods, not an alternative gate',()=>{
 const fixture=read('BlindCore/Tests/BlindCoreTests/FamiliarPhotoImportOwnershipTests.swift');
 for(const name of ['cancelSelectedPhotoImport','importSelectedPhotos','inspectSelectedPhoto'])assert.equal(method(fixture,name),method(controller,name));
 assert.equal((fixture.match(/func test/g)||[]).length,8);
 assert.doesNotMatch(fixture,/import PhotosUI|import UIKit|BAFaceEngine|FamiliarFaceStore\(/);
});
test('negative mutations reject early release, unbounded loading and missing consent/owner fences',()=>{
 const mutations=[
  controller.replace('@MainActor private var photoImportLease','private var photoImportLease'),
  controller.replace('@MainActor @discardableResult func importSelectedPhotos','@discardableResult func importSelectedPhotos'),
  controller.replace('photoImportLease == nil','true'),
  controller.replace('func cancelSelectedPhotoImport() { photoImportRevision = UUID() }','func cancelSelectedPhotoImport() { photoImportRevision = UUID(); photoImportLease = nil }'),
  controller.replace('loadTransferable(type: SelectedPhotoTransfer.self)','loadTransferable(type: Data.self)'),
  controller.replace('loaded.data.count <= 20_000_000','true'),
  controller.replace('generation == ownerGeneration, enabled, draft?.token == enrollmentToken','generation == ownerGeneration, enabled'),
  controller.replaceAll('photoImportRevision == revision','true'),
  controller.replace('if self.photoImportLease == lease {','if true {'),
  controller.replace('photos.count <= 6','true')
 ];
 for(const mutation of mutations)assert.throws(()=>check(mutation),{name:'AssertionError'});
});
