// Bounded acquisition source contracts, not SwiftUI rendering or device accuracy.
import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,cpSync,existsSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';import {fileURLToPath} from 'node:url';import {tmpdir} from 'node:os';import {spawnSync} from 'node:child_process';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const read=p=>readFileSync(join(root,p),'utf8');
const section=(s,a,b)=>{const i=s.indexOf(a),j=s.indexOf(b,i);assert.ok(i>=0&&j>i);return s.slice(i,j)};
const before=(s,a,b)=>assert.ok(s.indexOf(a)>=0&&s.indexOf(b)>s.indexOf(a),a+' precedes '+b);
test('raw feature/corner bounds precede all conversion and no matching authority is invented',()=>{
 const s=section(read('ios/BlindAssist/RoomLayoutAdapter.swift'),'    static func registrationFeatures','    static func layout');
 before(s,'guard room.objects.count <= limit','var result:');before(s,'polygonCorners.count <= 16','var result:');
 assert.doesNotMatch(s,/nearest|confidence.*error|CompanionMemoryScope\(/);
});
test('held read selection rotates ownership and existing helper offers explicit bounded retry',()=>{
 const store=read('ios/BlindAssist/PlaceStore.swift');const load=section(store,'    @MainActor func loadRegistration','    func worldMap(');
 before(load,'registrationRequestID = request','guard !registrationSaving, !registrationLoading');
 before(load,'registrationSelectionPlaceID = place.id','guard !registrationSaving, !registrationLoading');
 assert.equal((load.match(/Task.detached/g)||[]).length,1);assert.doesNotMatch(load,/await loadRegistration|Task \{/);
 before(load,'guard registrationRequestID == request','registration = value');
 const ui=read('ios/BlindAssist/RoomDetailView.swift');const retry=section(ui,'            if places.registrationLoadNeedsRetry','            if !places.registrationStatus');
 assert.match(retry,/await places.loadRegistration\(for: place\)/);assert.match(retry,/disabled\(places.registrationLoading \|\| places.registrationSaving\)/);
});
test('held diagnostic read also disables helper saving',()=>{
 const ui=read('ios/BlindAssist/RoomDetailView.swift');
 const save=section(ui,'                Button(t("Save measurement record on this phone"','            if places.registrationLoadNeedsRetry');
 assert.match(save,/disabled\(places.registrationSaving \|\| places.registrationLoading\)/);
});
test('stale save completion cannot publish another selection status',()=>{
 const s=section(read('ios/BlindAssist/PlaceStore.swift'),'    @MainActor func saveRegistration','    @MainActor func loadRegistration');
 const fail=s.slice(s.indexOf('        } catch {'));before(fail,'registrationRequestID == request','registrationStatus =');before(fail,'self.memory?.writeOwner == owner','registrationStatus =');
 assert.doesNotMatch(s,/This save cannot be confirmed here/);assert.equal((s.match(/Task.detached/g)||[]).length,1);
});

test('scan preparation reuses bounded verified bytes off main and deletion retires before SQL',()=>{
 const store=read('ios/BlindAssist/PlaceStore.swift');
 const start=section(store,'    func startScan(','    /// Preparation reuses');
 assert.doesNotMatch(start,/worldMapArtifacts|JSONDecoder|Data\(contentsOf:/);
 const prep=section(store,'    private func prepareRegistrationBaseline','    func finishScan()');
 before(prep,'guard registrationPreparation == nil','Task { @MainActor');
 before(prep,'bytes.data.count <= Self.maximumRegistrationRoomBytes','Task { @MainActor');
 before(prep,'Task.detached(priority: .utility)','JSONDecoder().decode');
 before(prep,'self.registrationRequestID == request','self.registrationBaseline = baseline');
 const recover=section(store,'    func beginWorldMapRecovery','    func invalidateWorldMapRecovery');
 before(recover,'try worldMapArtifacts(for: place)','registrationBytes = RegistrationBytes');
 assert.match(recover,/artifacts.room.count <= Self.maximumRegistrationRoomBytes/);
 const erase=section(store,'    func retireRegistration(for place:','    func retryDeletionCleanup()');
 before(erase,'registrationRequestID = UUID()','try memory.deleteRoom');
 before(erase,'registrationBytes = nil','try memory.deleteRoom');
 const ingress=section(read('ios/BlindAssist/NavigationModel.swift'),'    func deletePlace(_ place:','    private func deletePlaceAfterNativePurge');
 before(ingress,'places.retireRegistration(for: place)','nativeObservations.clearHistory');
 const end=section(store,'    func captureSession(_ session: RoomCaptureSession, didEndWith','                let map: ARWorldMap');
 before(end,'let measurementRequest = registrationRequestID','processing = Task');
 before(end,'registrationRequestID == measurementRequest','registration = acquired');
 assert.match(end,/else if registrationRequestID == measurementRequest/);
});

test('actual registration acquisition and native ownership replay use real pinned GRDB',{
 skip:!process.env.BLIND_SWIFTC && 'Set BLIND_SWIFTC for executable native-source replay.',timeout:300_000,
},()=>{
 const grdb=process.env.BLIND_GRDB_PATH||join(root,'BlindMemory/.build/checkouts/GRDB.swift');
 assert.ok(existsSync(join(grdb,'Package.swift')),'Use an already-resolved pinned GRDB checkout via BLIND_GRDB_PATH; this runner does not download dependencies.');
 // Package.resolved is generated/ignored in this repository. Check the committed
 // exact-version manifest and the reviewed upstream revision, not a local lockfile.
 assert.match(read('BlindMemory/Package.swift'), /\.package\(url: "https:\/\/github\.com\/groue\/GRDB\.swift\.git", exact: "7\.11\.1"\)/);
 const expected='b83108d10f42680d78f23fe4d4d80fc88dab3212';
 const revision=spawnSync('git',['-C',grdb,'rev-parse','HEAD'],{encoding:'utf8'});
 assert.equal(revision.status,0,'Pinned checkout provenance must be readable');assert.equal(revision.stdout.trim(),expected);
 const work=process.env.BLIND_REGISTRATION_REPLAY_SCRATCH||mkdtempSync(join(process.env.BLIND_TEST_SCRATCH||tmpdir(),'blind-room-registration-'));
 mkdirSync(work,{recursive:true});
 const src=join(work,'Sources/AcquisitionReplay'),tests=join(work,'Tests/AcquisitionReplayTests'),memory=join(work,'BlindMemory');
 mkdirSync(src,{recursive:true});mkdirSync(tests,{recursive:true});mkdirSync(memory,{recursive:true});
 cpSync(join(root,'BlindMemory/Sources'),join(memory,'Sources'),{recursive:true});
 cpSync(join(root,'BlindMemory/Tests'),join(memory,'Tests'),{recursive:true});
 const packageText=read('BlindMemory/Package.swift').replace('.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")',`.package(path: ${JSON.stringify(grdb)})`);
 assert.ok(!packageText.includes('.package(url:'));writeFileSync(join(memory,'Package.swift'),packageText);
 const fixture='tools/test/fixtures/room-registration-acquisition/';const nav=read('ios/BlindAssist/NavigationModel.swift'),store=read('ios/BlindAssist/PlaceStore.swift'),adapter=read('ios/BlindAssist/RoomLayoutAdapter.swift');
 writeFileSync(join(src,'Native.swift'),read(fixture+'ControllerPrefix.swift')+section(store,'    func startScan(','    func finishScan()')+section(store,'    func cancelScan()','    /// User-facing cancellation')+section(store,'    func retireRegistration(for place:','    func retryDeletionCleanup()')+section(store,'    func observeRegistrationFrame(','    func worldMap(for place: SavedPlace)')+'}\nenum RoomLayoutAdapter {\n'+section(adapter,'    static func registrationFeatures(','    static func layout(')+'}\n');
 writeFileSync(join(src,'ControlledStore.swift'),read(fixture+'ControlledStore.swift'));
 writeFileSync(join(src,'NativeDeletion.swift'),read(fixture+'NativeDeletionPrefix.swift')+section(nav,'    func deletePlace(_ place:','    private func deletePlaceAfterNativePurge')+'}\n');
 writeFileSync(join(src,'WorkingState.swift'),'import Foundation\nimport BlindCore\n'+section(read('ios/BlindAssist/LocalImageAssistant.swift'),'struct CompanionTaskUpdate:','\n#if canImport(FoundationModels)'));
 writeFileSync(join(src,'HistoryController.swift'),'import Foundation\nimport BlindCore\nfinal class HistoryController { var companionWorkingState = CompanionWorkingState()\n'+section(nav,'    /// Explicit saved-place selection','    var scopedConversationReviews:')+'}\n');
 const cases=read(fixture+'AcquisitionTests.swift');assert.equal((cases.match(/func testA\d{3}/g)||[]).length,31);writeFileSync(join(tests,'AcquisitionTests.swift'),cases);
 writeFileSync(join(work,'Package.swift'),`// swift-tools-version: 5.9\nimport PackageDescription\nlet package=Package(name:"AcquisitionReplay",dependencies:[.package(path:${JSON.stringify(join(root,'BlindCore'))}),.package(path:${JSON.stringify(memory)})],targets:[.target(name:"AcquisitionReplay",dependencies:[.product(name:"BlindCore",package:"BlindCore"),.product(name:"BlindMemory",package:"BlindMemory")]),.testTarget(name:"AcquisitionReplayTests",dependencies:["AcquisitionReplay",.product(name:"BlindCore",package:"BlindCore"),.product(name:"BlindMemory",package:"BlindMemory")])])\n`);
 const args=['test','--package-path',work,'--jobs','2'];
 if(process.env.SQLITE_TEST_SDK)args.push('-Xcc','-I'+join(process.env.SQLITE_TEST_SDK,'include'),'-Xlinker','-L'+join(process.env.SQLITE_TEST_SDK,'lib'));
 const result=spawnSync(join(dirname(process.env.BLIND_SWIFTC),'swift'),args,{encoding:'utf8',timeout:290_000,maxBuffer:8*1024*1024});
 const output=(result.stdout||'')+'\n'+(result.stderr||'');writeFileSync(join(work,'execution-'+Date.now()+'.log'),output);
 assert.equal(result.status,0,`Replay retained at ${work}\n${output.slice(-14000)}`);assert.match(output,/Executed 31 tests, with 0 failures/);
});
