import XCTest
@testable import BlindCore

final class LandmarkPoseTests: XCTestCase {
    /// Horizontal direction for a yaw in degrees: 0 looks along -z, positive turns left (as in BodyHeadingTests).
    private func direction(_ degrees: Double) -> Point3 {
        let r = degrees * .pi / 180
        return Point3(-sin(r), 0, -cos(r))
    }

    /// Body-frame sighting (x right, z ahead) of a saved map point, built through `Observation.coordinates`
    /// so these tests share one left/right convention with Geometry.swift.
    private func sighting(of mapPoint: Point3, from position: Point3, facing forward: Point3,
                          weight: Double = 1) -> LandmarkSighting {
        let view = Observation(timestamp: 0, camera: position, forward: forward, samples: [])
        let c = view.coordinates(mapPoint)
        return LandmarkSighting(mapPosition: mapPoint, relative: Point3(c.side, 0, c.ahead), weight: weight)
    }

    private let truePosition = Point3(1.2, 0, -0.8)
    private var trueForward: Point3 { direction(35) }
    private let landmarks = [Point3(3, 0, -2), Point3(0.5, 0, -3.5), Point3(-0.6, 0, 0.4)]

    private func assertPoint(_ actual: Point3, _ expected: Point3, accuracy: Double,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: accuracy, file: file, line: line)
    }

    func testRecoversKnownPoseFromTwoLandmarks() throws {
        let sightings = landmarks.prefix(2).map { sighting(of: $0, from: truePosition, facing: trueForward) }
        let estimate = try XCTUnwrap(LandmarkPose.solve(Array(sightings)))
        assertPoint(estimate.position, truePosition, accuracy: 1e-9)
        assertPoint(estimate.forward, trueForward, accuracy: 1e-9)
        XCTAssertLessThan(estimate.residualMetres, 1e-9)
        XCTAssertEqual(estimate.landmarkCount, 2)
    }

    func testRecoversKnownPoseFromThreeLandmarks() throws {
        let sightings = landmarks.map { sighting(of: $0, from: truePosition, facing: trueForward) }
        let estimate = try XCTUnwrap(LandmarkPose.solve(sightings))
        assertPoint(estimate.position, truePosition, accuracy: 1e-9)
        assertPoint(estimate.forward, trueForward, accuracy: 1e-9)
        XCTAssertLessThan(estimate.residualMetres, 1e-9)
        XCTAssertEqual(estimate.landmarkCount, 3)
    }

    func testSmallNoiseGivesSmallResidualAndCloseEstimate() throws {
        let noise = [(0.03, -0.02), (-0.02, 0.03), (0.02, 0.02)]
        var sightings = landmarks.map { sighting(of: $0, from: truePosition, facing: trueForward) }
        for i in sightings.indices {
            let r = sightings[i].relative
            sightings[i].relative = Point3(r.x + noise[i].0, 0, r.z + noise[i].1)
        }
        let estimate = try XCTUnwrap(LandmarkPose.solve(sightings))
        XCTAssertGreaterThan(estimate.residualMetres, 0)
        XCTAssertLessThan(estimate.residualMetres, 0.1)
        assertPoint(estimate.position, truePosition, accuracy: 0.05)
        let headingError = acos(min(1, estimate.forward.x * trueForward.x + estimate.forward.z * trueForward.z))
        XCTAssertLessThan(headingError * 180 / .pi, 2)
    }

    func testOneWronglyMatchedLandmarkAmongThreeIsDeclined() {
        var sightings = landmarks.map { sighting(of: $0, from: truePosition, facing: trueForward) }
        XCTAssertNotNil(LandmarkPose.solve(sightings))
        // The third detection is paired with a different saved object about 2 m from the right one.
        // The best rigid fit leaves roughly 0.6 m RMS residual, above the 0.35 m limit.
        sightings[2].mapPosition = Point3(1.4, 0, 1.6)
        XCTAssertNil(LandmarkPose.solve(sightings))
    }

    func testTooFewOrTooCloseLandmarksAreDeclined() {
        let one = [sighting(of: landmarks[0], from: truePosition, facing: trueForward)]
        XCTAssertNil(LandmarkPose.solve(one))
        // About 0.28 m apart: below the 0.5 m separation requirement.
        let close = [Point3(3, 0, -2), Point3(3.2, 0, -2.2)].map {
            sighting(of: $0, from: truePosition, facing: trueForward)
        }
        XCTAssertNil(LandmarkPose.solve(close))
    }

    func testTwoLandmarksWithMismatchedSeparationAreDeclined() {
        // Saved 2.0 m apart, seen 2.3 m apart. A two-point fit would leave only about 0.15 m residual,
        // so the tighter pair-distance check is what declines it.
        let sightings = [LandmarkSighting(mapPosition: Point3(0, 0, -2), relative: Point3(0, 0, 2)),
                         LandmarkSighting(mapPosition: Point3(2, 0, -2), relative: Point3(2.3, 0, 2))]
        XCTAssertNil(LandmarkPose.solve(sightings))
        var matching = sightings
        matching[1].relative = Point3(2.1, 0, 2)
        XCTAssertNotNil(LandmarkPose.solve(matching))
    }

    func testNonFiniteOrInvalidInputIsDeclined() {
        let good = landmarks.map { sighting(of: $0, from: truePosition, facing: trueForward) }
        XCTAssertNotNil(LandmarkPose.solve(good))

        var nanRelative = good
        nanRelative[0].relative = Point3(.nan, 0, 1)
        XCTAssertNil(LandmarkPose.solve(nanRelative))

        var infiniteMap = good
        infiniteMap[1].mapPosition = Point3(0, 0, .infinity)
        XCTAssertNil(LandmarkPose.solve(infiniteMap))

        var nanWeight = good
        nanWeight[2].weight = .nan
        XCTAssertNil(LandmarkPose.solve(nanWeight))

        var zeroWeight = good
        zeroWeight[2].weight = 0
        XCTAssertNil(LandmarkPose.solve(zeroWeight))
    }

    func testLandmarksAlongOneLineOfSightLeaveHeadingUnknown() throws {
        // 3.0 m and 3.6 m straight ahead: heading rests on bearing noise at range (about 15.6 degrees predicted).
        let alongSight = [LandmarkSighting(mapPosition: Point3(0, 0, -3), relative: Point3(0, 0, 3)),
                          LandmarkSighting(mapPosition: Point3(0, 0, -3.6), relative: Point3(0, 0, 3.6))]
        XCTAssertNil(LandmarkPose.solve(alongSight))
        // The same 0.6 m separation side by side at 3 m rests on depth instead (about 6.9 degrees) and is accepted.
        let sideBySide = [LandmarkSighting(mapPosition: Point3(-0.3, 0, -3), relative: Point3(-0.3, 0, 3)),
                          LandmarkSighting(mapPosition: Point3(0.3, 0, -3), relative: Point3(0.3, 0, 3))]
        let estimate = try XCTUnwrap(LandmarkPose.solve(sideBySide))
        assertPoint(estimate.position, Point3(0, 0, 0), accuracy: 1e-9)
        assertPoint(estimate.forward, Point3(0, 0, -1), accuracy: 1e-9)
    }

    func testAgreesWithCloseArkitPoseOnly() {
        let estimate = LandmarkPoseEstimate(position: Point3(1, 0, 2), forward: Point3(0, 0, -1),
                                            residualMetres: 0.05, landmarkCount: 3)
        // Camera 1.4 m up, 0.22 m away horizontally, pitched down and turned about 6 degrees.
        XCTAssertTrue(LandmarkPose.agrees(estimate, with: Point3(1.2, 1.4, 2.1),
                                          arkitForward: Point3(0.1, -0.3, -0.95)))
        // 0.8 m away horizontally.
        XCTAssertFalse(LandmarkPose.agrees(estimate, with: Point3(1.8, 1.4, 2), arkitForward: Point3(0, 0, -1)))
        // Same place, heading 30 degrees apart.
        XCTAssertFalse(LandmarkPose.agrees(estimate, with: Point3(1, 1.4, 2), arkitForward: direction(30)))
        // A camera pointing straight down gives no heading to compare.
        XCTAssertFalse(LandmarkPose.agrees(estimate, with: Point3(1, 1.4, 2), arkitForward: Point3(0, -1, 0)))
        XCTAssertFalse(LandmarkPose.agrees(estimate, with: Point3(.nan, 1.4, 2), arkitForward: Point3(0, 0, -1)))
    }

    func testWorkedExampleBedAheadWardrobeOnRight() throws {
        // "The bed is ahead 2 m, the wardrobe is on my right 1.5 m."
        let bed = LandmarkSighting(mapPosition: Point3(0, 0, -2), relative: Point3(0, 0, 2))
        let wardrobe = LandmarkSighting(mapPosition: Point3(1.5, 0, 0), relative: Point3(1.5, 0, 0))
        // Saved bed along -z and wardrobe along +x: the person is at the origin facing -z,
        // and right is +x, as in Observation.coordinates.
        let facingMinusZ = try XCTUnwrap(LandmarkPose.solve([bed, wardrobe]))
        assertPoint(facingMinusZ.position, Point3(0, 0, 0), accuracy: 1e-9)
        assertPoint(facingMinusZ.forward, Point3(0, 0, -1), accuracy: 1e-9)
        let check = Observation(timestamp: 0, camera: facingMinusZ.position, forward: facingMinusZ.forward,
                                samples: []).coordinates(wardrobe.mapPosition)
        XCTAssertEqual(check.side, 1.5, accuracy: 1e-9)
        XCTAssertEqual(check.ahead, 0, accuracy: 1e-9)

        // Same sightings with the bed saved along +x and the wardrobe along +z: facing +x, right is +z.
        let bedEast = LandmarkSighting(mapPosition: Point3(2, 0, 0), relative: Point3(0, 0, 2))
        let wardrobeSouth = LandmarkSighting(mapPosition: Point3(0, 0, 1.5), relative: Point3(1.5, 0, 0))
        let facingPlusX = try XCTUnwrap(LandmarkPose.solve([bedEast, wardrobeSouth]))
        assertPoint(facingPlusX.position, Point3(0, 0, 0), accuracy: 1e-9)
        assertPoint(facingPlusX.forward, Point3(1, 0, 0), accuracy: 1e-9)

        // If the wardrobe were saved on the person's left (-x), the fit is not the origin facing -z:
        // a left/right sign error would move the person, so the convention matters.
        let wardrobeLeft = LandmarkSighting(mapPosition: Point3(-1.5, 0, 0), relative: Point3(1.5, 0, 0))
        let mirrored = try XCTUnwrap(LandmarkPose.solve([bed, wardrobeLeft]))
        assertPoint(mirrored.position, Point3(-1.92, 0, -1.44), accuracy: 1e-9)
        assertPoint(mirrored.forward, Point3(0.96, 0, -0.28), accuracy: 1e-9)
    }
}
