#!/usr/bin/env python3
"""Bounded source assertions only. Does not compile Swift or execute SceneKit."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source_path = root / "ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift"
tests_path = root / "ios/BlindAssistTests/SavedRoomRouteCollisionOracleTests.swift"
source, tests = source_path.read_text(), tests_path.read_text()
checks = []
def check(name, condition):
    checks.append({"name": name, "passed": bool(condition)})
def section(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]
def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()

rigid = section(source, "    private static func rigidTransform(", "    private enum BackendConfiguration:").rstrip()
check("dc32_typed_SIMD_transform_repair_unchanged", sha(rigid) == "a83710da9ac0bc3c47d1dc9670636c2b993be635dc9fc4a424f35d11f65e2d13")
check("all_six_existing_tests_unchanged", sha(tests[tests.index("    private func wallAndFloor()"):].rstrip()) == "74e01edaaed4c34bb85de33979265004b2c9887df8a2d6285ee9e79edab79e20")
check("retained_renderer_and_deterministic_clock", all(x in source for x in ["private var renderer: SCNRenderer?", "renderer = retained", "retained.update(atTime: 0)", "simulationTick += 1", "renderer.update(atTime: TimeInterval(simulationTick) * Self.physicsTimeStep)"]))
check("unpaused_zero_gravity_world", all(x in source for x in ["scene.isPaused = false", "scene.physicsWorld.speed = 1", "scene.physicsWorld.gravity = SCNVector3Zero", "retained.isPlaying = true"]) and "scene.physicsWorld.speed = 0" not in source)
check("static_and_kinematic_only", source.count("SCNPhysicsBody(type: .static") == 1 and source.count("SCNPhysicsBody(type: .kinematic") == 1 and "SCNPhysicsBody(type: .dynamic" not in source)
check("candidate_does_not_override_source_collision_mask", "if configuration.restrictsSourceMask { body.collisionBitMask = probeMask }" in source and "static let candidate = BackendConfiguration.defaultOffscreenRenderer" in source)
check("explicit_query_source_mask_retained", source.count("options: [.collisionBitMask: sourceMask") == 2)
check("zero_collision_margin_all_three_shapes", source.count(".collisionMargin: 0.0") == 3)
check("full_cylinder_dimensions_unchanged", "SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))" in source)
sweep = section(source, "    func sweep(", "    private func overlap(")
check("initial_continuous_swept_terminal_order_retained", sweep.index("let initial = try overlap") < sweep.index("convexSweepTest") < sweep.index("let terminal = try overlap"))
check("both_backfaces_and_all_contacts_retained", ".backfaceCulling: false" in sweep and "SCNPhysicsWorld.TestSearchMode.all" in sweep)
check("mandatory_fail_closed_control_gate", "configuration: .candidate, checkBackend: true" in source and "if checkBackend { try Self.verifyBackend(configuration: configuration) }" in source and "guard witness.backendReady else" in source and 'throw Failure.backendUnavailable("backend controls failed: " +' in source)
check("matrix_exact_four_cells", all(x in source for x in ['"restricted-no-renderer"', '"default-no-renderer"', '"restricted-offscreen-renderer"', '"default-offscreen-renderer"']) and "BackendConfiguration.allCases.map" in source)
check("matrix_exact_ten_ordered_controls", "case thinWallForward, thinWallReverse, wallInitialOverlap, wallTerminalOverlap\n        case containedSolid, overheadTallForward, overheadTallReverse, overheadShort, clear, floor" in source)
check("every_query_recorded_without_short_circuit", "queries = ControlName.allCases.map { name in" in source and "catch { return QueryWitness.failed(name, error: error) }" in source and "queries = ControlName.allCases.map { QueryWitness.failed($0, error: error) }" in source)
check("error_records_fail_with_empty_contacts", "let empty = ContactWitness(Contacts())" in source and "passed: false, errorCode: code" in source and "initial: empty, swept: empty, terminal: empty" in source)
check("candidate_attachment_precedes_assertion", 'attachment.name = "SavedRoomCollisionBackendMatrix-v1.json"' in tests and "attachment.lifetime = .keepAlways" in tests and tests.index("add(attachment)") < tests.index("XCTAssertTrue(candidate.backendReady"))
check("attachment_bound_and_no_authority", "XCTAssertLessThanOrEqual(data.count, 131_072)" in tests and source.count("let physicalAuthority = false") == 2 and source.count("let fullFootprintSupportVerified = false") == 2)
result = {"kind": "source-contract-checks-not-Swift-compilation", "baselineCommit": "dc32a9bad9a75566f27924fb9f7aa8fe50a46e95", "checks": checks, "passed": sum(x["passed"] for x in checks), "failed": sum(not x["passed"] for x in checks), "nativeExecution": "not-run-no-Swift-Xcode-or-Apple-SDK", "sourceSHA256": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [source_path, tests_path]}}
print(json.dumps(result, indent=2))
raise SystemExit(bool(result["failed"]))
