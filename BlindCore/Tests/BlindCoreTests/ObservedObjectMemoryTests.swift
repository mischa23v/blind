import XCTest
@testable import BlindCore

final class ObservedObjectMemoryTests: XCTestCase {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let point = Point3(1, 0, -2)

    func context(at date: Date, frame: String = "session-a", heading: BodyHeading? = nil,
                 uncertainty: Double = 0.05) -> ObservedObjectRecallContext {
        ObservedObjectRecallContext(frameID: frame, position: Point3(0, 0, 0),
            bodyHeading: heading ?? BodyHeading(forward: Point3(0, 0, -1), source: .declaredMount, confidence: 0.8, age: 0),
            capturedAt: date, uncertaintyMetres: uncertainty)
    }
    @discardableResult
    func observe(_ memory: inout ObservedObjectMemory, category: String = "cup", room: String = "kitchen",
                 position: Point3? = nil, uncertainty: Double? = nil, validated: Bool = false,
                 source: ObservedObjectSighting.Source = .onDeviceDetector, identity: String? = nil,
                 time: Date? = nil) -> ObservedObjectSighting? {
        let time = time ?? date
        return memory.observe(category: category, source: source, frameID: "session-a", roomID: room,
            roomName: room, position: position, uncertaintyMetres: uncertainty, associationValidated: validated,
            confirmedInstanceID: identity, at: time, now: time)
    }

    func testPassiveObservationCanBeRecalledOutsideViewAfterExpiry() throws {
        var memory = ObservedObjectMemory()
        let sighting = try XCTUnwrap(observe(&memory, category: "backpack", room: "bedroom", position: point, uncertainty: 1))
        XCTAssertEqual(sighting.source, .onDeviceDetector)
        XCTAssertNil(sighting.confirmedInstanceID)
        let later = date.addingTimeInterval(300)
        memory.expire(at: later)
        let recall = memory.recall(category: "my backpack", at: later, context: context(at: later))
        XCTAssertEqual(recall.status, .history)
        XCTAssertEqual(recall.sightings.first?.roomName, "bedroom")
        XCTAssertEqual(recall.sightings.first?.observedAt, date)
        XCTAssertNil(recall.relation)
        XCTAssertEqual(memory.sightings.count, 1)
        let text = ObservedObjectMemory.answer(for: recall, asked: "my backpack", now: later, arabic: false)
        XCTAssertEqual(text, "I last noticed a backpack in the bedroom 5 minutes ago. Its current location is unconfirmed.")
        XCTAssertFalse(text.contains("your"))
    }

    func testDetectorLabelNeverBecomesPersonalIdentity() {
        var memory = ObservedObjectMemory()
        XCTAssertNil(observe(&memory, identity: "personal-cup"))
        XCTAssertNil(observe(&memory, source: .appearanceComparison, identity: "personal-cup"))
        XCTAssertNil(observe(&memory, source: .roomPlanScan, identity: "personal-cup"))
        XCTAssertNotNil(observe(&memory, source: .appearanceComparison))
        let recalled = memory.recall(category: "my cup", at: date)
        XCTAssertNil(recalled.sightings.first?.confirmedInstanceID)
        let text = ObservedObjectMemory.answer(for: recalled, asked: "my cup", now: date, arabic: false)
        XCTAssertTrue(text.contains("possible match for cup"))
        XCTAssertFalse(text.contains("your"))
    }

    func testSimultaneousSameClassIsAmbiguousEvenAtSameSite() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.05, validated: true)
        observe(&memory, position: point, uncertainty: 0.05, validated: true)
        let recalled = memory.recall(category: "cup", at: date, context: context(at: date))
        XCTAssertEqual(recalled.status, .ambiguous)
        XCTAssertEqual(recalled.sightings.count, 2)
        XCTAssertNil(recalled.relation)
    }

    func testRepeatedSingleSiteObservationsDoNotInventMultipleObjects() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.1)
        observe(&memory, position: Point3(1.01, 0, -2.01), uncertainty: 0.1, time: date.addingTimeInterval(1))
        let recalled = memory.recall(category: "cup", at: date.addingTimeInterval(1))
        XCTAssertEqual(recalled.status, .currentCandidate)
        XCTAssertEqual(recalled.sightings.count, 1)
        XCTAssertEqual(memory.sightings.count, 2) // Raw history is retained, not an identity merge.
        XCTAssertNil(recalled.sightings.first?.confirmedInstanceID)
    }

    func testLaterSingleDetectionDoesNotEraseEarlierSimultaneousAmbiguity() {
        var memory = ObservedObjectMemory()
        observe(&memory)
        observe(&memory)
        observe(&memory, time: date.addingTimeInterval(1))
        let recall = memory.recall(category: "cup", at: date.addingTimeInterval(1))
        XCTAssertEqual(recall.status, .ambiguous)
        XCTAssertEqual(recall.sightings.count, 2)
        XCTAssertNil(recall.relation)
    }

    func testRepeatedUnlocatedCategoryUsesLatestBatchButDifferentRoomsStayAmbiguous() {
        var memory = ObservedObjectMemory()
        observe(&memory)
        observe(&memory, time: date.addingTimeInterval(1))
        XCTAssertEqual(memory.recall(category: "cup", at: date.addingTimeInterval(1)).status, .currentCandidate)
        observe(&memory, room: "bedroom", time: date.addingTimeInterval(2))
        XCTAssertEqual(memory.recall(category: "cup", at: date.addingTimeInterval(2)).status, .ambiguous)
    }

    func testSameClassAtDifferentSitesNeverSilentlyMerges() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.1)
        observe(&memory, position: Point3(-3, 0, -2), uncertainty: 0.1, time: date.addingTimeInterval(1))
        let recall = memory.recall(category: "cup", at: date.addingTimeInterval(1))
        XCTAssertEqual(recall.status, .ambiguous)
        XCTAssertNil(recall.relation)
        XCTAssertTrue(ObservedObjectMemory.answer(for: recall, asked: "cup", now: date.addingTimeInterval(1), arabic: false)
            .contains("Which room?"))
    }

    func testVerifiedMovedInstanceSupersedesOldLocationWithoutDeletingHistory() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.05, source: .verifiedInstanceMatcher, identity: "cup-1")
        observe(&memory, room: "bedroom", position: Point3(3, 0, 1), uncertainty: 0.05,
                source: .verifiedInstanceMatcher, identity: "cup-1", time: date.addingTimeInterval(10))
        observe(&memory, position: Point3(-2, 0, 1), uncertainty: 0.05,
                source: .verifiedInstanceMatcher, identity: "cup-2", time: date.addingTimeInterval(10))
        let recalled = memory.recall(category: "cup", confirmedInstanceID: "cup-1", at: date.addingTimeInterval(10))
        XCTAssertEqual(recalled.status, .currentCandidate)
        XCTAssertEqual(recalled.sightings.count, 1)
        XCTAssertEqual(recalled.sightings.first?.roomName, "bedroom")
        XCTAssertEqual(memory.sightings.count, 3)
        XCTAssertEqual(memory.recall(category: "cup", at: date.addingTimeInterval(10)).status, .ambiguous)
    }

    func testFrameChangeAndExplicitResetPreserveHistoryWithoutGeometry() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.05, validated: true)
        XCTAssertNotNil(memory.recall(category: "cup", at: date, context: context(at: date)).relation)
        XCTAssertNil(memory.recall(category: "cup", at: date, context: context(at: date, frame: "session-b")).relation)
        memory.invalidateGeometry()
        let recall = memory.recall(category: "cup", at: date, context: context(at: date))
        XCTAssertEqual(recall.status, .history)
        XCTAssertNil(recall.relation)
        XCTAssertEqual(recall.sightings.first?.position, point)
        XCTAssertEqual(memory.sightings.count, 1)
    }

    func testUnvalidatedCentreDepthNeverPermitsDirection() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.01)
        let recall = memory.recall(category: "cup", at: date, context: context(at: date))
        XCTAssertEqual(recall.status, .currentCandidate)
        XCTAssertNil(recall.relation)
        XCTAssertFalse(ObservedObjectMemory.answer(for: recall, asked: "cup", now: date, arabic: false).contains("metres"))
    }

    func testNoHeadingStaleHeadingAndInvalidHeadingNeverPermitOrientation() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.05, validated: true)
        var invalid = BodyHeading(forward: Point3(0, 0, -1), source: .walking, confidence: 1, age: 0)
        invalid.confidence = .infinity
        let headings: [BodyHeading] = [.unknown, invalid,
            BodyHeading(forward: Point3(0, 0, -1), source: .walking, confidence: 0.7, age: 0),
            BodyHeading(forward: Point3(0, 0, -1), source: .walking, confidence: 0.9, age: -1),
            BodyHeading(forward: Point3(0, 0, -1), source: .walking, confidence: 0.9, age: 0.6),
            BodyHeading(forward: Point3(0, 1, 0), source: .walking, confidence: 0.9, age: 0),
            BodyHeading(forward: Point3(.nan, 0, -1), source: .walking, confidence: 0.9, age: 0)]
        for heading in headings {
            XCTAssertNil(memory.recall(category: "cup", at: date, context: context(at: date, heading: heading)).relation)
        }
    }

    func testPoseAndHeadingAgeAreCombinedAndSpeechRechecksAge() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.05, validated: true)
        let delayed = date.addingTimeInterval(0.3)
        let heading = BodyHeading(forward: Point3(0, 0, -1), source: .walking, confidence: 0.9, age: 0.3)
        XCTAssertNil(memory.recall(category: "cup", at: delayed, context: context(at: date, heading: heading)).relation)
        let fresh = memory.recall(category: "cup", at: date, context: context(at: date))
        XCTAssertNotNil(fresh.relation)
        XCTAssertTrue(ObservedObjectMemory.answer(for: fresh, asked: "cup", now: date, arabic: false).contains("metres"))
        XCTAssertFalse(ObservedObjectMemory.answer(for: fresh, asked: "cup", now: date.addingTimeInterval(1), arabic: false).contains("metres"))
        XCTAssertNil(memory.recall(category: "cup", at: date, context: context(at: date.addingTimeInterval(1))).relation)
    }

    func testUncertainOrMissingDepthAndPoseHaveNoDirection() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.26, validated: true)
        XCTAssertNil(memory.recall(category: "cup", at: date, context: context(at: date)).relation)
        memory.clear()
        observe(&memory, position: point)
        XCTAssertNil(memory.recall(category: "cup", at: date, context: context(at: date)).relation)
        memory.clear()
        observe(&memory, position: point, uncertainty: 0.05, validated: true)
        for uncertainty in [Double.nan, .infinity, -1, 0.26] {
            XCTAssertNil(memory.recall(category: "cup", at: date, context: context(at: date, uncertainty: uncertainty)).relation)
        }
    }

    func testFutureNonfiniteAndMalformedInputsAreRejected() {
        var memory = ObservedObjectMemory()
        XCTAssertNil(memory.observe(category: "cup", source: .onDeviceDetector, frameID: "f",
                                    at: date.addingTimeInterval(0.01), now: date))
        for bad in [Double.nan, .infinity, -.infinity, Double.greatestFiniteMagnitude] {
            XCTAssertNil(observe(&memory, position: Point3(bad, 0, 1)))
            XCTAssertNil(observe(&memory, uncertainty: bad))
            XCTAssertNil(memory.observe(category: "cup", source: .onDeviceDetector, frameID: "f",
                                        at: Date(timeIntervalSince1970: bad), now: date))
        }
        XCTAssertNil(observe(&memory, category: " "))
        XCTAssertNil(observe(&memory, category: "my"))
        XCTAssertNil(observe(&memory, category: "cup\nturn right"))
        XCTAssertNil(observe(&memory, category: String(repeating: "x", count: 81)))
        XCTAssertNil(observe(&memory, uncertainty: -0.1))
        XCTAssertNil(observe(&memory, validated: true))
        XCTAssertNil(memory.observe(category: "cup", source: .onDeviceDetector, frameID: nil, position: point, at: date, now: date))
        XCTAssertTrue(memory.sightings.isEmpty)
    }

    func testBoxesAreFiniteNormalizedAndPersistedWithoutImages() throws {
        var memory = ObservedObjectMemory()
        let box = ObservedObjectBox(x: 0.2, y: 0.3, width: 0.2, height: 0.3)
        XCTAssertNotNil(memory.observe(category: "cup", source: .onDeviceDetector, frameID: "f", box: box, at: date, now: date))
        XCTAssertEqual(memory.sightings.first?.box, box)
        for bad in [ObservedObjectBox(x: -0.1, y: 0, width: 0.2, height: 0.2),
                    ObservedObjectBox(x: 0, y: 0, width: 0, height: 1),
                    ObservedObjectBox(x: 0, y: 0.9, width: 1, height: 0.2),
                    ObservedObjectBox(x: .nan, y: 0, width: 1, height: 1)] {
            XCTAssertNil(memory.observe(category: "cup", source: .onDeviceDetector, frameID: "f", box: bad, at: date, now: date))
        }
        let json = try JSONEncoder().encode(memory)
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("imageData"))
    }

    func testExpiryDoesNotDeleteHistoryOrReviveAfterClockRollback() {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.05, validated: true)
        memory.expire(at: date.addingTimeInterval(9))
        XCTAssertEqual(memory.recall(category: "cup", at: date).status, .history)
        XCTAssertNil(memory.recall(category: "cup", at: date, context: context(at: date)).relation)
        XCTAssertEqual(memory.sightings.count, 1)
        XCTAssertEqual(memory.recall(category: "cup", at: date.addingTimeInterval(-1)).status, .notFound)
    }

    func testCodableRestoresHistoryAndMigratesLegacyFieldsFailClosed() throws {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point, uncertainty: 0.05, validated: true)
        let data = try JSONEncoder().encode(memory)
        let restored = try JSONDecoder().decode(ObservedObjectMemory.self, from: data)
        XCTAssertTrue(restored.valid)
        XCTAssertEqual(restored.sightings.first?.observedAt, date)
        XCTAssertEqual(restored.sightings.first?.position, point)
        XCTAssertEqual(restored.recall(category: "cup", at: date).status, .history)
        XCTAssertNil(restored.recall(category: "cup", at: date, context: context(at: date)).relation)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "schemaVersion")
        var records = try XCTUnwrap(object["sightings"] as? [[String: Any]])
        for key in ["associationValidated", "confirmedInstanceID", "geometryValid", "isActive", "categoryKey"] {
            records[0].removeValue(forKey: key)
        }
        object["sightings"] = records
        let migrated = try JSONDecoder().decode(ObservedObjectMemory.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(migrated.sightings.first?.associationValidated, false)
        XCTAssertEqual(migrated.sightings.first?.categoryKey, "cup")
        XCTAssertTrue(try JSONDecoder().decode(ObservedObjectMemory.self, from: Data("{}".utf8)).sightings.isEmpty)
    }

    func testCodableRejectsCorruptionUnsupportedVersionAndUntrustedSource() throws {
        var memory = ObservedObjectMemory()
        observe(&memory, position: point)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(memory)) as? [String: Any])
        func rejects(_ object: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws {
            let data = try JSONSerialization.data(withJSONObject: object)
            XCTAssertThrowsError(try JSONDecoder().decode(ObservedObjectMemory.self, from: data), file: file, line: line)
        }
        var unknown = original; unknown["schemaVersion"] = 99; try rejects(unknown)
        for (key, value): (String, Any) in [("source", "llm"), ("categoryKey", "different"), ("uncertaintyMetres", -1),
                                          ("confirmedInstanceID", "not-verified"), ("frameID", ""), ("id", "")] {
            var object = original
            var records = try XCTUnwrap(object["sightings"] as? [[String: Any]])
            records[0][key] = value; object["sightings"] = records; try rejects(object)
        }
        var duplicate = original
        let records = try XCTUnwrap(original["sightings"] as? [[String: Any]])
        duplicate["sightings"] = records + records; try rejects(duplicate)
        duplicate["sightings"] = Array(repeating: records[0], count: ObservedObjectMemory.limit + 1); try rejects(duplicate)
    }

    func testBoundedCacheEvictsOldestAndSupportsScopedDeletion() throws {
        var memory = ObservedObjectMemory()
        for index in 0...ObservedObjectMemory.limit {
            observe(&memory, category: "item \(index)", room: index % 2 == 0 ? "kitchen" : "bedroom",
                    time: date.addingTimeInterval(Double(index)))
        }
        XCTAssertEqual(memory.sightings.count, ObservedObjectMemory.limit)
        XCTAssertEqual(memory.recall(category: "item 0", at: date.addingTimeInterval(300)).status, .notFound)
        XCTAssertTrue(memory.valid)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(memory).count, ObservedObjectMemory.maximumEncodedBytes)
        XCTAssertTrue(memory.forget(category: "item 1"))
        XCTAssertFalse(memory.forget(category: "item"))
        XCTAssertTrue(memory.forgetRoom("kitchen"))
        XCTAssertTrue(memory.sightings.allSatisfy { $0.roomID == "bedroom" })
        memory.clear(); XCTAssertTrue(memory.sightings.isEmpty)
    }

    func testMultibyteMetadataAlsoRespectsEncodedPayloadBudget() throws {
        var memory = ObservedObjectMemory()
        let field = String(repeating: "غ", count: 128)
        for index in 0..<ObservedObjectMemory.limit {
            let time = date.addingTimeInterval(Double(index))
            XCTAssertNotNil(memory.observe(category: String(repeating: "ح", count: 80), source: .verifiedInstanceMatcher,
                frameID: field, roomID: field, roomName: field, position: point, uncertaintyMetres: 1,
                confirmedInstanceID: field, box: ObservedObjectBox(x: 0, y: 0, width: 1, height: 1), at: time, now: time))
        }
        XCTAssertTrue(memory.valid)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(memory).count, ObservedObjectMemory.maximumEncodedBytes)
        XCTAssertLessThan(memory.sightings.count, ObservedObjectMemory.limit)
        XCTAssertEqual(memory.sightings.last?.observedAt, date.addingTimeInterval(Double(ObservedObjectMemory.limit - 1)))
    }

    func testFutureRestoredTimestampsAreNotRecalledAsCurrentOrHistory() throws {
        var memory = ObservedObjectMemory()
        observe(&memory, time: date.addingTimeInterval(60))
        let restored = try JSONDecoder().decode(ObservedObjectMemory.self, from: JSONEncoder().encode(memory))
        XCTAssertEqual(restored.recall(category: "cup", at: date).status, .notFound)
        XCTAssertNil(restored.recall(category: "cup", at: date, context: context(at: date)).relation)
    }

    func testArabicRecallIsHistoricalAndNoPossessiveIdentityClaim() {
        var memory = ObservedObjectMemory()
        observe(&memory, category: "حقيبة", room: "غرفة النوم")
        let later = date.addingTimeInterval(300)
        let recall = memory.recall(category: "الحقيبة", at: later)
        let text = ObservedObjectMemory.answer(for: recall, asked: "الحقيبة", now: later, arabic: true)
        XCTAssertTrue(text.contains("غرفة النوم"))
        XCTAssertTrue(text.contains("قبل 5 دقائق"))
        XCTAssertTrue(text.contains("مكانه الآن غير مؤكد"))
        XCTAssertFalse(text.contains("حقيبتك"))
    }

    func testMissingObservationDoesNotAssertAbsence() {
        let recall = ObservedObjectMemory().recall(category: "cup", at: date)
        XCTAssertEqual(recall.status, .notFound)
        XCTAssertNil(recall.relation)
        let text = ObservedObjectMemory.answer(for: recall, asked: "cup", now: date, arabic: false)
        XCTAssertTrue(text.contains("does not mean it is absent"))
    }

    func spotContext(at time: Date, frame: String = "map-a", aligned: Bool = true,
                     ids: Set<String> = ["scan-point"], headingError: Double = 2,
                     placeID: String? = nil, floorID: String? = nil) -> ObservedObjectRecallContext {
        ObservedObjectRecallContext(frameID: frame, position: Point3(0, 0, 0),
            bodyHeading: BodyHeading(forward: Point3(0, 0, -1), source: .declaredMount, confidence: 0.8, age: 0),
            capturedAt: time, uncertaintyMetres: 0.05, recordedFrameAlignmentValidated: aligned,
            placeID: placeID, floorID: floorID, allowedRecordedPointIDs: ids, headingUncertaintyDegrees: headingError)
    }

    @discardableResult
    func observeSpot(_ memory: inout ObservedObjectMemory, position: Point3 = Point3(0, 0, -3),
                     validated: Bool = true, placeID: String? = nil, floorID: String? = nil,
                     source: ObservedObjectSighting.Source = .roomPlanScan) -> ObservedObjectSighting? {
        memory.observe(category: "desk", source: source, sourceObservationID: "scan-point", frameID: "map-a",
            placeID: placeID, floorID: floorID, position: position, uncertaintyMetres: 0.05,
            recordedSpotValidated: validated, at: date, now: date)
    }

    func testHistoricalSearchAcrossHousesRoomsFloorsAndLandmarks() throws {
        var memory = ObservedObjectMemory()
        for (place, floor, landmark, offset) in [("home", "ground", "desk", 0.0), ("aunt's house", "upper", "sofa", 1.0)] {
            let time = date.addingTimeInterval(offset)
            XCTAssertNotNil(memory.observe(category: "phone", source: .onDeviceDetector, frameID: "shared-test-frame",
                roomID: "bedroom", roomName: "bedroom", placeID: place, placeName: place, floorID: floor,
                floorName: floor + " floor", landmarks: [landmark], at: time, now: time))
        }
        let later = date.addingTimeInterval(300)
        let all = memory.recall(category: "phone", at: later)
        XCTAssertEqual(all.status, .ambiguous)
        XCTAssertEqual(all.sightings.count, 2)
        XCTAssertTrue(ObservedObjectMemory.answer(for: all, asked: "phone", now: later, arabic: false).contains("Which house or place?"))
        let home = memory.recall(category: "phone", placeName: "HOME", floorID: "ground", roomName: "bedroom", landmarks: ["desk"], at: later)
        XCTAssertEqual(home.status, .history)
        XCTAssertEqual(home.sightings.first?.placeID, "home")
        XCTAssertNil(home.sightings.first?.position)
        XCTAssertNil(home.relation)
        XCTAssertNil(home.recordedSpotOrientation)
        XCTAssertEqual(memory.recall(category: "phone", placeID: "home", landmarks: ["sofa"], at: later).status, .notFound)
        XCTAssertEqual(memory.recall(category: "phone", floorID: "unknown", at: later).status, .notFound)
    }

    func testUnknownPlaceMetadataIsOmittedAndCannotSupplyCoordinates() throws {
        var memory = ObservedObjectMemory()
        observe(&memory, category: "laptop")
        let sighting = try XCTUnwrap(memory.sightings.first)
        XCTAssertNil(sighting.placeID); XCTAssertNil(sighting.placeName)
        XCTAssertNil(sighting.floorID); XCTAssertNil(sighting.floorName)
        XCTAssertTrue(sighting.landmarks.isEmpty); XCTAssertNil(sighting.position)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(sighting)) as? [String: Any])
        for key in ["placeID", "placeName", "floorID", "floorName", "position"] { XCTAssertNil(encoded[key]) }
        XCTAssertEqual(memory.recall(category: "laptop", placeID: "home", at: date).status, .notFound)
    }

    func testNewPlaceAndLandmarkFieldsValidateAndMigrate() throws {
        var memory = ObservedObjectMemory()
        XCTAssertNil(memory.observe(category: "phone", source: .onDeviceDetector, frameID: "f", landmarks: ["desk", "Desk"], at: date, now: date))
        XCTAssertNil(memory.observe(category: "phone", source: .onDeviceDetector, frameID: "f", landmarks: Array(repeating: "x", count: 9), at: date, now: date))
        XCTAssertNil(memory.observe(category: "phone", source: .onDeviceDetector, frameID: "f", placeName: "home\nturn left", at: date, now: date))
        observe(&memory)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(memory)) as? [String: Any])
        object["schemaVersion"] = 1
        var rows = try XCTUnwrap(object["sightings"] as? [[String: Any]])
        for key in ["sourceObservationID", "placeID", "placeName", "floorID", "floorName", "landmarks", "recordedSpotValidated", "recordedSpotGeometryValid"] {
            rows[0].removeValue(forKey: key)
        }
        object["sightings"] = rows
        let restored = try JSONDecoder().decode(ObservedObjectMemory.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(restored.valid)
        XCTAssertEqual(restored.sightings.first?.recordedSpotValidated, false)
        XCTAssertNil(restored.sightings.first?.placeID)
        XCTAssertEqual(restored.recall(category: "cup", at: date).status, .history)
    }

    func testRecordedSpotOrientationIsSeparateFromPresentObjectAuthority() throws {
        var memory = ObservedObjectMemory()
        let sighting = try XCTUnwrap(observeSpot(&memory))
        let later = date.addingTimeInterval(3600)
        memory.expire(at: later)
        let recall = memory.recall(category: "desk", at: later, context: spotContext(at: later))
        XCTAssertEqual(recall.status, .history)
        XCTAssertNil(recall.relation)
        XCTAssertEqual(recall.recordedSpotOrientation?.sightingID, sighting.id)
        XCTAssertEqual(recall.recordedSpotOrientation?.observedAt, date)
        XCTAssertEqual(recall.recordedSpotOrientation?.relation.sector, .ahead)
        let answer = try XCTUnwrap(ObservedObjectMemory.recordedSpotAnswer(for: recall, now: later, arabic: false))
        XCTAssertTrue(answer.contains("Earlier recorded spot"))
        XCTAssertTrue(answer.contains("does not confirm the object is there now or that the route is clear"))
        XCTAssertFalse(ObservedObjectMemory.answer(for: recall, asked: "desk", now: later, arabic: false).contains("metres"))
        XCTAssertNil(ObservedObjectMemory.recordedSpotAnswer(for: recall, now: later.addingTimeInterval(1), arabic: false))
    }

    func testHistoricalOrientationRequiresExactReceiptAndValidatedAssociation() {
        var memory = ObservedObjectMemory()
        observeSpot(&memory, validated: false)
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        memory.clear(); observeSpot(&memory)
        for ctx in [spotContext(at: date, aligned: false), spotContext(at: date, ids: []),
                    spotContext(at: date, ids: ["different-point"]), spotContext(at: date, frame: "map-b"),
                    spotContext(at: date.addingTimeInterval(-1)), spotContext(at: date.addingTimeInterval(1))] {
            XCTAssertNil(memory.recall(category: "desk", at: date, context: ctx).recordedSpotOrientation)
        }
        XCTAssertNil(memory.recall(category: "desk", at: date, context: context(at: date, frame: "map-a")).recordedSpotOrientation)
    }

    func testRecordedSpotResetAndReloadRequireExplicitFreshRevalidation() throws {
        var memory = ObservedObjectMemory()
        observeSpot(&memory)
        memory.invalidateGeometry()
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        XCTAssertFalse(memory.revalidateRecordedFrame(using: spotContext(at: date, ids: ["wrong"]), at: date))
        XCTAssertTrue(memory.revalidateRecordedFrame(using: spotContext(at: date), at: date))
        XCTAssertNotNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).relation)
        var restored = try JSONDecoder().decode(ObservedObjectMemory.self, from: JSONEncoder().encode(memory))
        XCTAssertNil(restored.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        XCTAssertTrue(restored.revalidateRecordedFrame(using: spotContext(at: date), at: date))
        XCTAssertNotNil(restored.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        XCTAssertEqual(restored.recall(category: "desk", at: date).status, .history)
    }

    func testHistoricalOrientationRejectsNearSpotsSectorCrossingAndUnknownHeadingError() {
        var memory = ObservedObjectMemory()
        observeSpot(&memory, position: Point3(0, 0, -1))
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        memory.clear()
        let angle = 29.0 * Double.pi / 180
        observeSpot(&memory, position: Point3(sin(angle) * 3, 0, -cos(angle) * 3))
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        memory.clear(); observeSpot(&memory)
        for error in [Double.infinity, .nan, -1, 10.01] {
            XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date, headingError: error)).recordedSpotOrientation)
        }
    }

    func testHistoricalOrientationDoesNotPointAcrossPlacesFloorsOrVerticalLevels() {
        var memory = ObservedObjectMemory()
        observeSpot(&memory, placeID: "home", floorID: "ground")
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        XCTAssertNil(memory.recall(category: "desk", at: date,
            context: spotContext(at: date, placeID: "other-home", floorID: "ground")).recordedSpotOrientation)
        XCTAssertNil(memory.recall(category: "desk", at: date,
            context: spotContext(at: date, placeID: "home", floorID: "upper")).recordedSpotOrientation)
        XCTAssertNotNil(memory.recall(category: "desk", at: date,
            context: spotContext(at: date, placeID: "home", floorID: "ground")).recordedSpotOrientation)
        memory.clear(); observeSpot(&memory, position: Point3(0, 3, -3))
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
    }

    func testHistoricalBearingUsesTangentBoundAndCapsCombinedPositionError() {
        var memory = ObservedObjectMemory()
        let angle = 17.0 * Double.pi / 180
        // atan2(0.25, 1.1) would incorrectly fit inside the 30-degree ahead sector;
        // the full uncertainty disk has the wider asin(0.25 / 1.1) tangent angle.
        memory.observe(category: "desk", source: .roomPlanScan, sourceObservationID: "scan-point", frameID: "map-a",
            position: Point3(sin(angle) * 1.1, 0, -cos(angle) * 1.1), uncertaintyMetres: 0.2,
            recordedSpotValidated: true, at: date, now: date)
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date, headingError: 0)).recordedSpotOrientation)
        memory.clear()
        memory.observe(category: "desk", source: .roomPlanScan, sourceObservationID: "scan-point", frameID: "map-a",
            position: Point3(0, 0, -3), uncertaintyMetres: 0.25, recordedSpotValidated: true, at: date, now: date)
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
    }

    func testValidationUpgradeBindsExactRoomPlanSourceFrameAndPointWithoutLiveAuthority() throws {
        var memory = ObservedObjectMemory()
        let original = try XCTUnwrap(observeSpot(&memory, validated: false))
        XCTAssertFalse(memory.applyRecordedPointValidation(frameID: "wrong", sourceObservationID: "scan-point", position: Point3(0, 0, -3), uncertaintyMetres: 0.05))
        XCTAssertFalse(memory.applyRecordedPointValidation(frameID: "map-a", sourceObservationID: "wrong", position: Point3(0, 0, -3), uncertaintyMetres: 0.05))
        XCTAssertFalse(memory.applyRecordedPointValidation(frameID: "map-a", sourceObservationID: "scan-point", position: Point3(0.01, 0, -3), uncertaintyMetres: 0.05))
        for uncertainty in [Double.nan, .infinity, -0.1, 0.26] {
            XCTAssertFalse(memory.applyRecordedPointValidation(frameID: "map-a", sourceObservationID: "scan-point", position: Point3(0, 0, -3), uncertaintyMetres: uncertainty))
        }
        XCTAssertTrue(memory.applyRecordedPointValidation(frameID: "map-a", sourceObservationID: "scan-point", position: Point3(0, 0, -3), uncertaintyMetres: 0.1))
        XCTAssertEqual(memory.sightings.count, 1)
        XCTAssertEqual(memory.sightings.first?.id, original.id)
        XCTAssertEqual(memory.sightings.first?.observedAt, original.observedAt)
        XCTAssertEqual(memory.sightings.first?.associationValidated, false)
        XCTAssertNil(memory.sightings.first?.confirmedInstanceID)
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        XCTAssertTrue(memory.revalidateRecordedFrame(using: spotContext(at: date), at: date))
        XCTAssertNotNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).recordedSpotOrientation)
        XCTAssertNil(memory.recall(category: "desk", at: date, context: spotContext(at: date)).relation)
        memory.clear(); observeSpot(&memory, validated: false, source: .onDeviceDetector)
        XCTAssertFalse(memory.applyRecordedPointValidation(frameID: "map-a", sourceObservationID: "scan-point", position: Point3(0, 0, -3), uncertaintyMetres: 0.05))
    }

    func testTransientLeaseFlagsAreNotPersistedAndUpgradeRemainsBoundedAndAtomic() throws {
        var memory = ObservedObjectMemory()
        let field = String(repeating: "غ", count: 128)
        for index in 0..<ObservedObjectMemory.limit {
            let time = date.addingTimeInterval(Double(index))
            memory.observe(category: String(repeating: "ح", count: 80), source: .roomPlanScan,
                sourceObservationID: "scan-point", frameID: field, roomID: field, roomName: field,
                placeID: field, placeName: field, floorID: field, floorName: field,
                position: Point3(0, 0, -3), at: time, now: time)
        }
        let before = memory
        let changed = memory.applyRecordedPointValidation(frameID: field, sourceObservationID: "scan-point",
            position: Point3(0, 0, -3), uncertaintyMetres: 0.05)
        XCTAssertTrue(memory.valid)
        XCTAssertEqual(memory.sightings.count, before.sightings.count)
        if !changed { XCTAssertEqual(memory, before) }
        let data = try JSONEncoder().encode(memory)
        XCTAssertLessThanOrEqual(data.count, ObservedObjectMemory.maximumEncodedBytes)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("\"isActive\""))
        XCTAssertFalse(json.contains("\"geometryValid\""))
        XCTAssertFalse(json.contains("\"recordedSpotGeometryValid\""))
        memory.invalidateGeometry()
        XCTAssertEqual(try JSONEncoder().encode(memory).count, data.count)
        XCTAssertTrue(memory.valid)
    }

    func testRoomPlanFurnitureSurvivesMoreThanCacheCapacityOfPassiveDetections() throws {
        var memory = ObservedObjectMemory()
        let anchor = try XCTUnwrap(observeSpot(&memory, validated: false))
        for index in 1...(ObservedObjectMemory.limit + 50) {
            observe(&memory, category: "cup", time: date.addingTimeInterval(Double(index * 3)))
        }
        let later = date.addingTimeInterval(1000)
        let recalled = memory.recall(category: "desk", at: later)
        XCTAssertEqual(recalled.status, .history)
        XCTAssertEqual(recalled.sightings.first?.id, anchor.id)
        XCTAssertEqual(recalled.sightings.first?.observedAt, date)
        XCTAssertNil(recalled.relation)
        XCTAssertNil(recalled.recordedSpotOrientation)
        XCTAssertEqual(memory.sightings.count, ObservedObjectMemory.limit)
        XCTAssertTrue(memory.valid)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(memory).count, ObservedObjectMemory.maximumEncodedBytes)
    }

    func testRoomPlanReservationIsBoundedAndKeepsNewestScanHistory() throws {
        var memory = ObservedObjectMemory()
        let scanCount = ObservedObjectMemory.roomPlanReservation + 10
        for index in 0..<scanCount {
            let time = date.addingTimeInterval(Double(index))
            memory.observe(category: "furniture \(index)", source: .roomPlanScan,
                sourceObservationID: "scan-\(index)", frameID: "map-a", at: time, now: time)
        }
        for index in 0..<ObservedObjectMemory.limit {
            observe(&memory, time: date.addingTimeInterval(Double(1000 + index)))
        }
        let scans = memory.sightings.filter { $0.source == .roomPlanScan }
        XCTAssertEqual(scans.count, ObservedObjectMemory.roomPlanReservation)
        XCTAssertFalse(scans.contains { $0.sourceObservationID == "scan-0" })
        XCTAssertTrue(scans.contains { $0.sourceObservationID == "scan-\(scanCount - 1)" })
        XCTAssertEqual(memory.sightings.count, ObservedObjectMemory.limit)
        XCTAssertTrue(memory.valid)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(memory).count, ObservedObjectMemory.maximumEncodedBytes)
    }
}
