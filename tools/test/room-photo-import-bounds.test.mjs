import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const root=new URL('../../',import.meta.url),read=p=>readFileSync(new URL(p,root),'utf8');
const view=read('ios/BlindAssist/RoomDetailView.swift'),store=read('ios/BlindAssist/PlaceStore.swift'),decoder=read('ios/BlindAssist/SelectedPhotoDecoder.swift');
const section=(s,a,b)=>{const at=s.indexOf(a);assert.ok(at>=0,a);const end=s.indexOf(b,at+a.length);assert.ok(end>at,b);return s.slice(at,end)};
const load=section(view,'.task(id: photo)','private func refreshReferencePhoto');
function ownerContract(s){
 assert.match(s,/@MainActor private var referencePhotoImportLease: UUID\?/);
 const begin=section(s,'@MainActor func beginReferencePhotoImport()','@MainActor func finishReferencePhotoImport(');
 assert.match(begin,/guard referencePhotoImportLease == nil/);
 assert.ok(begin.indexOf('guard referencePhotoImportLease == nil')<begin.indexOf('referencePhotoImportLease = lease'));
 const finish=section(s,'@MainActor func finishReferencePhotoImport(','/// One recoverable reference-photo');
 assert.match(finish,/if referencePhotoImportLease == lease \{ referencePhotoImportLease = nil \}/);
}
test('store-scoped import lease is explicitly serialized and releases only exact owner',()=>{
 ownerContract(store);
 for(const mutant of [store.replace('@MainActor private var referencePhotoImportLease','private var referencePhotoImportLease'),store.replace('@MainActor func beginReferencePhotoImport()','func beginReferencePhotoImport()'),store.replace('guard referencePhotoImportLease == nil','guard true'),store.replace('if referencePhotoImportLease == lease { referencePhotoImportLease = nil }','referencePhotoImportLease = nil')])assert.throws(()=>ownerContract(mutant));
});
test('claim precedes allocation; cancelled UI waits for actual bounded detached worker',()=>{
 assert.match(load,/\.task\(id: photo\) \{ @MainActor in/);
 assert.ok(load.indexOf('store.beginReferencePhotoImport()')<load.indexOf('Task.detached'));
 assert.match(load,/defer \{ store.finishReferencePhotoImport\(lease\) \}/);
 assert.match(load,/await Task.detached\(priority: \.utility\) \{ \(\) -> Data\? in/);
 assert.match(load,/loadTransferable\(type: SelectedPhotoTransfer.self\)/);
 assert.doesNotMatch(load,/type: Data.self|CGImageSourceCreate|withTaskCancellationHandler|\.cancel\(\)/);
 assert.match(load,/\}\.value\s+try Task.checkCancellation\(\)/);
 assert.match(load,/self.photo = nil \/\/ Permit selecting the same item/);
});
test('existing cancellation, revision, selected-item and save-size fences remain',()=>{
 assert.equal((load.match(/guard revision == photoRevision, self.photo == photo/g)||[]).length,2);
 assert.ok(load.indexOf('guard revision == photoRevision, self.photo == photo')<load.indexOf('savePhoto(jpeg'));
 assert.match(load,/transfer.data.count <= 20_000_000/);
 assert.match(load,/decode\(transfer.data, maximumDecodedSide: 1200\)/);
 assert.match(store,/jpeg.count <= 2_000_000/);
});
test('same transfer caps file read before allocation and shared decoder only permits smaller output',()=>{
 assert.match(decoder,/FileRepresentation\(importedContentType: \.image\)/);
 assert.ok(decoder.indexOf('size <= SelectedPhotoReference.maximumEncodedBytes')<decoder.indexOf('handle.read(upToCount:'));
 assert.match(decoder,/maximumEncodedBytes \+ 1/);
 assert.match(decoder,/maximumDecodedSide > 0, maximumDecodedSide <= SelectedPhotoReference.maximumDecodedSide/);
 assert.match(decoder,/maximumDecodedSide: Int = SelectedPhotoReference.maximumDecodedSide/);
 assert.match(decoder,/CGImageSourceGetCount\(source\) == 1/);
 assert.ok(decoder.indexOf('maximumSourcePixels / height')<decoder.indexOf('CGImageSourceCreateThumbnailAtIndex'));
 assert.match(decoder,/image.width <= maximumDecodedSide/);assert.match(decoder,/image.height <= maximumDecodedSide/);
});
