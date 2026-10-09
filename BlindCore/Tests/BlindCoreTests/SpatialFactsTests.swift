import XCTest
@testable import BlindCore

/// Code-rendered spatial facts (E13) and fast "where is it" answers (E14).
final class SpatialFactsTests: XCTestCase {
    private let camera = Point3(0, 1.3, 0)
    // ARKit default: the camera looks along -z, and its right is +x.
    private let lookingNorth = Point3(0, 0, -1)

    /// Target at `degrees` from the facing direction (positive right) and `range` metres away,
    /// for a person facing -z. Right of -z is +x, so x = sin, z = -cos.
    private func target(_ degrees: Double, _ range: Double = 2) -> Point3 {
        let radians = degrees * .pi / 180
        return Point3(range * sin(radians), 0.4, -range * cos(radians))
    }

    func testLeftRightMatchesObservationCoordinates() throws {
        // Worked example: facing -z, a door at (1, y, -1) is one metre ahead and one metre to the
        // right. Observation.coordinates gives side = -dx * fz + dz * fx = -(1)(-1) + (-1)(0) = +1.
        let door = Point3(1, 0.2, -1)
        let observation = Observation(timestamp: 0, camera: camera, forward: lookingNorth, samples: [])
        let c = observation.coordinates(door)
        XCTAssertEqual(c.ahead, 1, accuracy: 1e-9)
        XCTAssertEqual(c.side, 1, accuracy: 1e-9)
        let relation = try XCTUnwrap(SpatialFacts.relation(from: camera, facing: lookingNorth, to: door))
        XCTAssertEqual(relation.angleDegrees, 45, accuracy: 1e-9)
        XCTAssertEqual(relation.distance, sqrt(2), accuracy: 1e-9)
        XCTAssertEqual(relation.sector, .aheadRight)
        // Same sign as the coordinates helper for a target on the left.
        let lamp = Point3(-1, 0, -1)
        XCTAssertLessThan(observation.coordinates(lamp).side, 0)
        XCTAssertEqual(SpatialFacts.relation(from: camera, facing: lookingNorth, to: lamp)?.sector, .aheadLeft)
    }

    func testEachSectorFromSyntheticGeometry() {
        let cases: [(Double, Sector)] = [
            (0, .ahead), (20, .ahead), (-20, .ahead),
            (50, .aheadRight), (-50, .aheadLeft),
            (90, .right), (-90, .left),
            (140, .behindRight), (-140, .behindLeft),
            (170, .behind), (-170, .behind), (180, .behind)
        ]
        for (degrees, expected) in cases {
            let relation = SpatialFacts.relation(from: camera, facing: lookingNorth, to: target(degrees, 2.5))
            XCTAssertEqual(relation?.sector, expected, "\(degrees) degrees")
            XCTAssertEqual(relation?.distance ?? 0, 2.5, accuracy: 1e-9)
        }
    }

    func testSectorThresholdsMatchEvaluationScript() {
        XCTAssertEqual(SpatialFacts.sector(angleDegrees: 29.9), .ahead)
        XCTAssertEqual(SpatialFacts.sector(angleDegrees: 30), .aheadRight)
        XCTAssertEqual(SpatialFacts.sector(angleDegrees: -74.9), .aheadLeft)
        XCTAssertEqual(SpatialFacts.sector(angleDegrees: 75), .right)
        XCTAssertEqual(SpatialFacts.sector(angleDegrees: -120), .behindLeft)
        XCTAssertEqual(SpatialFacts.sector(angleDegrees: 159.9), .behindRight)
        XCTAssertEqual(SpatialFacts.sector(angleDegrees: 160), .behind)
    }

    func testRotatedAndUnnormalizedFacing() {
        // Facing +x: the right-hand side is +z (right = (-fz, 0, fx)).
        let east = Point3(4, 0.7, 0)
        XCTAssertEqual(SpatialFacts.relation(from: camera, facing: east, to: Point3(0, 0, 2))?.sector, .right)
        XCTAssertEqual(SpatialFacts.relation(from: camera, facing: east, to: Point3(0, 0, -2))?.sector, .left)
        XCTAssertEqual(SpatialFacts.relation(from: camera, facing: east, to: Point3(-3, 0, 0))?.sector, .behind)
        // Height is ignored: a target straight below the forward line is still ahead at horizontal range.
        let below = SpatialFacts.relation(from: camera, facing: Point3(0, -0.5, -3), to: Point3(0, -2, -1.5))
        XCTAssertEqual(below?.sector, .ahead)
        XCTAssertEqual(below?.distance ?? 0, 1.5, accuracy: 1e-9)
    }

    func testInvalidGeometryReturnsNil() {
        XCTAssertNil(SpatialFacts.relation(from: camera, facing: Point3(0, 1, 0), to: target(0)))
        XCTAssertNil(SpatialFacts.relation(from: camera, facing: Point3(0, 0, 0), to: target(0)))
        XCTAssertNil(SpatialFacts.relation(from: camera, facing: Point3(.nan, 0, -1), to: target(0)))
        XCTAssertNil(SpatialFacts.relation(from: camera, facing: lookingNorth, to: Point3(.infinity, 0, 0)))
        XCTAssertNil(SpatialFacts.relation(from: Point3(0, .nan, 0), facing: lookingNorth, to: target(0)))
    }

    func testPhraseWordingAndDistanceRounding() {
        let door = SpatialRelation(angleDegrees: 140, distance: 2.06, sector: .behindRight)
        XCTAssertEqual(SpatialFacts.phrase(label: "Door", relation: door, arabic: false, inView: nil),
                       "Door: behind you on the right, 2.1 metres.")
        let fork = SpatialRelation(angleDegrees: 40, distance: 0.64, sector: .aheadRight)
        XCTAssertEqual(SpatialFacts.phrase(label: "Fork", relation: fork, arabic: false, inView: true),
                       "Fork: ahead, slightly right, 0.6 metres.")
        func spoken(_ distance: Double) -> String {
            SpatialFacts.phrase(label: "Chair", relation: SpatialRelation(angleDegrees: 0, distance: distance, sector: .ahead),
                                arabic: false, inView: nil)
        }
        XCTAssertEqual(spoken(2.94), "Chair: ahead, 2.9 metres.")
        XCTAssertEqual(spoken(0.25), "Chair: ahead, 0.3 metres.")
        XCTAssertEqual(spoken(3.0), "Chair: ahead, 3 metres.")
        XCTAssertEqual(spoken(3.4), "Chair: ahead, 3 metres.")
        XCTAssertEqual(spoken(3.6), "Chair: ahead, 4 metres.")
        XCTAssertEqual(spoken(7.2), "Chair: ahead, 7 metres.")
        // A distance that cannot be spoken is left out rather than guessed.
        XCTAssertEqual(spoken(.nan), "Chair: ahead.")
    }

    func testNotInViewSuffix() {
        let door = SpatialRelation(angleDegrees: 140, distance: 2.1, sector: .behindRight)
        XCTAssertEqual(SpatialFacts.phrase(label: "Door", relation: door, arabic: false, inView: false),
                       "Door: behind you on the right, 2.1 metres, not in camera view.")
        XCTAssertFalse(SpatialFacts.phrase(label: "Door", relation: door, arabic: false, inView: true).contains("camera"))
        XCTAssertFalse(SpatialFacts.phrase(label: "Door", relation: door, arabic: false, inView: nil).contains("camera"))
    }

    func testArabicPhrase() {
        let door = SpatialRelation(angleDegrees: 140, distance: 2.1, sector: .behindRight)
        XCTAssertEqual(SpatialFacts.phrase(label: "الباب", relation: door, arabic: true, inView: nil),
                       "الباب: خلفك إلى اليمين، 2.1 متر.")
        XCTAssertEqual(SpatialFacts.phrase(label: "الباب", relation: door, arabic: true, inView: false),
                       "الباب: خلفك إلى اليمين، 2.1 متر، ليس ضمن مجال الكاميرا.")
        let cup = SpatialRelation(angleDegrees: -100, distance: 4.4, sector: .left)
        XCTAssertEqual(SpatialFacts.phrase(label: "الكوب", relation: cup, arabic: true, inView: true),
                       "الكوب: على يسارك، 4 متر.")
    }

    func testCameraRelationFromBoxAndDepth() throws {
        let right = try XCTUnwrap(SpatialFacts.cameraRelation(boxCenterX: 0.75, depth: 1.8, horizontalFieldOfViewDegrees: 60))
        XCTAssertEqual(right.angleDegrees, 15, accuracy: 1e-9)
        XCTAssertEqual(right.distance, 1.8, accuracy: 1e-9)
        XCTAssertEqual(right.sector, .ahead)
        let left = try XCTUnwrap(SpatialFacts.cameraRelation(boxCenterX: 0, depth: 0.6, horizontalFieldOfViewDegrees: 100))
        XCTAssertEqual(left.angleDegrees, -50, accuracy: 1e-9)
        XCTAssertEqual(left.sector, .aheadLeft)
        XCTAssertEqual(SpatialFacts.cameraRelation(boxCenterX: 0.5, depth: 0.1, horizontalFieldOfViewDegrees: 60)?.sector, .ahead)
        XCTAssertNotNil(SpatialFacts.cameraRelation(boxCenterX: 1, depth: 10, horizontalFieldOfViewDegrees: 60))
    }

    func testCameraRelationInvalidInputsReturnNil() {
        XCTAssertNil(SpatialFacts.cameraRelation(boxCenterX: 0.5, depth: 0.05, horizontalFieldOfViewDegrees: 60))
        XCTAssertNil(SpatialFacts.cameraRelation(boxCenterX: 0.5, depth: 10.5, horizontalFieldOfViewDegrees: 60))
        XCTAssertNil(SpatialFacts.cameraRelation(boxCenterX: 0.5, depth: .nan, horizontalFieldOfViewDegrees: 60))
        XCTAssertNil(SpatialFacts.cameraRelation(boxCenterX: 0.5, depth: .infinity, horizontalFieldOfViewDegrees: 60))
        XCTAssertNil(SpatialFacts.cameraRelation(boxCenterX: 1.2, depth: 1, horizontalFieldOfViewDegrees: 60))
        XCTAssertNil(SpatialFacts.cameraRelation(boxCenterX: .nan, depth: 1, horizontalFieldOfViewDegrees: 60))
        XCTAssertNil(SpatialFacts.cameraRelation(boxCenterX: 0.5, depth: 1, horizontalFieldOfViewDegrees: 0))
        XCTAssertNil(SpatialFacts.cameraRelation(boxCenterX: 0.5, depth: 1, horizontalFieldOfViewDegrees: .nan))
    }

    func testCalibratedStepsOnlyWithPersonalStride() {
        XCTAssertEqual(SpatialFacts.calibratedSteps(distance: 3, strideMetres: 0.75), 4)
        XCTAssertEqual(SpatialFacts.calibratedSteps(distance: 2.1, strideMetres: 0.35), 6)
        XCTAssertEqual(SpatialFacts.calibratedSteps(distance: 0, strideMetres: 0.5), 0)
        // No calibrated stride means no step count; there is no average-stride fallback.
        XCTAssertNil(SpatialFacts.calibratedSteps(distance: 3, strideMetres: nil))
        XCTAssertNil(SpatialFacts.calibratedSteps(distance: 3, strideMetres: 0.1))
        XCTAssertNil(SpatialFacts.calibratedSteps(distance: 3, strideMetres: 2))
        XCTAssertNil(SpatialFacts.calibratedSteps(distance: 3, strideMetres: .nan))
        XCTAssertNil(SpatialFacts.calibratedSteps(distance: .nan, strideMetres: 0.7))
        XCTAssertNil(SpatialFacts.calibratedSteps(distance: -1, strideMetres: 0.7))
    }
}
