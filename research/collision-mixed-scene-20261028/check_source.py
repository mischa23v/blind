#!/usr/bin/env python3
"""Lightweight source invariants; NOT Swift parsing/typechecking or physics."""
import hashlib, json, re
from pathlib import Path
root = Path(__file__).resolve().parents[2]
paths = [root/'ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift',root/'ios/BlindAssistTests/SavedRoomRouteCollisionOracleTests.swift']
s,t = [p.read_text() for p in paths]
checks=[]
def check(name, passed): checks.append({'name':name,'passed':bool(passed)})
def sha(x): return hashlib.sha256(x.encode()).hexdigest()
def section(x,a,b): return x[x.index(a):x.index(b,x.index(a))]
check('typed_SIMD_repair_unchanged',sha(section(s,'    private static func rigidTransform(','    private enum QueryMode:').rstrip())=='a83710da9ac0bc3c47d1dc9670636c2b993be635dc9fc4a424f35d11f65e2d13')
check('six_original_test_bodies_unchanged',sha(t[t.index('    private func wallAndFloor()'):].rstrip())=='74e01edaaed4c34bb85de33979265004b2c9887df8a2d6285ee9e79edab79e20')
check('ten_original_control_queries_and_predicates_unchanged',sha(s[s.index('    private static func runControl('):].rstrip())=='78c9217d975cf61ff823deede1f29098a9d4c1994f8c00c0e386146ebb8a24e9')
check('external_candidate_separated_and_gated','configuration: .candidate, queryMode: .separated, checkBackend: true' in s and 'if checkBackend { try Self.verifyBackend(configuration: configuration, queryMode: queryMode) }' in s)
check('all_original_and_mixed_controls_gate_readiness',all(x in s for x in ['let original = backendQueries(configuration: configuration, queryMode: queryMode)','let mixed = mixedSceneQueries(layout: .wallAndFloor, queryMode: queryMode)','Set((original + mixed).filter { !$0.passed }.map(\\.name))','guard failures.isEmpty else {','throw Failure.backendUnavailable("backend controls failed: " +']))
check('existing_v1_matrix_stays_combined','let queries = backendQueries(configuration: configuration, queryMode: .combined)' in s)
check('category_masks_distinct_and_union_probe',all(x in s for x in ['private let sourceMask = 1','private let probeMask = 2','queryMode == .separated ? 4 : sourceMask','sourceMask | floorMask','queryMode == .separated ? [sourceMask, floorMask] : [sourceMask]','body.categoryBitMask = kind == .floorSurface ? floorMask : sourceMask','body.collisionBitMask = allSourceMask; body.contactTestBitMask = allSourceMask']))
check('default_source_collision_mask_retained','if configuration.restrictsSourceMask { body.collisionBitMask = probeMask }' in s)
check('every_phase_queries_both_categories',s.count('for mask in queryMasks {')==2 and 'swept.formUnion(try contacts(raw))' in s and 'result.formUnion(try contacts(scene.physicsWorld.contactTest' in s)
check('same_full_cylinder_and_transforms','SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))' in s and 'convexSweepTest(with: shape, from: SCNMatrix4(start), to: SCNMatrix4(end)' in s)
check('all_three_zero_collision_margins',s.count('.collisionMargin: 0.0')==3)
check('two_sided_all_contact_search_retained','.backfaceCulling: false' in s and 'SCNPhysicsWorld.TestSearchMode.all' in s)
check('no_dynamic_bodies_or_paused_world','SCNPhysicsBody(type: .dynamic' not in s and 'scene.physicsWorld.speed = 1' in s and 'scene.physicsWorld.gravity = SCNVector3Zero' in s and 'scene.isPaused = false' in s)
check('original_triangles_all_installed','for group in groups.keys.sorted' in s and 'for box in furnitureBoxes' in s and 'add(shape: shape, id: group.id, kind: group.floor ? .floorSurface : .obstacleSurface' in s)
mixed=section(s,'    private static func mixedSceneQueries(','    private static func runMixedControl(')
fixture=section(t,'    private func wallAndFloor()','    func testThinWallSweep')
nums=lambda x: re.findall(r'-?\d+(?:\.\d+)?',x)
check('mixed_vertices_match_failed_fixture',nums(re.search(r'vertices:\s*\[([^]]+)\]',mixed).group(1))==nums(re.search(r'vertices:\s*\[([^]]+)\]',fixture).group(1)))
check('mixed_triangles_match_failed_fixture',nums(re.search(r'triangles: includeFloor \? \[([^]]+)\]',mixed).group(1))==nums(re.search(r'triangles:\s*\[([^]]+)\]',fixture).group(1)))
check('fixed_four_layout_query_cells','[(MixedLayout, QueryMode)] = [(.wallOnly, .combined), (.wallAndFloor, .combined),\n            (.wallOnly, .separated), (.wallAndFloor, .separated)]' in s)
check('fixed_six_controls','[.thinWallForward, .thinWallReverse,\n        .wallInitialOverlap, .wallTerminalOverlap, .clear, .floor]' in s)
check('same_radius_height_no_floor_lift','oracle.sweep(from: from, to: to, radius: 0.2, height: 1.6)' in section(s,'    private static func runMixedControl(','    private static func runControl('))
check('unexpected_floor_in_wall_only_fails','layout == .wallOnly ? all.floorSurfaceIDs.isEmpty : all.floorSurfaceIDs.isSubset(of: [mixedFloor])' in s)
check('mixed_floor_contact_required','result.initial.floorSurfaceIDs == [mixedFloor] && result.terminal.floorSurfaceIDs == [mixedFloor]' in s)
check('error_empty_and_failclosed','let empty = ContactWitness(Contacts())' in s and 'passed: false, errorCode: code' in s and 'initial: empty, swept: empty, terminal: empty' in s)
newtest=section(t,'    func testMixedSceneCombinedAndSeparatedQueriesRecordEveryPhase()','    private func wallAndFloor()')
check('mixed_witness_kept_before_assertion','SavedRoomCollisionMixedScene-v1.json' in newtest and 'attachment.lifetime = .keepAlways' in newtest and newtest.index('add(attachment)')<newtest.index('XCTAssertEqual(witness.cells'))
check('diagnostic_bounded_and_separated_cells_asserted','XCTAssertLessThanOrEqual(data.count, 131_072)' in newtest and 'if cell.queryMode == "separated" {' in newtest and 'XCTAssertTrue(cell.backendReady' in newtest)
result={'kind':'source-contracts-not-Swift-compilation','baselineCommit':'6fe9d5270f23954fa59fc3509cccf23445cefa51','checks':checks,'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks),'nativeExecution':'not-run-no-Apple-SDK-Xcode','sourceSHA256':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
print(json.dumps(result,indent=2));raise SystemExit(bool(result['failed']))
