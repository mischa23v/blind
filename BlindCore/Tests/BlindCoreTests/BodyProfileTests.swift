import Foundation
import XCTest
@testable import BlindCore

final class BodyProfileTests: XCTestCase {
    func testOptionalInputsAndUnits() throws {
        let p = try LocalBodyProfile()
        XCTAssertNil(p.input.ageYears); XCTAssertNil(p.input.gender)
        XCTAssertNil(p.input.weightKilograms); XCTAssertNil(p.input.heightMetres)
        XCTAssertEqual(BodyProfileInput.metres(centimetres: 180), 1.8)
        XCTAssertEqual(BodyProfileInput.metres(inches: 60), 1.524, accuracy: 0.0001)
        XCTAssertEqual(BodyProfileInput.kilograms(pounds: 100), 45.359237, accuracy: 0.000001)
        XCTAssertFalse(p.preview().missingEvidence.isEmpty)
    }
    func testInvalidFiniteAndRangeValuesReject() throws {
        for n in [Double.nan, .infinity, -.infinity, -1, 1000] {
            XCTAssertThrowsError(try LocalBodyProfile(input: .init(ageYears: n)))
            XCTAssertThrowsError(try LocalBodyProfile(input: .init(weightKilograms: n)))
            XCTAssertThrowsError(try LocalBodyProfile(input: .init(heightMetres: n)))
        }
        XCTAssertThrowsError(try LocalBodyProfile(input: .init(gender: String(repeating: "x", count: 101))))
        XCTAssertThrowsError(try LocalBodyProfile(mount: .init(up: -1)))
        XCTAssertThrowsError(try LocalBodyProfile(equipment: .init(radialExtension: .nan)))
    }
    func testRecordedBoundsRejectLoadedEmptyAndEstimatedOnlyProfiles() throws {
        let empty = try LocalBodyProfile.decodeLocal(JSONEncoder().encode(LocalBodyProfile()))
        XCTAssertNotNil(empty.preview().envelope) // Settings visualization keeps its existing defaults.
        XCTAssertNil(empty.recordedBoundsPreview()) // Loading no saved measurements cannot create a planning body.
        var estimated = try LocalBodyProfile(input: .init(ageYears: 8, weightKilograms: 25, heightMetres: 1.2))
        XCTAssertNil(estimated.recordedBoundsPreview())
        try record(&estimated, .estimated)
        XCTAssertNotNil(estimated.preview().envelope)
        XCTAssertNil(estimated.recordedBoundsPreview())
    }
    func testRecordedBoundsAcceptReportsAndMeasurementsWithoutHidingMissingEvidence() throws {
        for source in [BodyDimensionSource.reported, .measured] {
            var p = try LocalBodyProfile()
            try p.record(.init(height: 1.7, width: 0.6, depth: 0.4, uncertainty: nil,
                source: source, provenance: "synthetic conditional input", recordedAt: 10,
                profileRevision: p.measurementBasisRevision), replacingGeometryRevision: p.geometryRevision)
            let preview = try XCTUnwrap(p.recordedBoundsPreview()), existing = p.preview()
            XCTAssertEqual(preview.envelope, existing.envelope)
            XCTAssertEqual(preview.dimensionSource, source)
            XCTAssertEqual(preview.missingEvidence, existing.missingEvidence)
            XCTAssertTrue(preview.missingEvidence.contains("quantified dimension uncertainty"))
            XCTAssertTrue(preview.missingEvidence.contains("chest mount offset"))
            XCTAssertTrue(preview.missingEvidence.contains("carried objects, backpack, clothing and cane bounds"))
            XCTAssertEqual(preview.profileRevision, p.geometryRevision)
            XCTAssertEqual(preview.mountRevision, p.mountRevision)
        }
    }
    func testRecordedBoundsRetainConservativeUnionAndRetireAfterGeometryChanges() throws {
        var p = try LocalBodyProfile(); try record(&p, .measured, h: 1.8, w: 0.4, d: 0.2)
        try record(&p, .reported, h: 1.5, w: 0.9, d: 0.5)
        let preview = try XCTUnwrap(p.recordedBoundsPreview())
        XCTAssertEqual(preview.envelope, p.preview().envelope)
        XCTAssertEqual(preview.dimensionSource, .reported)
        XCTAssertTrue(preview.missingEvidence.contains("new report compared with retained measurement; conservative union"))
        try p.update(input: .init(heightMetres: 1.9), mount: p.mount, equipment: p.equipment)
        XCTAssertTrue(p.dimensions.isEmpty)
        XCTAssertNil(p.recordedBoundsPreview())
    }
    func testRecordedBoundsRejectInvalidStaleAndUnsupportedWithoutSmallerFallback() throws {
        var p = try LocalBodyProfile(equipment: .init(radialExtension: 3, overheadExtension: 3))
        try record(&p, .reported)
        XCTAssertNotNil(p.recordedBoundsPreview())
        XCTAssertNil(p.recordedBoundsPreview()?.envelope) // Unsupported size is never clamped/defaulted.
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as? [String: Any])
        object["measurementBasisRevision"] = UUID().uuidString
        let stale = try JSONDecoder().decode(LocalBodyProfile.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(stale.valid)
        XCTAssertNil(stale.recordedBoundsPreview())
        object["measurementBasisRevision"] = p.measurementBasisRevision.uuidString
        var input = try XCTUnwrap(object["input"] as? [String: Any]); input["heightMetres"] = -1; object["input"] = input
        let invalid = try JSONDecoder().decode(LocalBodyProfile.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(invalid.valid)
        XCTAssertNil(invalid.recordedBoundsPreview())
    }
    func testDemographicsDoNotInventWidthOrGuardianAuthority() throws {
        let a = try LocalBodyProfile(input: .init(ageYears: 5, gender: "girl", weightKilograms: 20, heightMetres: 1))
        let b = try LocalBodyProfile(input: .init(ageYears: 50, gender: "man", weightKilograms: 120, heightMetres: 2))
        XCTAssertEqual(a.preview().envelope?.radius, b.preview().envelope?.radius)
        XCTAssertEqual(a.preview().dimensionSource, .estimated)
        XCTAssertEqual(a.preview().envelope?.height, 1)
    }
    func record(_ p: inout LocalBodyProfile, _ source: BodyDimensionSource, h: Double = 1.5, w: Double = 0.5, d: Double = 0.3) throws {
        try p.record(.init(height: h, width: w, depth: d, uncertainty: 0.02, source: source,
            provenance: "synthetic test only", recordedAt: 10, profileRevision: p.measurementBasisRevision), replacingGeometryRevision: p.geometryRevision)
    }
    func testMeasuredThenReportedThenEstimatedPrecedence() throws {
        var p = try LocalBodyProfile(input: .init(heightMetres: 2))
        try record(&p, .estimated, h: 1.4)
        XCTAssertEqual(p.preview().dimensionSource, .estimated)
        try record(&p, .measured, h: 1.6)
        try record(&p, .reported, h: 1.7)
        XCTAssertEqual(p.preview().dimensionSource, .reported)
        XCTAssertEqual(try XCTUnwrap(p.preview().envelope).height, 1.72, accuracy: 0.00001)
        XCTAssertEqual(p.dimensions.count, 2)
        try record(&p, .measured, h: 1.8)
        XCTAssertEqual(p.dimensions.count, 1)
    }
    func testNewWiderReportDoesNotRefreshOrShrinkOlderMeasurement() throws {
        var p = try LocalBodyProfile()
        try record(&p, .measured, h: 1.8, w: 0.4, d: 0.2)
        let original = try XCTUnwrap(p.dimensions.first), revision = p.geometryRevision
        try record(&p, .reported, h: 1.5, w: 0.9, d: 0.5)
        XCTAssertEqual(p.dimensions.first { $0.source == .measured }, original)
        XCTAssertNotEqual(revision, p.geometryRevision)
        XCTAssertEqual(try XCTUnwrap(p.preview().envelope).radius, hypot(0.9, 0.5) / 2 + 0.02, accuracy: 0.00001)
        XCTAssertEqual(try XCTUnwrap(p.preview().envelope).height, 1.82, accuracy: 0.00001)
        try record(&p, .measured, h: 1.6, w: 0.45, d: 0.25)
        XCTAssertEqual(p.dimensions.count, 1)
        XCTAssertEqual(p.preview().dimensionSource, .measured)
    }
    func testLateDimensionCallbackAndIndependentContradictoryAxes() throws {
        var p = try LocalBodyProfile()
        let pendingRevision = p.geometryRevision
        let pending = BodyDimensions(height: 1.2, width: 0.2, depth: 0.2, uncertainty: nil,
            source: .measured, provenance: "old synthetic callback", recordedAt: 9, profileRevision: p.measurementBasisRevision)
        try record(&p, .measured, h: 1.5, w: 0.8, d: 0.2)
        XCTAssertThrowsError(try p.record(pending, replacingGeometryRevision: pendingRevision))
        let original = p.dimensions.first
        try record(&p, .reported, h: 1.9, w: 0.2, d: 0.9)
        XCTAssertEqual(p.dimensions.first { $0.source == .measured }, original)
        let preview = p.preview(), bounds = try XCTUnwrap(preview.envelope)
        XCTAssertEqual(bounds.height, 1.92, accuracy: 0.00001)
        XCTAssertEqual(bounds.radius, hypot(0.2, 0.9) / 2 + 0.02, accuracy: 0.00001)
        XCTAssertEqual(preview.evaluate(surface: surface(), from: .init(5,0,3), to: .init(5,0,6)), .unknown)
    }
    func testOldTimestampCannotReplaceNewerMeasurementEvenWithCurrentRevision() throws {
        var p = try LocalBodyProfile(); try record(&p, .measured, w: 0.9, d: 0.5)
        let original = p
        let old = BodyDimensions(height: 1.2, width: 0.2, depth: 0.2, uncertainty: nil,
            source: .measured, provenance: "late old synthetic measurement", recordedAt: 9,
            profileRevision: p.measurementBasisRevision)
        XCTAssertThrowsError(try p.record(old, replacingGeometryRevision: p.geometryRevision))
        XCTAssertEqual(p, original)
    }
    func testGrowthAndMountChangesInvalidateEvenSamePreviewSize() throws {
        var p = try LocalBodyProfile(input: .init(ageYears: 5))
        try record(&p, .measured)
        let old = p.geometryRevision
        try p.update(input: .init(ageYears: 6), mount: p.mount, equipment: p.equipment)
        XCTAssertNotEqual(old, p.geometryRevision); XCTAssertTrue(p.dimensions.isEmpty)
        let revision = p.geometryRevision, mount = p.mountRevision
        try p.update(input: p.input, mount: .init(up: 1), equipment: p.equipment)
        XCTAssertNotEqual(revision, p.geometryRevision); XCTAssertNotEqual(mount, p.mountRevision)
        let next = p.geometryRevision
        XCTAssertFalse(try p.update(input: p.input, mount: p.mount, equipment: p.equipment))
        XCTAssertEqual(next, p.geometryRevision)
    }
    func testGenderOnlyEditPreservesGeometryButUpdatesProfile() throws {
        var p = try LocalBodyProfile(); try record(&p, .measured)
        let old = p.revision, geometry = p.geometryRevision
        try p.update(input: .init(gender: "self-described"), mount: p.mount, equipment: p.equipment)
        XCTAssertNotEqual(old, p.revision); XCTAssertEqual(geometry, p.geometryRevision)
        XCTAssertEqual(p.dimensions.count, 1)
    }
    func testStaleMeasurementCannotRestoreOldGeometry() throws {
        var p = try LocalBodyProfile()
        let value = BodyDimensions(height: 1.5, width: 0.5, depth: 0.3, uncertainty: nil,
            source: .measured, provenance: "synthetic", recordedAt: 10, profileRevision: p.measurementBasisRevision)
        try p.update(input: .init(heightMetres: 1.6), mount: p.mount, equipment: p.equipment)
        XCTAssertThrowsError(try p.record(value, replacingGeometryRevision: p.geometryRevision))
    }
    func testCylinderCoversCornersAndSidewaysNotNarrowed() throws {
        var p = try LocalBodyProfile(); try record(&p, .reported, w: 0.6, d: 0.4)
        let radius = try XCTUnwrap(p.preview().envelope).radius
        XCTAssertEqual(radius, hypot(0.6, 0.4) / 2 + 0.02, accuracy: 0.00001)
        var sideways = try LocalBodyProfile(); try record(&sideways, .reported, w: 0.4, d: 0.6)
        XCTAssertEqual(radius, sideways.preview().envelope?.radius)
    }
    func testMountOffsetAndEquipmentExpandNotShrink() throws {
        var p = try LocalBodyProfile(mount: .init(right: 0.1, up: 1.2, forward: 0.2),
            equipment: .init(radialExtension: 0.1, overheadExtension: 0.2))
        try record(&p, .reported)
        let e = try XCTUnwrap(p.preview().envelope)
        XCTAssertEqual(e.radius, hypot(0.5, 0.3) / 2 + 0.02 + hypot(0.1, 0.2) + 0.1, accuracy: 0.00001)
        XCTAssertEqual(e.height, 1.72, accuracy: 0.00001)
        try p.update(input: p.input, mount: p.mount, equipment: .init(radialExtension: 3, overheadExtension: 3))
        XCTAssertNil(p.preview().envelope) // No unsafe clamp to planner's limits.
    }
    func surface(clearance: Double = 3, blockedSides: Bool = false) -> NavigationSurface {
        var cells = Array(repeating: SurfaceCell(floor: 0, clearance: clearance), count: 10000)
        if blockedSides { for z in 0..<100 { for x in 0..<100 where x < 47 || x > 53 { cells[z * 100 + x].blocked = true } } }
        return .init(level: "test", origin: .init(0,0,0), resolution: 0.1, width: 100, depth: 100, cells: cells)
    }
    func testPreviewCannotGrantClearanceAndRejectsNarrowDoorAndOverhead() throws {
        var p = try LocalBodyProfile(); try record(&p, .measured, h: 1.8, w: 0.6, d: 0.4)
        let a = Point3(5,0,3), b = Point3(5,0,6)
        XCTAssertEqual(p.preview().evaluate(surface: surface(), from: a, to: b), .unknown)
        XCTAssertEqual(p.preview().evaluate(surface: surface(clearance: 1.7), from: a, to: b), .rejected)
        XCTAssertEqual(p.preview().evaluate(surface: surface(blockedSides: true), from: a, to: b), .rejected)
    }
    func testBoundedPrivateRoundTripAndNoIdentityFields() throws {
        var p = try LocalBodyProfile(input: .init(ageYears: 8, gender: "optional", weightKilograms: 25, heightMetres: 1.2))
        try record(&p, .reported)
        let bytes = try JSONEncoder().encode(p)
        XCTAssertEqual(try LocalBodyProfile.decodeLocal(bytes), p)
        let keys = Set(try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any]).keys)
        XCTAssertEqual(keys, ["input", "mount", "equipment", "revision", "measurementBasisRevision", "geometryRevision", "mountRevision", "dimensions"])
        XCTAssertThrowsError(try LocalBodyProfile.decodeLocal(Data(repeating: 32, count: 16385)))
        XCTAssertThrowsError(try LocalBodyProfile.decodeLocal(Data("{}".utf8)))
    }
    func testGeometryEditInvalidatesExistingRouteTicketSessionAndOldCallbacks() throws {
        var (owner, support) = try SpatialIntegrationFixture.prepared()
        let ticket = try owner.next(support: support, now: 10)
        let oldCapture = try SpatialIntegrationFixture.capture(owner: owner)
        let session = owner.sessionID, body = owner.body
        var p = try LocalBodyProfile(); try owner.invalidateBodyProfile(p)
        XCTAssertNotEqual(session, owner.sessionID); XCTAssertEqual(body, owner.body)
        XCTAssertFalse(owner.permits(ticket, now: 10.1)); XCTAssertNil(owner.currentPose(now: 10.1))
        XCTAssertThrowsError(try owner.accept(oldCapture, now: 10.1))
        let same = owner.sessionID
        try p.update(input: .init(gender: "optional"), mount: p.mount, equipment: p.equipment)
        try owner.invalidateBodyProfile(p); XCTAssertEqual(same, owner.sessionID)
        try p.update(input: p.input, mount: .init(up: 1), equipment: p.equipment)
        try owner.invalidateBodyProfile(p); XCTAssertNotEqual(same, owner.sessionID)
    }
}
