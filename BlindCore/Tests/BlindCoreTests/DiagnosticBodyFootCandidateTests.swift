import XCTest
@testable import BlindCore

final class DiagnosticBodyFootCandidateTests: XCTestCase {
    typealias Candidate = DiagnosticBodyFootCandidate
    private let session = UUID(), frame = UUID()
    private func capture(_ matrix: NativeCameraTransform = .identity, time: Double = 10) -> Candidate.Capture {
        .init(session: session, frame: frame, capturedAt: time, cameraToWorld: matrix)
    }
    private func source(revision: UInt64 = 3) -> Candidate.Source {
        .init(captureSession: session, session: "mesh", generation: 1, revision: revision)
    }
    private func declaration(mount: ChestMountMetadata = .init(right: 0.1, up: 1.2, forward: 0.2),
                             yaw: Double? = 0, confirmed: Bool = true) throws -> Candidate.Declaration {
        .init(profile: try LocalBodyProfile(mount: mount), bodyYaw: yaw, confirmed: confirmed)
    }
    func testIdentityAndDeclaredForwardSignAreMetres() throws {
        let c = try XCTUnwrap(Candidate(capture: capture(), source: source(), declaration: declaration(), now: 10))
        XCTAssertEqual(c.requestedFoot.x, -0.1, accuracy: 1e-12)
        XCTAssertEqual(c.requestedFoot.y, -1.2, accuracy: 1e-12)
        XCTAssertEqual(c.requestedFoot.z, 0.2, accuracy: 1e-12)
        XCTAssertFalse(c.authorizesPhysicalGuidance); XCTAssertFalse(c.independentlyValidated)
    }
    func testTiltedCameraDoesNotTiltDeclaredWorldUpOrSupplyBodyYaw() throws {
        // +90 around X, with translation(10,20,30). Optical pitch must not rotate the body mount.
        let matrix = NativeCameraTransform(columns: [1,0,0,0, 0,0,1,0, 0,-1,0,0, 10,20,30,1])
        let c = try XCTUnwrap(Candidate(capture: capture(matrix), source: source(), declaration: declaration(yaw: .pi/2), now: 10))
        XCTAssertEqual(c.capture.cameraToWorld, matrix)
        XCTAssertEqual(c.cameraOrigin, Point3(10,20,30))
        XCTAssertEqual(c.requestedFoot.x, 10.2, accuracy: 1e-10)
        XCTAssertEqual(c.requestedFoot.y, 18.8, accuracy: 1e-10)
        XCTAssertEqual(c.requestedFoot.z, 30.1, accuracy: 1e-10)
    }
    func testMissingMountIsNotZeroAndStatureCannotReplaceMount() throws {
        let stature = try LocalBodyProfile(input: .init(heightMetres: 1.8))
        XCTAssertNil(Candidate(capture: capture(), source: source(), declaration: .init(profile: stature, bodyYaw: 0, confirmed: true), now: 10))
        for mount in [ChestMountMetadata(right: nil, up: 1, forward: 0), .init(right: 0, up: nil, forward: 0), .init(right: 0, up: 1, forward: nil)] {
            XCTAssertNil(Candidate(capture: capture(), source: source(), declaration: try declaration(mount: mount), now: 10))
        }
        XCTAssertNotNil(Candidate(capture: capture(), source: source(), declaration: try declaration(mount: .init(right: 0,up: 0,forward: 0)), now: 10))
        XCTAssertThrowsError(try LocalBodyProfile(mount: .init(right: .nan,up: 1,forward: 0)))
        XCTAssertThrowsError(try LocalBodyProfile(mount: .init(right: 0,up: 3,forward: 0)))
    }
    func testMissingInvalidUnconfirmedHeadingAndCaptureRefuse() throws {
        let invalidYaws: [Double?] = [nil, .nan, .infinity, 4]
        for yaw in invalidYaws {
            XCTAssertNil(Candidate(capture: capture(), source: source(), declaration: try declaration(yaw: yaw), now: 10))
        }
        XCTAssertNil(Candidate(capture: capture(), source: source(), declaration: try declaration(confirmed: false), now: 10))
        XCTAssertNil(Candidate(capture: nil, source: source(), declaration: try declaration(), now: 10))
    }
    func testStaleFutureNonfiniteAndBadMatrixRefuse() throws {
        let d = try declaration()
        for time in [9.49, 10.01, -.infinity, .nan, -1] {
            XCTAssertNil(Candidate(capture: capture(time: time), source: source(), declaration: d, now: 10))
        }
        XCTAssertNil(Candidate(capture: capture(), source: source(), declaration: d, now: .nan))
        for columns in [[], [Double](repeating: 0,count: 16), [Double](repeating: .nan,count: 16)] {
            XCTAssertNil(Candidate(capture: capture(.init(columns: columns)), source: source(), declaration: d, now: 10))
        }
        var scaled = NativeCameraTransform.identity.columns; scaled[0] = 2
        XCTAssertNil(Candidate(capture: capture(.init(columns: scaled)), source: source(), declaration: d, now: 10))
    }
    func testCaptureSessionMismatchRefuses() throws {
        let other = Candidate.Source(captureSession: UUID(),session: "mesh",generation: 1,revision: 3)
        XCTAssertNil(Candidate(capture: capture(),source: other,declaration: try declaration(),now: 10))
    }
    func testHeldDeliveryRejectsChangedCaptureSourceMountHeadingAndDeclaration() throws {
        let d = try declaration(), s = source(), camera = capture()
        let c = try XCTUnwrap(Candidate(capture: camera,source: s,declaration: d,now: 10))
        XCTAssertTrue(c.isCurrent(capture: camera,source: s,declaration: d,now: 10.1))
        XCTAssertFalse(c.isCurrent(capture: nil,source: s,declaration: d,now: 10.1))
        let next = Candidate.Capture(session: session,frame: UUID(),capturedAt: 10.1,cameraToWorld: .identity)
        XCTAssertFalse(c.isCurrent(capture: next,source: s,declaration: d,now: 10.1))
        XCTAssertFalse(c.isCurrent(capture: camera,source: source(revision: 4),declaration: d,now: 10.1))
        XCTAssertFalse(c.isCurrent(capture: camera,source: s,declaration: try declaration(yaw: 1),now: 10.1))
        var profile = d.profile
        try profile.update(input: profile.input,mount: .init(right: 0,up: 1.3,forward: 0),equipment: profile.equipment)
        let moved = Candidate.Declaration(revision: d.revision,profile: profile,bodyYaw: d.bodyYaw,confirmed: true)
        XCTAssertFalse(c.isCurrent(capture: camera,source: s,declaration: moved,now: 10.1))
        XCTAssertFalse(c.isCurrent(capture: camera,source: s,declaration: d,now: 18.001))
    }
    func testNativeAssociatedFootNeverOverwritesRequestedFoot() throws {
        let c = try XCTUnwrap(Candidate(capture: capture(),source: source(),declaration: declaration(),now: 10))
        let original = c.requestedFoot
        var projected = c.queryPoint; projected[1] += 0.026
        let e = try XCTUnwrap(c.associatedEndpoint(requested: c.queryPoint,associated: projected,found: true,isOverPolygon: true))
        XCTAssertEqual(e.deltaY, 0.026, accuracy: 1e-6)
        XCTAssertEqual(e.horizontalResidual, 0)
        XCTAssertEqual(c.requestedFoot, original)
        var different = c.queryPoint; different[0] += 0.1
        XCTAssertNil(c.associatedEndpoint(requested: different,associated: projected,found: true,isOverPolygon: true))
        XCTAssertNil(c.associatedEndpoint(requested: c.queryPoint,associated: [],found: true,isOverPolygon: true))
        let refused = try XCTUnwrap(c.associatedEndpoint(requested: c.queryPoint,associated: projected,found: false,isOverPolygon: false))
        XCTAssertFalse(refused.found); XCTAssertFalse(refused.isOverPolygon)
    }
}
