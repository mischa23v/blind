// Source/provenance checks, NOT execution of Apple's RoomPlan decoder or Swift.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { declaration, withoutComments } from './helpers/navigation-source-contract.mjs';
const read = path => readFileSync(new URL(`../../${path}`, import.meta.url));
const directory = 'ios/BlindAssistTests/Fixtures/RoomPlanApple/';
const manifest = JSON.parse(read(`${directory}manifest.json`));
const swift = read('ios/BlindAssistTests/SavedRoomDiagnosticGeometryAppleFixtureTests.swift').toString();
const sha256 = value => createHash('sha256').update(value).digest('hex');
const pins = [
  ['Hallway2.capturedRoom.json', 27575, 'f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d', [6,6,1,0,0,0]],
  ['Bedroom3.capturedRoom.json', 69516, '44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e', [4,2,1,1,0,3]],
];

test('two untouched Apple original room JSON blobs retain exact official provenance and license', () => {
  assert.equal(manifest.official_archive_url, 'https://developer.apple.com/tutorials/3e2b731b0ef7/MergingMultipleScansIntoASingleStructure.zip');
  assert.equal(manifest.official_archive_sha256, '135cf2ae9c415723f9f32c31a130b4ce9efced61b3e22f50858785a4323d66a1');
  for (const [file, size, digest, counts] of pins) {
    const bytes = read(`${directory}${file}`), entry = manifest.fixtures.find(row => row.file === file);
    assert.equal(bytes.length, size); assert.equal(sha256(bytes), digest);
    assert.equal(entry.bytes, size); assert.equal(entry.sha256, digest);
    assert.equal(entry.mirror_commit, 'cc5cb5fa1cd177b626a774f4b79846bc2fb00cb0');
    const room = JSON.parse(bytes);
    assert.equal(room.version, 2); assert.equal(room.story, 0);
    assert.ok(room.coreModel, 'Original opaque native payload retained');
    assert.deepEqual(['walls','doors','floors','windows','openings','objects'].map(kind => room[kind].length), counts);
    assert.ok(swift.includes(digest), 'Native fixture pin matches immutable source');
  }
  const license = read(`${directory}APPLE-LICENSE.txt`);
  assert.equal(sha256(license), 'ef80d1c2ac05c7040c0ced9d603c2c359712f90fdb3ece8da70b976981a69e89');
  assert.match(license.toString(), /Copyright © 2025 Apple Inc\./);
});

test('native fixtures call actual framework decoder and production extractor over every original field', () => {
  const decode = declaration(swift, 'func testBothOriginalAppleRoomsDecodeThroughNativeFrameworkAndProductionExtractor()');
  assert.match(decode, /for fixture in Fixture\.allCases/);
  assert.match(decode, /JSONDecoder\(\)\.decode\(CapturedRoom\.self, from: data\)/);
  assert.match(decode, /SavedRoomDiagnosticGeometryDecoder\.decode\(data, frame: frame\)/);
  const fields = declaration(swift, 'private func assertEveryOriginalField(');
  const check = text => {
    for (const token of ['raw.groups', 'original.identifier', 'feature.kind, kind', 'feature.category',
      'feature.dimensions, original.dimensions', 'feature.transform.columns, original.transform',
      'feature.polygonCorners, corners', 'polygon.points, corners', 't[4+r] * corner[1]',
      't[8+r] * corner[2]', 'geometry.permitsPhysicalGuidance']) assert.ok(text.includes(token), token);
  };
  check(fields);
  for (const token of ['feature.dimensions, original.dimensions', 'feature.transform.columns, original.transform',
    'feature.polygonCorners, corners', 't[8+r] * corner[2]']) {
    assert.throws(() => check(fields.replace(token, 'omitted')), { name: 'AssertionError' });
  }
  assert.doesNotMatch(withoutComments(fields), /NativeARObservationAdapter|NativeCameraTransform\.applying|\.prefix\(/);
  assert.match(swift, /Bundle\(for: Self\.self\)\.url/);
  assert.match(swift, /subdirectory: "RoomPlanApple"/);
});

test('fixed furnished-room projection witnesses derive from original full transform and real depth', () => {
  const room = JSON.parse(read(`${directory}Bedroom3.capturedRoom.json`));
  const floor = room.floors.find(row => row.identifier === 'B95427E8-846F-4367-A2DA-87892E259635');
  const world = floor.polygonCorners.map(point => [0,1,2].map(r =>
    floor.transform[r]*point[0] + floor.transform[4+r]*point[1] + floor.transform[8+r]*point[2] + floor.transform[12+r]));
  const expected = [[2.323137373056058,-1.465985,16.703357492181844],
    [-1.185866286299784,-1.465985,16.205300397357025],
    [-0.7174753508629721,-1.465985,12.905301991829168],
    [2.791528137945333,-1.465985,13.403358153426467]];
  for (let i=0;i<world.length;i++) for (let axis=0;axis<3;axis++) assert.ok(Math.abs(world[i][axis]-expected[i][axis]) < 1e-12);
  assert.deepEqual(room.objects.map(row => Object.keys(row.category)[0]).sort(), ['bed','chair','table']);
  const bed = room.objects.find(row => row.identifier === '45597D99-3218-4419-A2E4-2ADFA824D033');
  assert.deepEqual(bed.dimensions, [1.6728522,0.6448028,2.1749296]);
  for (const token of ['2.323137373056058','16.205300397357025','12.905301991829168','2.1749296','14.552343561668101']) assert.ok(swift.includes(token));
});

test('real-byte default provider fixture does not inject geometry and rejects mismatched room binding', () => {
  const provider = declaration(swift, 'func testDefaultProviderReadsOriginalRoomAndRetiresAtDeletionAdmission()');
  assert.match(provider, /try bytes\(\.bedroom\)\.write/);
  assert.match(provider, /SavedRoomDiagnosticGeometryProvider\(places: store\)/);
  assert.doesNotMatch(withoutComments(provider), /loader:|\.success\(|SavedRoomDiagnosticGeometry\(/);
  assert.match(provider, /guard !provider\.hasPendingWork else \{ XCTFail\("Native decode did not complete"\); throw Failure\.timeout \}/);
  assert.match(provider, /provider\.status, \.ready/);
  assert.match(provider, /store\.retireDiagnosticGeometry\(for: place\)/);
  assert.match(provider, /provider\.status, \.unavailable/);
  const mismatch = declaration(swift, 'func testRealSourceHashMismatchIsRejectedInsteadOfBorrowingOtherRoom()');
  assert.match(mismatch, /decode\(bytes\(\.bedroom\), frame: syntheticDescriptor\(\.hallway\)\)/);
  assert.match(mismatch, /\.sourceMismatch/);
  assert.match(swift, /descriptor below is SYNTHETIC test metadata/);
});

test('native room UUID is same-instance metadata, not a stable cross-decode source key', () => {
  for (const [file] of pins) assert.equal(Object.hasOwn(JSON.parse(read(`${directory}${file}`)), 'identifier'), false);
  const check = source => {
    const decode = declaration(source, 'func testBothOriginalAppleRoomsDecodeThroughNativeFrameworkAndProductionExtractor()');
    assert.match(decode, /let sameNativeRoom = try SavedRoomDiagnosticGeometryDecoder\.extract\(room, frame: frame\)/);
    assert.match(decode, /XCTAssertEqual\(sameNativeRoom\.capturedRoomID, room\.identifier\)/);
    assert.doesNotMatch(withoutComments(decode), /XCTAssertEqual\(geometry\.capturedRoomID, room\.identifier\)/);
    assert.match(decode, /XCTAssertEqual\(nativeCounts, fixture\.counts\)/);
    for (const group of ['floors','walls','doors','windows','openings','objects']) assert.ok(decode.includes(`room.${group}.count`));
    const repeat = declaration(source, 'func testRepeatedOriginalDecodesBindStableSourceAndFeaturesNotRoomUUID()');
    assert.match(repeat, /XCTAssertNil\(original\["identifier"\]\)/);
    assert.equal((repeat.match(/SavedRoomDiagnosticGeometryDecoder\.decode\(data, frame: frame\)/g) ?? []).length, 2);
    for (const property of ['frame','story','sourceCounts','features','polylines']) {
      assert.ok(repeat.includes(`XCTAssertEqual(first.${property}, second.${property})`), property);
    }
    assert.match(repeat, /XCTAssertEqual\(second\.frame\.roomCaptureSHA256, fixture\.digest\)/);
    assert.doesNotMatch(withoutComments(repeat), /capturedRoomID|XCTAssertEqual\(first, second\)/);
  };
  check(swift);
  for (const [from,to] of [
    ['SavedRoomDiagnosticGeometryDecoder.extract(room, frame: frame)', 'SavedRoomDiagnosticGeometryDecoder.decode(data, frame: frame)'],
    ['XCTAssertEqual(geometry.frame, frame)', 'XCTAssertEqual(geometry.capturedRoomID, room.identifier)'],
    ['XCTAssertEqual(first.features, second.features)', 'XCTAssertEqual(first, second)'],
    ['XCTAssertEqual(second.frame.roomCaptureSHA256, fixture.digest)', 'XCTAssertTrue(true)'],
  ]) {
    assert.ok(swift.includes(from)); assert.throws(() => check(swift.replace(from,to)), { name: 'AssertionError' });
  }
  const provider = read('ios/BlindAssist/SavedRoomDiagnosticGeometryProvider.swift').toString();
  const view = read('ios/BlindAssist/NavigationTestRecordingView.swift').toString();
  assert.match(provider, /geometry\.frame == work\.source\.frame/);
  assert.match(view, /recording\.sameFrameSegments\(for: geometry\.frame\)/);
  assert.doesNotMatch(withoutComments(provider + view), /\.capturedRoomID/);
});
