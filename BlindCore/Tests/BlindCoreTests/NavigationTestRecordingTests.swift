import XCTest
@testable import BlindCore

final class NavigationTestRecordingTests: XCTestCase {
    private let session = UUID()
    private var sampler = RecordedRouteSampler()
    private let map = SpatialMapBinding(mapID: "synthetic-room", frameID: "map-frame", revision: "r1")
    private func sample(_ time: Double, tracking: NativeObservationRecord.Tracking = .normal, frameID: String = "camera-frame") throws -> RecordedRouteSample {
        return try sampler.observe(.init(sessionID: session, coordinateFrameID: frameID, producer: .arkit,
            sourceID: "synthetic-\(time)", mapTarget: map, capturedAt: time, receivedAt: time,
            observedAt: Date(timeIntervalSince1970: 1000 + time), tracking: tracking,
            cameraConvention: .arKitRightUpBack, cameraToSessionWorld: .identity,
            intrinsics: .init(width: 2, height: 2, fx: 1, fy: 1, cx: 1, cy: 1), depth: nil))
    }
    private func plan(at time: Double = 0, expiry: Double = 10, aligned: Bool = true) -> NavigationTestRecording.Plan {
        .init(revision: UUID(), goalRevision: UUID(), map: map, points: [Point3(0,0,0), Point3(2,0,0)],
              alignment: aligned ? .init(sessionID: session, sourceFrameID: "camera-frame", revision: "registration-1",
                calibrationRevision: "mount-1", evidenceID: "synthetic-only", map: map, sourceToMap: .identity,
                validFrom: 0, validThrough: expiry) : nil, recordedAt: time)
    }
    private var savedFrame: SavedWorldFrame {
        .init(placeID: UUID().uuidString, revision: UUID().uuidString,
              worldMapSHA256: String(repeating: "a", count: 64), roomCaptureSHA256: String(repeating: "b", count: 64),
              originAnchorID: UUID().uuidString, capturedAt: Date(timeIntervalSince1970: 100))
    }
    private func recovery(_ frame: SavedWorldFrame) -> SavedWorldFrameRecovery {
        var value = SavedWorldFrameRecovery(); value.begin(frame: frame, sessionID: session, now: 0)
        _ = value.observe(sessionID: session, tracking: .relocalizing, mappingAvailable: true, originAnchorMatches: true, frameTime: 0, now: 0)
        for time in [0.1, 0.2, 0.3] {
            _ = value.observe(sessionID: session, tracking: .normal, mappingAvailable: true, originAnchorMatches: true, frameTime: time, now: time)
        }
        return value
    }
    func testSameFrameAtomicArchivePreservesRawCameraAndNoAuthority() throws {
        let frame = savedFrame; let gate = recovery(frame)
        let receipt = try XCTUnwrap(gate.cameraAssociation(sessionID: session, capturedAt: 0.3, now: 0.31))
        let raw = try sample(0.3, frameID: receipt.sourceFrameID)
        var value = try NavigationTestRecording(explicitStartAt: 0)
        try value.observe(raw, receivedAt: 0.4, sameFrameReceipt: receipt)
        XCTAssertEqual(value.archiveEvents.count, 1)
        XCTAssertLessThanOrEqual(try value.archiveEvents[0].encoded().count, NavigationTestArchiveEvent.maximumBytes)
        XCTAssertEqual(NavigationTestRecording.maximumSamples + 2 * NavigationTestRecording.maximumEvents + 1, 3_257)
        XCTAssertNil(value.entries[0].cameraInMap); XCTAssertTrue(value.overlaySegments.isEmpty)
        XCTAssertEqual(value.sameFrameSegments(for: frame), [[raw.cameraPosition]])
        let events = try value.archiveEvents.map { try NavigationTestArchiveEvent(payload: $0.encoded()) }
        let restored = try NavigationTestRecording.restored(id: value.id, startedAt: 0, events: events)
        XCTAssertEqual(restored.sameFrameAssociations, value.sameFrameAssociations)
        XCTAssertEqual(restored.entries, value.entries); XCTAssertEqual(restored.status, .stopped)
        XCTAssertTrue(restored.restoredInterrupted); XCTAssertNil(restored.endedAt)
        XCTAssertFalse(restored.permitsPhysicalGuidance); XCTAssertFalse(restored.sameFrameAssociations[0].permitsPhysicalGuidance)
        XCTAssertTrue(restored.sameFrameSegments(for: savedFrame).isEmpty)
        XCTAssertThrowsError(try NavigationTestRecording.restored(id: value.id, startedAt: 0, events: events + events))
        let empty = try NavigationTestRecording.restored(id: value.id, startedAt: 0, events: [])
        XCTAssertTrue(empty.sameFrameAssociations.isEmpty)
    }
    func testMismatchedReceiptKeepsRawSampleWithoutAssociation() throws {
        let frame = savedFrame; let gate = recovery(frame)
        let receipt = try XCTUnwrap(gate.cameraAssociation(sessionID: session, capturedAt: 0.3, now: 0.31))
        var value = try NavigationTestRecording(explicitStartAt: 0)
        try value.observe(sample(0.3), receivedAt: 0.4, sameFrameReceipt: receipt) // wrong source frame
        try value.observe(sample(0.5, frameID: receipt.sourceFrameID), receivedAt: 0.5, sameFrameReceipt: receipt) // wrong capture
        XCTAssertEqual(value.entries.count, 2); XCTAssertTrue(value.sameFrameAssociations.isEmpty)
        let old = try NavigationTestRecording.restored(id: value.id, startedAt: 0, events: value.archiveEvents)
        XCTAssertEqual(old.entries, value.entries); XCTAssertTrue(old.sameFrameAssociations.isEmpty)
    }
    func testSameFrameTraceBreaksAtMissingReceiptTrackingLossAndRecoveryEpoch() throws {
        let frame = savedFrame; var gate = recovery(frame)
        let source = "arkit-session:\(session.uuidString)"
        var value = try NavigationTestRecording(explicitStartAt: 0)
        for time in [0.3, 0.5] {
            if time > 0.3 { _ = gate.observe(sessionID: session, tracking: .normal, mappingAvailable: true, originAnchorMatches: true, frameTime: time, now: time) }
            try value.observe(sample(time, frameID: source), receivedAt: time,
                sameFrameReceipt: gate.cameraAssociation(sessionID: session, capturedAt: time, now: time))
        }
        XCTAssertEqual(value.sameFrameSegments(for: frame).map(\.count), [2])
        try value.observe(sample(0.7, frameID: source), receivedAt: 0.7) // no receipt, no bridge across it
        _ = gate.observe(sessionID: session, tracking: .normal, mappingAvailable: true, originAnchorMatches: true, frameTime: 0.9, now: 0.9)
        try value.observe(sample(0.9, frameID: source), receivedAt: 0.9,
            sameFrameReceipt: gate.cameraAssociation(sessionID: session, capturedAt: 0.9, now: 0.9))
        gate.observeTrackingInterruption(sessionID: session, tracking: .relocalizing, frameTime: 1, now: 1)
        for time in [1.1, 1.2, 1.3] {
            _ = gate.observe(sessionID: session, tracking: .normal, mappingAvailable: true, originAnchorMatches: true, frameTime: time, now: time)
        }
        try value.observe(sample(1.3, frameID: source), receivedAt: 1.3,
            sameFrameReceipt: gate.cameraAssociation(sessionID: session, capturedAt: 1.3, now: 1.3))
        XCTAssertEqual(value.sameFrameSegments(for: frame).map(\.count), [2, 1, 1])
        XCTAssertNotEqual(value.sameFrameAssociations.first?.recoveryID, value.sameFrameAssociations.last?.recoveryID)
        try value.observe(sample(1.5, tracking: .limited, frameID: source), receivedAt: 1.5)
        XCTAssertEqual(value.sameFrameAssociations.count, 4)
    }
    func testSameFrameMetadataFutureVersionAndMismatchRejected() throws {
        let frame = savedFrame; let gate = recovery(frame)
        let receipt = try XCTUnwrap(gate.cameraAssociation(sessionID: session, capturedAt: 0.3, now: 0.31))
        var value = try NavigationTestRecording(explicitStartAt: 0)
        try value.observe(sample(0.3, frameID: receipt.sourceFrameID), receivedAt: 0.4, sameFrameReceipt: receipt)
        let metadata = try XCTUnwrap(value.sameFrameAssociations.first)
        let data = try JSONEncoder().encode(metadata)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for (key, replacement) in [("schemaVersion", 2 as Any), ("capturedAt", 99 as Any), ("observationID", UUID().uuidString as Any)] {
            var corrupt = object; corrupt[key] = replacement
            let decoded = try JSONDecoder().decode(NavigationTestRecording.SameFrameAssociation.self,
                from: JSONSerialization.data(withJSONObject: corrupt))
            XCTAssertThrowsError(try NavigationTestRecording.restored(id: value.id, startedAt: 0,
                events: [.associatedSample(value.entries[0], decoded)]))
        }
    }
    func testArchiveRoundTripKeepsRawSamplesPlansMarkersAndStops() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan()); try recording.observe(sample(0.2), receivedAt: 0.3)
        try recording.mark(.apparentFurnitureCrossing, at: 0.4); try recording.stop(at: 0.5)
        let decoded = try recording.archiveEvents.map { try NavigationTestArchiveEvent(payload: $0.encoded()) }
        var restored = try NavigationTestRecording.restored(id: recording.id, startedAt: recording.startedAt, events: decoded)
        XCTAssertEqual(restored.entries, recording.entries); XCTAssertEqual(restored.plans, recording.plans)
        XCTAssertEqual(restored.markers, recording.markers); XCTAssertEqual(restored.archiveEvents, recording.archiveEvents)
        XCTAssertTrue(restored.restoredHistorical); XCTAssertFalse(restored.restoredInterrupted)
        XCTAssertEqual(restored.status, .stopped); XCTAssertFalse(restored.permitsPhysicalGuidance)
        XCTAssertThrowsError(try restored.observe(sample(0.6), receivedAt: 0.6))
    }
    func testInterruptedPrefixReopensStoppedWithoutInventedStopTime() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.observe(sample(0.2), receivedAt: 0.2)
        let restored = try NavigationTestRecording.restored(id: recording.id, startedAt: 0, events: recording.archiveEvents)
        XCTAssertTrue(restored.restoredInterrupted); XCTAssertEqual(restored.status, .stopped)
        XCTAssertNil(restored.endedAt); XCTAssertEqual(restored.archiveEvents, recording.archiveEvents)
        XCTAssertEqual(restored.entries, recording.entries)
    }
    func testArchiveRejectsInventedAssociationAndTerminalCorruption() throws {
        let observed = try sample(0.2)
        let invented = NavigationTestRecording.Entry(sample: observed, receivedAt: 0.2, planIndex: 99, cameraInMap: Point3(4,0,0))
        XCTAssertThrowsError(try NavigationTestRecording.restored(id: UUID(), startedAt: 0, events: [.sample(invented)]))
        XCTAssertThrowsError(try NavigationTestRecording.restored(id: UUID(), startedAt: 0,
            events: [.ended(status: .recording, at: 0.2)]))
        XCTAssertThrowsError(try NavigationTestRecording.restored(id: UUID(), startedAt: 0,
            events: [.ended(status: .capacityReached, at: 0.2)]))
        XCTAssertThrowsError(try NavigationTestRecording.restored(id: UUID(), startedAt: 0,
            events: [.ended(status: .stopped, at: 0.2), .plan(plan(at: 0.3))]))
        XCTAssertThrowsError(try NavigationTestArchiveEvent(payload: Data(repeating: 0, count: NavigationTestArchiveEvent.maximumBytes + 1)))
    }
    func testReadOnlyConnectedRouteSnapshotUsesActualOwnerWithoutRetiringTicket() throws {
        typealias F = ConnectedFixture
        var owner = try F.prepared()
        try owner.setDestination(F.endpoint(F.a, "p"), origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        try owner.plan(from: F.endpoint(F.a, "s"), now: 1)
        let ticket = try owner.next(now: 1)
        let diagnostic = try XCTUnwrap(owner.diagnosticOwnedRoute)
        XCTAssertEqual(diagnostic.map, F.a)
        XCTAssertEqual(diagnostic.routeRevision, ticket.route.routeID)
        XCTAssertEqual(diagnostic.goalRevision, ticket.route.goalRevision)
        XCTAssertEqual(diagnostic.bodyRevision, ticket.route.bodyRevision)
        XCTAssertEqual(diagnostic.obstacleRevision, ticket.route.obstacleRevision)
        XCTAssertEqual(diagnostic.artifactSHA256, ticket.route.artifactSHA256)
        XCTAssertEqual(diagnostic.points, [Point3(1,0,3), Point3(2,0,3), Point3(3,0,3)])
        XCTAssertTrue(owner.permits(ticket, now: 1))
        try owner.cancel(origin: .trustedInterface, recordedAt: F.date, persist: { _ in })
        XCTAssertNil(owner.diagnosticOwnedRoute)
    }
    func testExplicitRecordingStopAndLateCallback() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan()); try recording.observe(sample(0.2), receivedAt: 0.3)
        try recording.mark(.apparentFurnitureCrossing, at: 0.4); try recording.stop(at: 0.5)
        XCTAssertThrowsError(try recording.observe(sample(0.6), receivedAt: 0.6))
        XCTAssertEqual(recording.entries.count, 1); XCTAssertEqual(recording.status, .stopped)
        XCTAssertEqual(recording.markers.first?.lastObservationID, recording.entries.first?.sample.observationID)
        XCTAssertFalse(recording.permitsPhysicalGuidance)
        XCTAssertEqual(recording.entries.first?.receivedAt, 0.3)
    }
    func testNoAlignmentNeverSnapsCameraToPlannedRoute() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan(aligned: false)); try recording.observe(sample(0.2), receivedAt: 0.2)
        XCTAssertNil(recording.entries[0].cameraInMap); XCTAssertTrue(recording.overlaySegments.isEmpty)
        XCTAssertEqual(recording.entries[0].sample.cameraPosition, Point3(0,0,0))
        XCTAssertEqual(recording.plans[0].points.count, 2)
    }
    func testExpiredAndLimitedAndDelayedSamplesStayUnregistered() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan(at: 1, expiry: 2))
        try recording.observe(sample(0.5), receivedAt: 1.1)
        try recording.observe(sample(1.2, tracking: .limited), receivedAt: 1.2)
        try recording.observe(sample(2.1), receivedAt: 2.1)
        XCTAssertTrue(recording.entries.allSatisfy { $0.cameraInMap == nil })
        XCTAssertEqual(recording.entries[1].sample.tracking, .limited)
        XCTAssertNil(recording.entries[0].planIndex)
    }
    func testRevisionAndTrackingBoundariesRemainVisible() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan()); try recording.observe(sample(0.2), receivedAt: 0.2)
        try recording.setPlan(plan(at: 0.3)); try recording.observe(sample(0.4), receivedAt: 0.4)
        XCTAssertEqual(recording.plans.count, 2); XCTAssertEqual(recording.overlaySegments.count, 2)
        XCTAssertNotEqual(recording.entries[0].planIndex, recording.entries[1].planIndex)
    }
    func testContinuousSamplesFormLineButUnknownAndTrackingLossBreakIt() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan())
        try recording.observe(sample(0.2), receivedAt: 0.2)
        try recording.observe(sample(0.4), receivedAt: 0.4)
        XCTAssertNil(recording.entries[1].sample.boundaryBefore)
        XCTAssertEqual(recording.overlaySegments.map { $0.points.count }, [2])
        try recording.setPlan(plan(at: 0.5, aligned: false))
        try recording.observe(sample(0.6), receivedAt: 0.6)
        try recording.setPlan(plan(at: 0.7))
        try recording.observe(sample(0.8), receivedAt: 0.8)
        try recording.observe(sample(1.0, tracking: .limited), receivedAt: 1.0)
        try recording.observe(sample(1.2), receivedAt: 1.2)
        XCTAssertEqual(recording.overlaySegments.map { $0.points.count }, [2, 1, 1])
        XCTAssertTrue(recording.overlaySegments.allSatisfy { $0.map == map })
    }
    func testEventCapacityStopsInsteadOfSilentlyDroppingEvidence() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        for i in 0..<NavigationTestRecording.maximumEvents { try recording.mark(.other, at: Double(i)) }
        XCTAssertThrowsError(try recording.mark(.other, at: 200))
        XCTAssertEqual(recording.status, .capacityReached); XCTAssertEqual(recording.markers.count, 128)
        XCTAssertThrowsError(try recording.setPlan(plan(at: 201)))
    }
    func testCancellationRetainsOldRouteButDoesNotAssociateNewSamples() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 0)
        try recording.setPlan(plan()); try recording.observe(sample(0.2), receivedAt: 0.2)
        try recording.setPlan(.init(revision: UUID(), goalRevision: UUID(), map: map,
                                    points: [], alignment: nil, recordedAt: 0.3))
        try recording.observe(sample(0.4), receivedAt: 0.4)
        XCTAssertEqual(recording.plans[0].points.count, 2)
        XCTAssertTrue(recording.plans[1].points.isEmpty)
        XCTAssertNil(recording.entries[1].cameraInMap)
    }
    func testInvalidPlanAndNonmonotonicReceiptRejected() throws {
        var recording = try NavigationTestRecording(explicitStartAt: 1)
        XCTAssertThrowsError(try recording.setPlan(plan(at: 0)))
        try recording.setPlan(plan(at: 1))
        let beforeOptIn = try sample(0.9), future = try sample(2)
        XCTAssertThrowsError(try recording.observe(future, receivedAt: 1.5)) {
            XCTAssertEqual($0 as? NavigationTestRecording.Failure, .invalidInput)
        }
        XCTAssertThrowsError(try recording.observe(beforeOptIn, receivedAt: 1.5)) {
            XCTAssertEqual($0 as? NavigationTestRecording.Failure, .invalidInput)
        }
        XCTAssertTrue(recording.entries.isEmpty)
        XCTAssertThrowsError(try recording.stop(at: .nan))
    }
}
