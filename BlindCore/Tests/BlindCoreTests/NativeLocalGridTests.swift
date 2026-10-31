import XCTest
@testable import BlindCore

final class NativeLocalGridTests: XCTestCase {
    private func translated(_ x: Double = 0, _ y: Double = 0, _ z: Double = 0) -> NativeCameraTransform {
        var c = NativeCameraTransform.identity.columns; c[12] = x; c[13] = y; c[14] = z
        return NativeCameraTransform(columns: c)
    }
    private func cells(_ points: [Point3] = [Point3(0.2, 0.3, -0.7)], original: Int? = nil,
                       available: Bool = true, truncated: Bool = false) -> NativeLocalGridCells {
        .init(points: points, originalCount: original ?? points.count, available: available, truncated: truncated)
    }
    private func packet(status: NativeLocalGridPacket.Status = .available, generation: UInt64 = 1,
                        frame: UInt64 = 1, event: UInt64 = 1, sequence: UInt64 = 1, time: Double = 1,
                        stamp: Double? = nil, node: Int = 1, map: Int = 0, cellSize: Double = 0.1,
                        poses: [NativeLocalGridNodePose]? = nil, ground: NativeLocalGridCells? = nil,
                        obstacles: NativeLocalGridCells = .unavailable, empty: NativeLocalGridCells = .unavailable,
                        graphTruncated: Bool = false, correction: NativeCameraTransform = .identity,
                        ar: NativeCameraTransform = .identity, optical: NativeCameraTransform? = .identity) -> NativeLocalGridPacket {
        .init(status: status, generation: generation, frameRevision: frame, eventRevision: event,
              captureSequence: sequence, capturedAt: time, upstreamStamp: stamp ?? 1_000 + time,
              nodeID: node, mapID: map, cellSize: cellSize, mapCorrection: correction, cameraToARWorld: ar,
              mapFromCameraOptical: optical, poses: poses ?? [.init(id: node, transform: .identity)],
              ground: ground ?? cells(), obstacles: obstacles, empty: empty, graphTruncated: graphTruncated)
    }
    func testConsumesOriginalThreeDimensionalGridWithoutCreatingHeightOrAuthority() throws {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        let pose = translated(2, 3, 4)
        let state = consumer.consume(packet(poses: [.init(id: 1, transform: pose)],
            ground: cells([Point3(0.2, 0.3, -0.7)]), obstacles: cells([Point3(0, 0, 1.25)])), now: 1.1)
        XCTAssertEqual(state.status, .available)
        XCTAssertEqual(state.tileCount, 1); XCTAssertEqual(state.cellCount, 2)
        XCTAssertEqual(state.groundCellCount, 1); XCTAssertEqual(state.obstacleCellCount, 1)
        XCTAssertEqual(state.emptyCellCount, 0)
        XCTAssertFalse(state.tiles[0].empty.available)
        XCTAssertEqual(state.tiles[0].ground.points[0].z, -0.7)
        let corrected = try state.tiles[0].mapFromNode.applying(to: state.tiles[0].ground.points[0])
        XCTAssertEqual(corrected.x, 2.2, accuracy: 0.0001)
        XCTAssertEqual(corrected.z, 3.3, accuracy: 0.0001)
        XCTAssertEqual(state.currentOpticalPose, .identity)
        XCTAssertFalse(state.authorizesPhysicalGuidance)
    }
    func testWrongGenerationAndSupersededEventsCannotMutateNewOwner() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 2)
        let fresh = consumer.consume(packet(generation: 2, frame: 3, event: 5), now: 1.1)
        XCTAssertEqual(consumer.consume(packet(status: .invalid, generation: 1, frame: 9, event: 99), now: .nan), fresh)
        XCTAssertEqual(consumer.consume(packet(generation: 2, frame: 2, event: 6), now: 100), fresh)
        XCTAssertEqual(consumer.consume(packet(generation: 2, frame: 3, event: 5), now: 100), fresh)
        consumer.invalidate()
        XCTAssertNil(consumer.consume(packet(generation: 2, frame: 4, event: 6), now: 1.2).generation)
        XCTAssertEqual(consumer.snapshot().tileCount, 0)
    }
    func testCurrentGraphPosesCorrectRetainedTilesWithoutChangingOriginalCaptureAge() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        consumer.consume(packet(), now: 1)
        let correction = translated(4)
        let state = consumer.consume(packet(event: 2, sequence: 2, time: 1.2, node: 2,
            poses: [.init(id: 1, transform: correction), .init(id: 2, transform: .identity)]), now: 1.2)
        XCTAssertEqual(state.tileCount, 2)
        XCTAssertEqual(state.tiles[0].mapFromNode, correction)
        XCTAssertEqual(state.tiles[0].capturedAt, 1)
        XCTAssertEqual(state.tiles[0].captureSequence, 1)
    }
    func testNewFrameResetsEventAndCaptureCountersButDelayedOldFrameCannotReturn() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        consumer.consume(packet(event: 9, sequence: 9, time: 1.5), now: 1.5)
        let fresh = consumer.consume(packet(frame: 2, event: 1, sequence: 1, time: 2, node: 2), now: 2)
        XCTAssertEqual(fresh.status, .available); XCTAssertEqual(fresh.eventRevision, 1)
        XCTAssertEqual(fresh.tiles.map(\.nodeID), [2]); XCTAssertEqual(fresh.tiles[0].captureSequence, 1)
        XCTAssertEqual(consumer.consume(packet(frame: 1, event: 99, sequence: 99, time: 3), now: 3), fresh)
        XCTAssertEqual(consumer.consume(packet(frame: 2, event: 1, sequence: 2, time: 3), now: 3), fresh)
    }
    func testZeroGenerationCannotBecomeOwnerAndMapChangeResetsCaptureBinding() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 0)
        let absent = consumer.consume(packet(generation: 0), now: 1)
        XCTAssertEqual(absent.status, .unavailable); XCTAssertNil(absent.generation)
        XCTAssertEqual(absent.tileCount, 0)
        consumer.begin(generation: 1)
        consumer.consume(packet(event: 2, sequence: 8), now: 1)
        let newMap = consumer.consume(packet(event: 3, sequence: 1, time: 1.2, map: 1), now: 1.2)
        XCTAssertEqual(newMap.status, .available); XCTAssertEqual(newMap.tiles[0].mapID, 1)
    }
    func testFrameRevisionAndMapChangeRetireEarlierCoordinates() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        consumer.consume(packet(), now: 1)
        let poses: [NativeLocalGridNodePose] = [.init(id: 1, transform: .identity), .init(id: 2, transform: .identity)]
        let corrected = consumer.consume(packet(frame: 2, event: 2, sequence: 2, time: 1.1, node: 2, poses: poses), now: 1.1)
        XCTAssertEqual(corrected.tiles.map(\.nodeID), [2])
        let newMap = consumer.consume(packet(frame: 2, event: 3, sequence: 3, time: 1.2, map: 1, poses: poses), now: 1.2)
        XCTAssertEqual(newMap.tiles.map(\.nodeID), [1]); XCTAssertEqual(newMap.tiles[0].mapID, 1)
    }
    func testMissingPoseIsEvictedEvenWhenPoseGraphWasTruncated() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        consumer.consume(packet(), now: 1)
        let state = consumer.consume(packet(event: 2, sequence: 2, time: 1.2, node: 2, graphTruncated: true), now: 1.2)
        XCTAssertEqual(state.tiles.map(\.nodeID), [2]); XCTAssertEqual(state.status, .truncated)
    }
    func testTruncationAndUnknownLayersStayExplicitNotConvertedToSupport() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        let state = consumer.consume(packet(ground: .unavailable,
            obstacles: cells([Point3(0, 0, 1.2)], original: 9000, truncated: true),
            empty: cells([Point3(0, 1, 0.4)])), now: 1.1)
        XCTAssertEqual(state.status, .truncated); XCTAssertEqual(state.groundCellCount, 0)
        XCTAssertEqual(state.emptyCellCount, 1); XCTAssertEqual(state.tiles[0].empty.points[0].z, 0.4)
        XCTAssertFalse(state.tiles[0].ground.available)
        XCTAssertEqual(state.tiles[0].obstacles.originalCount, 9000)
        XCTAssertTrue(state.tiles[0].obstacles.truncated)
        let missing = consumer.consume(packet(event: 2, sequence: 2, time: 1.2, ground: .unavailable), now: 1.2)
        XCTAssertEqual(missing.status, .unavailable); XCTAssertEqual(missing.tileCount, 0)
    }
    func testMalformedMatricesCountsAndOversizedInputsAreRejected() {
        let malformed = NativeCameraTransform(columns: [1, 2, 3])
        var reflected = NativeCameraTransform.identity.columns; reflected[0] = -1
        let bad: [NativeLocalGridPacket] = [
            packet(correction: malformed), packet(ar: malformed), packet(optical: malformed),
            packet(poses: [.init(id: 1, transform: NativeCameraTransform(columns: reflected))]),
            packet(poses: [.init(id: 1, transform: .identity), .init(id: 1, transform: .identity)]),
            packet(poses: (1...65).map { .init(id: $0, transform: .identity) }),
            packet(ground: cells(original: 0)), packet(ground: cells(original: 2)),
            packet(ground: cells(truncated: true)),
            packet(ground: cells([], original: 1, available: false)),
            packet(ground: cells([], available: false, truncated: true)),
            packet(ground: cells(available: false)), packet(ground: cells([Point3(.nan, 0, 0)])),
            packet(ground: cells(Array(repeating: Point3(0, 0, 0), count: 4097))),
            packet(cellSize: .infinity), packet(cellSize: 0), packet(cellSize: 0.009), packet(cellSize: 1.001)
        ]
        for value in bad {
            var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
            XCTAssertEqual(consumer.consume(value, now: 1.1).status, .invalid)
            XCTAssertNil(consumer.snapshot().currentOpticalPose)
            XCTAssertEqual(consumer.snapshot().tileCount, 0)
        }
    }
    func testFreshPoseExpiresWithoutNewCallbackAndHistoryHasSeparateDeadline() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        consumer.consume(packet(), now: 1.1)
        let expired = consumer.snapshot(now: 1.51)
        XCTAssertEqual(expired.status, .expired); XCTAssertNil(expired.currentOpticalPose)
        XCTAssertNil(expired.cameraToARWorld); XCTAssertEqual(expired.tileCount, 1)
        XCTAssertEqual(consumer.snapshot(now: 31).tileCount, 1)
        XCTAssertEqual(consumer.snapshot(now: 31.001).tileCount, 0)
    }
    func testDelayedGridIsUsefulHistoryButNotCurrentPoseAndFutureStampCannotPoisonRecovery() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        let delayed = consumer.consume(packet(), now: 2)
        XCTAssertEqual(delayed.status, .expired); XCTAssertEqual(delayed.tileCount, 1)
        XCTAssertNil(delayed.currentOpticalPose)
        XCTAssertEqual(consumer.consume(packet(event: 2, sequence: 99, time: .infinity), now: 2).status, .invalid)
        let recovered = consumer.consume(packet(event: 3, sequence: 2, time: 2.1), now: 2.1)
        XCTAssertEqual(recovered.status, .available); XCTAssertNotNil(recovered.currentOpticalPose)
        XCTAssertEqual(consumer.snapshot(now: .nan).status, .invalid)
        XCTAssertNil(consumer.snapshot().currentOpticalPose)
    }
    func testCaptureAssociationCannotBeReassignedOrReplayedAsNewerCameraPose() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        consumer.consume(packet(sequence: 2), now: 1)
        let replay = consumer.consume(packet(event: 2, sequence: 1, time: 1.1), now: 1.1)
        XCTAssertEqual(replay.status, .unassociated); XCTAssertNil(replay.currentOpticalPose)
        let alias = consumer.consume(packet(event: 3, sequence: 2, time: 1.2, node: 2), now: 1.2)
        XCTAssertEqual(alias.status, .unassociated); XCTAssertEqual(alias.tileCount, 0)
        let recovered = consumer.consume(packet(event: 4, sequence: 3, time: 1.3), now: 1.3)
        XCTAssertEqual(recovered.status, .available)
    }
    func testUnavailableAndUnassociatedEventsRetireLivePoseAndCannotCreateTiles() {
        for value in [NativeLocalGridPacket.Status.unavailable, .invalid, .unassociated] {
            var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
            consumer.consume(packet(), now: 1)
            let state = consumer.consume(packet(status: value, event: 2, sequence: 2, time: 1.1, node: 2), now: 1.1)
            XCTAssertEqual(state.status.rawValue, value.rawValue)
            XCTAssertNil(state.currentOpticalPose); XCTAssertEqual(state.tileCount, 0)
        }
    }
    func testRepeatedCaptureKeepsOriginalARBindingWhileGraphPoseMayCorrect() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        consumer.consume(packet(), now: 1)
        let corrected = consumer.consume(packet(event: 2, optical: translated(3)), now: 1.1)
        XCTAssertEqual(corrected.status, .available)
        XCTAssertEqual(corrected.currentOpticalPose, translated(3))
        XCTAssertEqual(corrected.capturedAt, 1)
        let relabelled = consumer.consume(packet(event: 3, ar: translated(9)), now: 1.2)
        XCTAssertEqual(relabelled.status, .unassociated); XCTAssertNil(relabelled.currentOpticalPose)
        XCTAssertEqual(consumer.consume(packet(event: 4, sequence: 2), now: 1.2).status, .unassociated)
    }
    func testTileAndPointCapsEvictDeterministicallyWithoutPartialInventedLayers() {
        var consumer = NativeLocalGridConsumer(); consumer.begin(generation: 1)
        for node in 1...40 {
            let time = 1 + Double(node) / 10
            consumer.consume(packet(event: UInt64(node), sequence: UInt64(node), time: time, node: node,
                poses: (1...node).map { .init(id: $0, transform: .identity) }), now: time)
        }
        XCTAssertEqual(consumer.snapshot().tileCount, 32)
        XCTAssertEqual(consumer.snapshot().tiles.first?.nodeID, 9)
        XCTAssertEqual(consumer.snapshot().evictedTileCount, 8)
        XCTAssertEqual(consumer.snapshot().status, .truncated)
        consumer.begin(generation: 1)
        let large = cells(Array(repeating: Point3(0, 0, 0), count: 4096))
        consumer.consume(packet(ground: large, obstacles: large, empty: large), now: 1)
        let state = consumer.consume(packet(event: 2, sequence: 2, time: 1.1, node: 2,
            poses: [.init(id: 1, transform: .identity), .init(id: 2, transform: .identity)],
            ground: large, obstacles: large, empty: large), now: 1.1)
        XCTAssertEqual(state.tiles.map(\.nodeID), [2]); XCTAssertEqual(state.cellCount, 12_288)
        XCTAssertLessThanOrEqual(state.cellCount, NativeLocalGridConsumer.maximumCells)
        XCTAssertEqual(state.status, .truncated)
    }

    func testNavigationEvidenceSelectsOnlyLatestExactCaptureNotHistoricalObstacles() throws {
        var c = NativeLocalGridConsumer(); c.begin(generation: 1)
        c.consume(packet(obstacles: cells([Point3(1, 2, 3)])), now: 1)
        let snapshot = c.consume(packet(event: 2, sequence: 4, time: 1.2, node: 2,
            poses: [.init(id: 1, transform: .identity), .init(id: 2, transform: .identity)],
            ground: cells([Point3(4, 5, 6)]), obstacles: cells([]), empty: cells([])), now: 1.2)
        guard case .current(let evidence) = snapshot.navigationEvidence(now: 1.3) else { return XCTFail("current capture missing") }
        XCTAssertEqual(evidence.revision.captureSequence, 4) // skipped captures are not fabricated
        XCTAssertEqual(evidence.historicalTileCount, 1)
        XCTAssertEqual(evidence.tile.ground.points, [Point3(4, 5, 6)])
        XCTAssertEqual(evidence.tile.obstacles.points, [])
        XCTAssertFalse(evidence.absenceEstablishesFreeSpace)
        XCTAssertFalse(evidence.fullFootprintSupportKnown)
        XCTAssertFalse(evidence.originalARCaptureIdentityAvailable)
        XCTAssertFalse(evidence.registeredMetricFrameAvailable)
        XCTAssertFalse(evidence.authorizesPhysicalGuidance)
    }
    func testNavigationEvidenceRechecksCachedSnapshotAgeAndFutureClock() {
        var c = NativeLocalGridConsumer(); c.begin(generation: 1)
        let snapshot = c.consume(packet(), now: 1)
        XCTAssertEqual(snapshot.navigationEvidence(now: 1.501), .unavailable(.staleCapture))
        XCTAssertEqual(snapshot.navigationEvidence(now: 0.9), .unavailable(.staleCapture))
        XCTAssertEqual(snapshot.navigationEvidence(now: .nan), .unavailable(.invalidClock))
        guard case .current = snapshot.navigationEvidence(now: 1.5) else { return XCTFail("boundary unexpectedly refused") }
    }
    func testNavigationEvidenceRetiresAfterMovedObjectReplacementAndRevisionChange() {
        var c = NativeLocalGridConsumer(); c.begin(generation: 1)
        let first = c.consume(packet(obstacles: cells([Point3(1, 0, 1)])), now: 1)
        guard case .current(let old) = first.navigationEvidence(now: 1) else { return XCTFail("missing first") }
        let next = c.consume(packet(event: 2, sequence: 2, time: 1.1,
            obstacles: cells([Point3(2, 0, 2)])), now: 1.1)
        XCTAssertFalse(next.isCurrent(old, now: 1.1))
        guard case .current(let fresh) = next.navigationEvidence(now: 1.1) else { return XCTFail("missing replacement") }
        XCTAssertEqual(fresh.tile.obstacles.points, [Point3(2, 0, 2)])
        let delayed = c.consume(packet(event: 1, sequence: 1, time: 1), now: 1.2)
        XCTAssertTrue(delayed.isCurrent(fresh, now: 1.2))
        XCTAssertFalse(delayed.isCurrent(fresh, now: 1.7))
        c.invalidate()
        XCTAssertFalse(c.snapshot().isCurrent(fresh, now: 1.2))
    }
    func testNavigationEvidenceDoesNotFallbackWhenLatestLayersMissingOrTruncated() {
        var c = NativeLocalGridConsumer(); c.begin(generation: 1)
        c.consume(packet(), now: 1)
        let unknown = c.consume(packet(event: 2, sequence: 2, time: 1.1,
            ground: .unavailable), now: 1.1)
        guard case .unavailable = unknown.navigationEvidence(now: 1.1) else { return XCTFail("unknown became evidence") }
        let partial = c.consume(packet(event: 3, sequence: 3, time: 1.2,
            ground: cells([Point3(0, 0, 0)], original: 2, truncated: true)), now: 1.2)
        XCTAssertEqual(partial.navigationEvidence(now: 1.2), .unavailable(.truncated))
    }
    func testNavigationEvidenceGraphUpdateRetiresEvenSameCaptureAndClock() {
        var c = NativeLocalGridConsumer(); c.begin(generation: 1)
        let first = c.consume(packet(), now: 1)
        guard case .current(let old) = first.navigationEvidence(now: 1) else { return XCTFail("missing first") }
        let revised = c.consume(packet(event: 2, poses: [.init(id: 1, transform: translated(1))]), now: 1.1)
        XCTAssertFalse(revised.isCurrent(old, now: 1.1))
        guard case .current(let fresh) = revised.navigationEvidence(now: 1.1) else { return XCTFail("missing revised") }
        XCTAssertEqual(fresh.revision.captureSequence, old.revision.captureSequence)
        XCTAssertNotEqual(fresh.revision.event, old.revision.event)
        XCTAssertEqual(fresh.capturedAt, old.capturedAt)
    }
}
