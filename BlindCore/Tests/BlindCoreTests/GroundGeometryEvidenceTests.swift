import XCTest
@testable import BlindCore

final class GroundGeometryEvidenceTests: XCTestCase {
    let profile = GroundGeometryProfile(identifier: "exact-fixture-2mm", residualTolerance: 0.002)
    func frame(a: Double = 0, b: Double = 0, yaw: Double = 0, step: Double = 0,
               edge: Double = 1.1, omitRow: Int? = nil, noise: Double = 0) -> Observation {
        let camera = Point3(10, 1.0, -8), forward = Point3(sin(yaw), 0, cos(yaw))
        var samples: [DepthSample] = []
        for row in 0..<9 where row != omitRow {
            for i in 0..<6 { for j in 0..<9 {
                let x = 0.3 + Double(row) * 0.2 + (Double(i) + 0.5) * 0.2 / 6
                let z = -0.38 + (Double(j) + 0.5) * 0.76 / 9
                let y = a*x + b*z + (x >= edge ? step : 0) + (((i+j)%2 == 0) ? noise : -noise)
                samples.append(DepthSample(Point3(camera.x + x*forward.x - z*forward.z,
                    y, camera.z + x*forward.z + z*forward.x)))
            } }
        }
        return Observation(timestamp: 10, camera: camera, forward: forward, samples: samples)
    }
    func analyze(_ frame: Observation, floor: Double? = 0) -> GroundGeometryEvidence {
        GroundGeometryAnalyzer.analyze(frame, now: 10, frameID: "fixture", source: .synthetic,
            referenceFloor: floor, profile: profile)
    }
    func testSignedPlanesIndependentYawAndPitchGrid() {
        // Prospective parameter grid, not the consumed recorded-stair labels.
        for degrees in [-18.0, -7, -2, 0, 3, 11, 21] {
            for cross in [-0.12, 0, 0.08] { for yaw in [0.0, 0.73, 2.4, -1.8] {
                let a = tan(degrees * .pi / 180)
                let result = analyze(frame(a: a, b: cross, yaw: yaw))
                XCTAssertEqual(result.status, .measured)
                XCTAssertEqual(result.patches.count, 9)
                for patch in result.patches {
                    XCTAssertEqual(patch.forwardGradient, a, accuracy: 1e-10)
                    XCTAssertEqual(patch.crossGradient, cross, accuracy: 1e-10)
                }
                XCTAssertTrue(result.transitions.allSatisfy { $0.kind == .continuousCandidate })
                XCTAssertFalse(result.authorizesPhysicalGuidance)
            } }
        }
    }
    func testBothStepDirectionsAndProspectiveHeightStrata() {
        for step in [-0.18, -0.12, -0.04, 0.04, 0.12, 0.18] {
            let result = analyze(frame(step: step))
            let edge = result.transitions.first { $0.fromPatch == 3 }
            XCTAssertEqual(edge?.kind, step > 0 ? .rise : .drop)
            XCTAssertEqual(edge?.signedHeightChange ?? 0, step, accuracy: 1e-9)
            XCTAssertFalse(result.authorizesPhysicalGuidance)
        }
    }
    func testSubToleranceMillimetresAreNotSafetyClearance() {
        for height in [0.001, 0.002, 0.003, 0.005] {
            let result = analyze(frame(step: height))
            XCTAssertEqual(result.transitions.first { $0.fromPatch == 3 }?.signedHeightChange ?? 0,
                           height, accuracy: 1e-9)
            XCTAssertFalse(result.frictionKnown)
            XCTAssertFalse(result.surfaceMovabilityKnown)
            XCTAssertFalse(result.authorizesPhysicalGuidance)
        }
    }
    func testMixedStepPatchNeverBecomesRamp() {
        for edge in [0.94, 0.98, 1.02, 1.06] { for height in [-0.12, 0.04, 0.18] {
            let result = analyze(frame(step: height, edge: edge))
            XCTAssertEqual(result.status, .incompleteSupport)
            XCTAssertFalse(result.patches.contains { $0.index == 3 })
            XCTAssertFalse(result.transitions.contains { $0.fromPatch == 2 && $0.toPatch == 4 })
        } }
    }
    func testDiagnosticToleranceMustNotFlattenResolvedFourCentimetreStep() {
        let input = frame(step: 0.04, edge: 1.0)
        let result = GroundGeometryAnalyzer.analyze(input, now: 10, frameID: "step-regression",
            source: .synthetic, referenceFloor: 0, profile: .diagnostic)
        XCTAssertFalse(result.patches.contains { $0.index == 3 })
        XCTAssertEqual(result.status, .incompleteSupport)
    }
    func testLateralFourCentimetreStepIsNotCrossSlope() {
        for height in [-0.04, 0.04] {
            var input = frame()
            input.samples = input.samples.map { sample in
                var sample = sample
                if input.coordinates(sample.position).side >= 0 { sample.position.y += height }
                return sample
            }
            let result = GroundGeometryAnalyzer.analyze(input, now: 10, frameID: "lateral-step",
                source: .synthetic, referenceFloor: 0, profile: .diagnostic)
            XCTAssertTrue(result.patches.isEmpty)
        }
    }
    func testSparseSubfitsCannotDistinguishPlaneFromStep() {
        for step in [0.0, 0.04, -0.04] { for yaw in [0.0, 41 * Double.pi / 180] {
            var input = frame(yaw: yaw, step: step, edge: 1.0)
            // Three ahead rows still occupy all 3x3 cells, but cannot support
            // two independent nondegenerate subplanes along the ahead axis.
            input.samples = input.samples.enumerated().filter { ($0.offset / 9) % 2 == 0 }.map(\.element)
            let result = GroundGeometryAnalyzer.analyze(input, now: 10, frameID: "sparse-step",
                source: .synthetic, referenceFloor: 0, profile: .diagnostic)
            XCTAssertTrue(result.patches.isEmpty)
        } }
    }
    func testHoleAndNarrowStripeRemainUnknown() {
        let hole = analyze(frame(omitRow: 4))
        XCTAssertEqual(hole.status, .incompleteSupport)
        XCTAssertFalse(hole.transitions.contains { $0.fromPatch == 3 && $0.toPatch == 5 })
        var stripe = frame()
        stripe.samples = stripe.samples.filter { abs(stripe.coordinates($0.position).side) < 0.05 }
        XCTAssertEqual(analyze(stripe).patches.count, 0)
    }
    func testNoiseIsMeasuredNotInterpretedAsHarmlessObject() {
        XCTAssertEqual(analyze(frame(noise: 0.001)).status, .measured)
        XCTAssertTrue(analyze(frame(noise: 0.015)).patches.isEmpty)
        var raisedObject = frame()
        raisedObject.samples[20].position.y += 0.04
        XCTAssertFalse(analyze(raisedObject).patches.contains { $0.index == 0 })
    }
    func testInvalidAndUnanchoredInputs() {
        var input = frame()
        input.trackingNormal = false
        XCTAssertEqual(analyze(input).status, .invalidInput)
        input = frame(); input.forward.y = 0.2
        XCTAssertEqual(analyze(input).status, .invalidInput)
        XCTAssertEqual(analyze(frame(), floor: nil).status, .unanchored)
        XCTAssertEqual(analyze(frame(), floor: 0.7).status, .unanchored)
        input = frame(); input.samples = input.samples.map { DepthSample($0.position, confidence: 1) }
        XCTAssertEqual(analyze(input).status, .unanchored)
        let invalid = GroundGeometryProfile(identifier: "invalid", residualTolerance: -.infinity)
        XCTAssertEqual(GroundGeometryAnalyzer.analyze(frame(), now: 10, frameID: "x", source: .synthetic,
            referenceFloor: 0, profile: invalid).status, .invalidInput)
    }
    func testStaleFutureAndMetadata() {
        for now in [9.9, 10.51] {
            XCTAssertEqual(GroundGeometryAnalyzer.analyze(frame(), now: now, frameID: "x",
                source: .sceneDepth, referenceFloor: 0).status, .stale)
        }
        let result = analyze(frame())
        XCTAssertEqual(result.frameID, "fixture")
        XCTAssertEqual(result.source, .synthetic)
        XCTAssertEqual(result.profileID, "exact-fixture-2mm")
        XCTAssertEqual(result.timestamp, 10)
    }
}
