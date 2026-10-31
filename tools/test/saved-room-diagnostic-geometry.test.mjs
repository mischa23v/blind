// Source contracts only. Native RoomPlan decoding/Swift behavior need Apple execution.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { declaration, frameSignature, withoutComments } from './helpers/navigation-source-contract.mjs';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
const core = read('BlindCore/Sources/BlindCore/SavedRoomDiagnosticGeometry.swift');
const native = read('ios/BlindAssist/SavedRoomDiagnosticGeometryProvider.swift');
const store = read('ios/BlindAssist/PlaceStore.swift');
const nav = read('ios/BlindAssist/NavigationModel.swift');
const before = (s, a, b) => assert.ok(s.includes(a) && s.indexOf(a) < s.indexOf(b), `${a} before ${b}`);

test('native geometry uses all original source groups and measurements, not inflated layout or matcher prefix', () => {
  const extract = declaration(native, 'static func extract(');
  const check = s => {
    for (const [kind, group] of [['floor','floors'],['wall','walls'],['door','doors'],['window','windows'],['opening','openings']]) {
      assert.ok(s.includes(`(.${kind}, room.${group})`), group);
      assert.ok(s.includes(`${group}: room.${group}.count`), `${group} source count`);
    }
    assert.match(s, /furniture: room\.objects\.count/);
    assert.match(s, /features \+= room\.objects\.map/);
    assert.match(s, /transform: NativeARObservationAdapter\.transform\(surface\.transform\)/);
    assert.match(s, /Point3\(Double\(surface\.dimensions\.x\), Double\(surface\.dimensions\.y\), Double\(surface\.dimensions\.z\)\)/);
    assert.match(s, /polygonCorners: surface\.polygonCorners\.map/);
    assert.match(s, /transform: NativeARObservationAdapter\.transform\(object\.transform\)/);
    assert.match(s, /Point3\(Double\(object\.dimensions\.x\), Double\(object\.dimensions\.y\), Double\(object\.dimensions\.z\)\)/);
    assert.doesNotMatch(withoutComments(s), /\.prefix\(|RoomRegistrationAcquisition|RoomLayoutAdapter|0\.06|\.identity/);
  };
  check(extract);
  for (const [from,to] of [['(.window, room.windows)','(.window, [])'], ['features += room.objects.map','features += room.objects.prefix(32).map'],
    ['Double(surface.dimensions.z)','0.06'], ['Double(object.dimensions.y)','0'], ['surface.polygonCorners.map','[].map']]) {
    assert.ok(extract.includes(from)); assert.throws(() => check(extract.replace(from,to)), { name: 'AssertionError' });
  }
  assert.match(read('BlindCore/Sources/BlindCore/RoomRegistrationAcquisition.swift'), /maximumFeatures = 32/);
});

test('whole source and geometry bounds reject unsupported documents without truncation', () => {
  assert.match(native, /maximumSourceBytes = 8 \* 1024 \* 1024/);
  const extract = declaration(native, 'static func extract(');
  before(extract, 'guard counts.withinBounds', 'var features:');
  before(extract, 'cornerCount <= Geometry.maximumTotalCorners', 'var features:');
  assert.match(extract, /surface\.polygonCorners\.count <= Geometry\.maximumCornersPerFeature else \{ throw Failure\.unsupported \}/);
  for (const [name, value] of [['maximumFeatures', '512'], ['maximumCornersPerFeature', '1_024'], ['maximumTotalCorners', '16_384']]) {
    assert.ok(core.includes(`${name} = ${value}`));
  }
  const validation = declaration(core, 'public func validate()');
  assert.match(validation, /sourceCounts\.total == features\.count/);
  assert.match(validation, /Set\(features\.map\(\\.id\)\)\.count == features\.count/);
  assert.match(validation, /Kind\.allCases\.allSatisfy/);
  assert.match(validation, /throw Failure\.unsupportedSize/);
  assert.doesNotMatch(withoutComments(core), /\.prefix\(|max\(0\.06/);
});

test('original room bytes are hash bound and deletion checked on both sides of utility decoding', () => {
  const load = declaration(native, 'static func load(');
  assert.equal((load.match(/isDeleted\(room: source\.frame\.placeID\)/g) ?? []).length, 2);
  assert.match(load, /SpatialMapFileStorage\.readBounded\(source\.url, maximumBytes: maximumSourceBytes\)/);
  before(load, 'isDeleted(', 'let geometry = try decode(');
  assert.ok(load.lastIndexOf('isDeleted(') > load.indexOf('let geometry = try decode('));
  const decode = declaration(native, 'static func decode(');
  before(decode, 'data.count <= maximumSourceBytes', 'JSONDecoder().decode(CapturedRoom.self');
  before(decode, '== frame.roomCaptureSHA256', 'JSONDecoder().decode(CapturedRoom.self');
  assert.doesNotMatch(withoutComments(native), /ARSession\(|URLSession|sourceToMap|acceptRegistered|acceptConnected|\.speak\(/);
});

test('provider has one worker one latest selection and final ownership CAS', () => {
  const drain = declaration(native, 'private func drain()');
  assert.match(drain, /guard activeWorker == nil, let work = pending else \{ return \}/);
  assert.match(drain, /pending = nil/);
  before(drain, 'await Task.detached(priority: .utility)', 'self.selectedID == work.selectionID');
  before(drain, 'ownsDiagnosticGeometrySource(work.source) == true', 'self.geometry = geometry');
  before(drain, 'geometry.frame == work.source.frame', 'self.geometry = geometry');
  assert.match(drain, /self\.selected == work\.source\.frame/);
  const select = declaration(native, 'func select(');
  assert.match(select, /selected == frame/);
  assert.match(select, /ownsDiagnosticGeometrySource\(source\) != true/);
  assert.doesNotMatch(withoutComments(select), /Data\(|\.read\(|JSONDecoder|SHA256|isDeleted\(/);
  const cancel = declaration(native, 'func cancel()');
  assert.match(cancel, /selectedID = UUID\(\); pending = nil; publishedSource = nil; geometry = nil; status = \.idle/);
  assert.doesNotMatch(cancel, /activeWorker = nil/);
});

test('actual PlaceStore source and user deletion admission fence geometry before asynchronous erasure', () => {
  const source = declaration(store, '@MainActor func diagnosticGeometrySource(');
  assert.match(source, /!diagnosticGeometryBlockedPlaces\.contains\(id\)/);
  assert.match(source, /\$0\.id == id && \$0\.worldFrame == frame/);
  assert.doesNotMatch(withoutComments(source), /Data\(|JSONDecoder|SHA256|\.read\(/);
  const owns = declaration(store, '@MainActor func ownsDiagnosticGeometrySource(');
  assert.match(owns, /memory === source\.memory, memory\.writeOwner == source\.memoryOwner/);
  assert.match(owns, /diagnosticGeometryDeletionGeneration == source\.deletionGeneration/);
  assert.match(owns, /\$0\.worldFrame == source\.frame/);
  const deletion = declaration(nav, 'func deletePlace(');
  before(deletion, 'places.retireDiagnosticGeometry(for: place)', 'nativeObservations.clearHistory(');
  before(declaration(store, 'func delete(_ place:'), 'retireDiagnosticGeometry(for: place)', 'memory.deleteRoom(');
});

test('native recorder receives only this exact frame receipt and one existing provider', () => {
  const frame = declaration(nav, frameSignature);
  assert.match(frame, /sameFrameAssociation: places\.cameraWorldFrameAssociation\(sessionID: nativeSessionID,\s*capturedAt: frame\.timestamp, now: ProcessInfo\.processInfo\.systemUptime\)/);
  assert.match(frame, /nativeObservations\.offer\(frame, sessionID: nativeSessionID,/);
  assert.match(nav, /private lazy var savedRoomDiagnosticGeometry = SavedRoomDiagnosticGeometryProvider\(places: places\)/);
  const factory = declaration(nav, '@MainActor func makeNavigationTestRecordingView()');
  assert.match(factory, /geometryProvider: savedRoomDiagnosticGeometry/);
  assert.doesNotMatch(factory, /ARSession\(|NativeARObservationBridge\(/);
  assert.match(core, /permitsPhysicalGuidance: Bool \{ false \}/);
});
