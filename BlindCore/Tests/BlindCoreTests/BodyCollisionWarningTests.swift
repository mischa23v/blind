import Foundation
import XCTest
@testable import BlindCore

final class BodyCollisionWarningTests: XCTestCase {
    func profile(height: Double = 1.7, width: Double = 0.5, depth: Double = 0.3,
                 right: Double = 0, up: Double = 1.2, forward: Double = 0,
                 radial: Double? = 0, overhead: Double? = 0, error: Double? = nil) throws -> LocalBodyProfile {
        var value = try LocalBodyProfile(input: .init(heightMetres: height),
            mount: .init(right: right, up: up, forward: forward),
            equipment: .init(radialExtension: radial, overheadExtension: overhead))
        try value.record(.init(height: height, width: width, depth: depth, uncertainty: error, source: .reported,
            provenance: "synthetic helper measurements, not physical validation", recordedAt: 1,
            profileRevision: value.measurementBasisRevision), replacingGeometryRevision: value.geometryRevision)
        return value
    }
    func matrix(_ camera: Point3 = .init(0,1.2,0)) -> NativeCameraTransform {
        .init(columns: [1,0,0,0, 0,1,0,0, 0,0,1,0, camera.x,camera.y,camera.z,1])
    }
    func patch(_ x: Double = 0, y: Double = 1.2, z: Double = -0.6) -> [DepthSample] {
        [DepthSample(.init(x,y,z)), DepthSample(.init(x,y+0.11,z)), DepthSample(.init(x,y+0.22,z))]
    }
    func assess(_ p: LocalBodyProfile?, samples: [DepthSample], camera: Point3 = .init(0,1.2,0),
                pose: NativeCameraTransform? = nil, mounted: Bool = true, floor: Double? = nil,
                now: Double = 1, tracking: Bool = true) -> BodyCollisionWarning.Assessment {
        BodyCollisionWarning.assess(.init(timestamp: 1, camera: camera, forward: .init(0,0,-1), samples: samples, trackingNormal: tracking),
            cameraToWorld: pose ?? matrix(camera), profile: p, fixedMount: mounted, now: now, floorHeight: floor)
    }
    func testRealProfileBoundsNotAgeWeightDefaultsDriveWarnings() throws {
        let noDimensions = try LocalBodyProfile(input: .init(ageYears: 8, weightKilograms: 30, heightMetres: 1.4),
            mount: .init(right: 0, up: 1.2, forward: 0))
        XCTAssertEqual(assess(noDimensions, samples: patch()).status, .unavailableProfile)
        XCTAssertEqual(assess(try profile(), samples: patch()).status, .observedIntersection)
    }
    func testShortTallAndOverheadEquipment() throws {
        let elevated = patch(y: 1.85)
        XCTAssertNil(assess(try profile(height: 1.1), samples: elevated).detection)
        XCTAssertNotNil(assess(try profile(height: 2.2), samples: elevated).detection)
        XCTAssertNotNil(assess(try profile(height: 1.7, overhead: 0.4), samples: elevated).detection)
        // Entered short camera height is usable, not rejected by the legacy .65m limit.
        XCTAssertNotNil(assess(try profile(height: 0.8, up: 0.5), samples: patch(y: 0.35), camera: .init(0,0.5,0)).detection)
    }
    func testWideBodyBackpackOffsetAndRecordedErrorExpand() throws {
        let beside = patch(1.4, y: 0.9, z: 0)
        XCTAssertNil(assess(try profile(width: 0.3, depth: 0.2), samples: beside).detection)
        XCTAssertNotNil(assess(try profile(width: 1.2, depth: 0.4), samples: beside).detection)
        XCTAssertNotNil(assess(try profile(width: 0.3, depth: 0.2, radial: 0.5), samples: beside).detection)
        XCTAssertNotNil(assess(try profile(width: 0.3, depth: 0.2, right: 0.5), samples: beside).detection)
        XCTAssertNotNil(assess(try profile(width: 0.3, depth: 0.2, right: -0.5), samples: beside).detection)
        XCTAssertNotNil(assess(try profile(width: 0.3, depth: 0.2, error: 0.5), samples: beside).detection)
    }
    func testUnknownErrorsEquipmentAndReportedFloorNeverBecomeZeroOrClearance() throws {
        let p = try profile(radial: nil, overhead: nil)
        let a = assess(p, samples: patch())
        XCTAssertTrue(a.unquantifiedDimensionError); XCTAssertTrue(a.equipmentBoundsIncomplete)
        XCTAssertEqual(a.verticalReference, .reportedMount); XCTAssertNil(a.detection?.distance)
        let empty = assess(p, samples: [])
        XCTAssertEqual(empty.status, .unavailableDepth); XCTAssertNil(empty.detection)
        XCTAssertEqual(BodyCollisionWarning.combining(Detection(.uncertain), with: empty).hazard, .uncertain)
        XCTAssertEqual(assess(p, samples: patch(), floor: 0).verticalReference, .sensorFloor)
    }
    func testDoesNotTreatThreeDuplicatePixelsAsIndependentReturnsOrFloorAsObstacle() throws {
        let p = try profile()
        XCTAssertNil(assess(p, samples: Array(repeating: patch()[0], count: 50)).detection)
        let ground = [-0.3,0,0.3].map { DepthSample(Point3($0,0,-0.6)) }
        XCTAssertNil(assess(p, samples: ground, floor: 0).detection)
        XCTAssertNil(assess(p, samples: patch().map { DepthSample($0.position, confidence: 1) }).detection)
    }
    func testFullCameraPitchRollYawProjectionMatchesUnchangedWorldGeometry() throws {
        let p = try profile(), world = patch(y: 1.2)
        // Synthetic exact rigid transforms only. Production reuses ARKit's full matrix.
        let rotations: [[Double]] = [
            [1,0,0,0, 0,0,1,0, 0,-1,0,0], // pitch
            [0,1,0,0, -1,0,0,0, 0,0,1,0], // roll
            [0,0,-1,0, 0,1,0,0, 1,0,0,0] // yaw
        ]
        for rotation in rotations {
            let pose = NativeCameraTransform(columns: rotation + [0,1.2,0,1])
            let inverse = try pose.inverted()
            let projected = try world.map { sample in DepthSample(try pose.applying(to: inverse.applying(to: sample.position))) }
            XCTAssertTrue(pose.valid)
            XCTAssertNotNil(assess(p, samples: projected, pose: pose).detection)
            for (a,b) in zip(world,projected) { XCTAssertLessThan(a.position.distance(to: b.position), 1e-9) }
        }
    }
    func testMountSlipDeletionChangedProfileAndBadOrExpiredPoseCannotWarn() throws {
        let p = try profile()
        XCTAssertNil(assess(p, samples: patch(), mounted: false).detection)
        XCTAssertNil(assess(nil, samples: patch()).detection)
        XCTAssertNil(assess(p, samples: patch(), pose: matrix(.init(2,1.2,0))).detection)
        XCTAssertNil(assess(p, samples: patch(), now: 1.500001).detection)
        XCTAssertNil(assess(p, samples: patch(), now: 0.9).detection)
        XCTAssertNil(assess(p, samples: patch(), tracking: false).detection)
        var edited = p; try edited.update(input: .init(heightMetres: 1.2), mount: p.mount, equipment: p.equipment)
        XCTAssertNil(assess(edited, samples: patch()).detection)
        XCTAssertNotEqual(assess(p, samples: patch()).profileRevision, assess(edited, samples: patch()).profileRevision)
    }
    func testAllLegacyUrgentWarningsSurviveAndNoSupplementMakesSafe() throws {
        let hit = assess(try profile(), samples: patch()), miss = assess(try profile(), samples: [])
        for hazard in [Hazard.drop,.overhead,.obstacle] {
            let legacy = Detection(hazard, distance: 0.6, sector: 2, coverage: 0.4)
            XCTAssertEqual(BodyCollisionWarning.combining(legacy, with: hit), legacy)
        }
        for hazard in [Hazard.uncertain,.needsCalibration,.calibrating,.stopped,.observing] {
            let legacy = Detection(hazard)
            XCTAssertEqual(BodyCollisionWarning.combining(legacy, with: miss), legacy)
            XCTAssertEqual(BodyCollisionWarning.combining(legacy, with: hit).hazard, .obstacle)
        }
        XCTAssertEqual(hit.detection?.reason, .bodyEnvelope)
        XCTAssertTrue(GuidanceText.detection(hit.detection!, arabic: false).contains("possible obstacle"))
    }
    func testActualLegacyDetectorMissWitnessTallBodyIsSupplementedWithoutReplacingHazards() throws {
        // Explicit authored synthetic level reference, never used for recorded replay.
        let floor = stride(from: 0.32, through: 2.15, by: 0.08).flatMap { ahead in
            stride(from: -0.3, through: 0.3, by: 0.05).map { DepthSample(Point3($0,0,-ahead)) }
        }
        let camera = Point3(0,1.3,0)
        func frame(_ time: Double, _ samples: [DepthSample]) -> Observation {
            .init(timestamp: time, camera: camera, forward: .init(0,0,-1), samples: samples)
        }
        var detector = HazardDetector(); detector.beginCalibration()
        for i in 0..<15 { _ = detector.process(frame(Double(i)/15, floor)) }
        XCTAssertEqual(detector.floorHeight, 0)
        let high = [-0.12,0,0.12].map { DepthSample(Point3($0,2.3,-0.7)) }
        let observed = frame(1.1, floor + high)
        let legacy = detector.process(observed)
        XCTAssertEqual(legacy.hazard, .observing) // Preserved failing-before geometry witness.
        let assessed = BodyCollisionWarning.assess(observed, cameraToWorld: matrix(camera),
            profile: try profile(height: 2.5, up: 1.3), fixedMount: true, now: 1.1, floorHeight: detector.floorHeight)
        XCTAssertEqual(assessed.status, .observedIntersection)
        XCTAssertEqual(BodyCollisionWarning.combining(legacy, with: assessed).reason, .bodyEnvelope)
        let dropSamples = floor.map { DepthSample(Point3($0.position.x,-0.4,$0.position.z)) }
        let legacyDrop = detector.process(frame(1.2,dropSamples))
        XCTAssertEqual(legacyDrop.hazard, .drop)
        XCTAssertEqual(BodyCollisionWarning.combining(legacyDrop, with: assessed), legacyDrop)
    }

    func testSupplementalCannotMaskIndependentSameSeverityAlertInEitherOrder() throws {
        let supplemental = try XCTUnwrap(assess(try profile(), samples: patch()).detection)
        let independent = Detection(.obstacle, distance: 0.4, sector: 3, coverage: 0.5)
        XCTAssertEqual(AlertPolicy.highest([supplemental,independent]), independent)
        XCTAssertEqual(AlertPolicy.highest([independent,supplemental]), independent)
    }

    func testArbitrationStillUsesSeverityAndPreservesAllExistingSourceTies() throws {
        let supplemental = try XCTUnwrap(assess(try profile(), samples: patch()).detection)
        for hazard in [Hazard.drop,.overhead] {
            let higher = Detection(hazard, distance: 0.5, sector: 1)
            XCTAssertEqual(AlertPolicy.highest([supplemental,higher]), higher)
            XCTAssertEqual(AlertPolicy.highest([higher,supplemental]), higher)
        }
        for hazard in [Hazard.uncertain,.needsCalibration,.observing] {
            let lower = Detection(hazard)
            XCTAssertEqual(AlertPolicy.highest([supplemental,lower]), supplemental)
            XCTAssertEqual(AlertPolicy.highest([lower,supplemental]), supplemental)
        }
        let visual = Detection(.obstacle, reason: .visualStairs)
        let independent = Detection(.obstacle, distance: 0.4, sector: 3)
        XCTAssertEqual(AlertPolicy.highest([visual,independent]), independent)
        XCTAssertEqual(AlertPolicy.highest([independent,visual]), independent)
    }

}
