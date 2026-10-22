import XCTest
@testable import BlindCore

/// Synthetic gate tests, not evidence of model accuracy or suitability for child use.
final class FamiliarFacePolicyTests: XCTestCase {
    private func axis(_ index: Int = 0, scale: Float = 1) -> [Float] {
        var feature = [Float](repeating: 0, count: 128)
        feature[index] = scale
        return feature
    }

    func testNormalizedMeanSingleReturnsUnit() {
        XCTAssertEqual(FamiliarFacePolicy.normalizedMean([axis(scale: 8)]), axis())
        XCTAssertEqual(FamiliarFacePolicy.normalizedMean([axis(scale: .leastNonzeroMagnitude)]), axis())
        XCTAssertEqual(FamiliarFacePolicy.normalizedMean([axis(scale: .greatestFiniteMagnitude)]), axis())
    }

    func testNormalizedMeanIgnoresIndividualMagnitudes() throws {
        let plain = try XCTUnwrap(FamiliarFacePolicy.normalizedMean([axis(), axis(1)]))
        let scaled = try XCTUnwrap(FamiliarFacePolicy.normalizedMean([axis(scale: 1000), axis(1, scale: 0.01)]))
        for index in plain.indices { XCTAssertEqual(plain[index], scaled[index], accuracy: 1e-6) }
    }

    func testNormalizedMeanOfThreeExamples() throws {
        let result = try XCTUnwrap(FamiliarFacePolicy.normalizedMean([axis(), axis(1), axis(2)]))
        XCTAssertEqual(result.count, 128)
        for index in 0..<3 { XCTAssertEqual(result[index], Float(1 / sqrt(3.0)), accuracy: 1e-6) }
        XCTAssertTrue(result.dropFirst(3).allSatisfy { $0 == 0 })
        XCTAssertEqual(result.reduce(0.0) { $0 + Double($1) * Double($1) }, 1, accuracy: 1e-6)
    }

    func testNormalizedMeanRejectsCancellationAndNearCancellation() {
        XCTAssertNil(FamiliarFacePolicy.normalizedMean([axis(), axis(scale: -1)]))
        var nearlyOpposite = axis(scale: -1)
        nearlyOpposite[1] = 1e-7
        XCTAssertNil(FamiliarFacePolicy.normalizedMean([axis(), nearlyOpposite]))
        nearlyOpposite[1] = 1e-4
        XCTAssertNotNil(FamiliarFacePolicy.normalizedMean([axis(), nearlyOpposite]))
    }

    func testNormalizedMeanRequiresOneThroughSixValidExamples() {
        XCTAssertNil(FamiliarFacePolicy.normalizedMean([]))
        XCTAssertEqual(FamiliarFacePolicy.normalizedMean(Array(repeating: axis(), count: 6)), axis())
        XCTAssertNil(FamiliarFacePolicy.normalizedMean(Array(repeating: axis(), count: 7)))
        for invalid in [[], [Float](repeating: 1, count: 127), [Float](repeating: 1, count: 129),
                        [Float](repeating: 0, count: 128), axis(scale: .nan), axis(scale: .infinity)] {
            XCTAssertNil(FamiliarFacePolicy.normalizedMean([axis(), invalid]))
        }
    }

    func testMeanVisionDistanceUsesAllExamples() throws {
        XCTAssertEqual(FamiliarFacePolicy.meanVisionDistance([0]), 0)
        XCTAssertEqual(try XCTUnwrap(FamiliarFacePolicy.meanVisionDistance([0.1, 0.2, 0.3])), 0.2, accuracy: 1e-12)
        XCTAssertEqual(FamiliarFacePolicy.meanVisionDistance([0, 0, 0, 0, 0, 6]), 1)
        XCTAssertEqual(FamiliarFacePolicy.meanVisionDistance([Double.greatestFiniteMagnitude,
                                                            Double.greatestFiniteMagnitude]), Double.greatestFiniteMagnitude)
        XCTAssertEqual(FamiliarFacePolicy.meanVisionDistance(Array(repeating: Double.greatestFiniteMagnitude, count: 6)),
                       Double.greatestFiniteMagnitude)
    }

    func testMeanVisionDistanceRejectsMalformedOrOutOfBoundExamples() {
        XCTAssertNil(FamiliarFacePolicy.meanVisionDistance([]))
        XCTAssertNil(FamiliarFacePolicy.meanVisionDistance(Array(repeating: 0, count: 7)))
        for invalid in [Double.nan, .infinity, -.infinity, -0.001] {
            XCTAssertNil(FamiliarFacePolicy.meanVisionDistance([invalid]))
            XCTAssertNil(FamiliarFacePolicy.meanVisionDistance([0, invalid, 0]))
        }
    }

    func testKnownCandidateAndNormalizedReference() {
        let known = UUID(), other = UUID()
        XCTAssertEqual(FamiliarFacePolicy.candidate(probe: axis(scale: 7), gallery: [
            (other, axis(1)), (known, axis(scale: 3))]), known)
        XCTAssertEqual(FamiliarFacePolicy.candidate(scores: [(other, 0), (known, 1)]), known)
    }

    func testUnknownBelowThreshold() {
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(UUID(), 0.362999)]))
        XCTAssertNil(FamiliarFacePolicy.candidate(probe: axis(), gallery: [(UUID(), axis(1))]))
    }

    func testSingleTemplateAndInclusiveThreshold() {
        let id = UUID()
        XCTAssertEqual(FamiliarFacePolicy.candidate(scores: [(id, 0.363)]), id)
        XCTAssertEqual(FamiliarFacePolicy.candidate(probe: axis(), gallery: [(id, axis())]), id)
    }

    func testLookalikeMarginAndInclusiveBoundary() {
        let best = UUID()
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(best, 0.8), (UUID(), 0.71)]))
        XCTAssertEqual(FamiliarFacePolicy.candidate(scores: [(best, 0.8), (UUID(), 0.7)]), best)
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(best, 0.8), (UUID(), 0.700001)]))
        var similar = axis()
        similar[1] = 0.1
        XCTAssertNil(FamiliarFacePolicy.candidate(probe: axis(), gallery: [(best, axis()), (UUID(), similar)]))
    }

    func testTiesRejectIndependentOfOrder() {
        let a = UUID(), b = UUID()
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(a, 1), (b, 1)]))
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(b, 1), (a, 1)]))
        XCTAssertNil(FamiliarFacePolicy.candidate(probe: axis(), gallery: [(a, axis()), (b, axis())]))
    }

    func testInvalidFeatureShapesAndValues() {
        for invalid in [[], [Float](repeating: 1, count: 127), [Float](repeating: 1, count: 129),
                        [Float](repeating: 0, count: 128), axis(scale: .nan), axis(scale: .infinity),
                        axis(scale: -.infinity)] {
            XCTAssertFalse(FamiliarFacePolicy.validFeature(invalid))
            XCTAssertNil(FamiliarFacePolicy.candidate(probe: invalid, gallery: [(UUID(), axis())]))
            XCTAssertNil(FamiliarFacePolicy.candidate(probe: axis(), gallery: [(UUID(), axis()), (UUID(), invalid)]))
        }
    }

    func testExtremeFiniteFeaturesRemainValid() {
        let id = UUID()
        for scale in [Float.greatestFiniteMagnitude, Float.leastNonzeroMagnitude] {
            XCTAssertTrue(FamiliarFacePolicy.validFeature(axis(scale: scale)))
            XCTAssertEqual(FamiliarFacePolicy.candidate(probe: axis(scale: scale), gallery: [(id, axis(scale: scale))]), id)
        }
    }

    func testEmptyGalleryRejects() {
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: []))
        XCTAssertNil(FamiliarFacePolicy.candidate(probe: axis(), gallery: []))
    }

    func testGalleryMaximum() {
        let best = UUID()
        var scores: [(id: UUID, cosine: Double)] = [(best, 1)]
        var gallery: [(id: UUID, feature: [Float])] = [(best, axis())]
        for _ in 1..<20 {
            scores.append((UUID(), 0))
            gallery.append((UUID(), axis(1)))
        }
        XCTAssertEqual(FamiliarFacePolicy.candidate(scores: scores), best)
        XCTAssertEqual(FamiliarFacePolicy.candidate(probe: axis(), gallery: gallery), best)
        scores.append((UUID(), 0))
        gallery.append((UUID(), axis(1)))
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: scores))
        XCTAssertNil(FamiliarFacePolicy.candidate(probe: axis(), gallery: gallery))
    }

    func testDuplicateIDsRejectEvenWithDistinctScores() {
        let id = UUID()
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(id, 1), (id, 0)]))
        XCTAssertNil(FamiliarFacePolicy.candidate(probe: axis(), gallery: [(id, axis()), (id, axis(1))]))
    }

    func testMalformedScoreRejectsEntireBatch() {
        for invalid in [Double.nan, .infinity, -.infinity, 1.000001, -1.000001] {
            XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(UUID(), 1), (UUID(), invalid)]))
        }
        let id = UUID()
        XCTAssertEqual(FamiliarFacePolicy.candidate(scores: [(id, 1), (UUID(), -1)]), id)
    }

    func testVisionCannotPromoteUnknownSFaceEvenWithExactMatch() {
        let id = UUID()
        XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
            sface: nil, visionDistances: [(id, 0)], expectedIDs: [id]))
    }

    func testVisionDisagreementVetoesRatherThanReplacesSFace() {
        let original = UUID(), alternate = UUID()
        XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
            sface: original, visionDistances: [(original, 0.5), (alternate, 0)],
            expectedIDs: [original, alternate]))
    }

    func testAmbiguousVisionAndTiesVeto() {
        let original = UUID(), alternate = UUID()
        for runnerUp in [0.1, 0.199999] {
            XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
                sface: original, visionDistances: [(original, 0.1), (alternate, runnerUp)],
                expectedIDs: [original, alternate]))
        }
    }

    func testCompleteVisionAgreementRetainsOnlyOriginalCandidate() {
        let original = UUID(), alternate = UUID()
        XCTAssertEqual(FamiliarFacePolicy.corroboratedCandidate(
            sface: original, visionDistances: [(alternate, 0.8), (original, 0.1)],
            expectedIDs: [original, alternate]), original)
    }

    func testVisionInclusiveDistanceAndMarginBoundaries() {
        let original = UUID(), alternate = UUID()
        XCTAssertEqual(FamiliarFacePolicy.corroboratedCandidate(
            sface: original, visionDistances: [(original, 0.3), (alternate, 0.4)],
            expectedIDs: [original, alternate]), original)
        XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
            sface: original, visionDistances: [(original, 0.300001), (alternate, 0.5)],
            expectedIDs: [original, alternate]))
        XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
            sface: original, visionDistances: [(original, 0.3), (alternate, 0.399999)],
            expectedIDs: [original, alternate]))
    }

    func testSingleVisionTemplateHasNoRunnerUpCheck() {
        let id = UUID()
        XCTAssertEqual(FamiliarFacePolicy.corroboratedCandidate(
            sface: id, visionDistances: [(id, 0.3)], expectedIDs: [id]), id)
    }

    func testVisionMissingExtraDuplicateOrWrongGalleryRejects() {
        let a = UUID(), b = UUID(), unexpected = UUID()
        let invalidGalleries: [[(id: UUID, distance: Double)]] = [
            [], [(a, 0)], [(a, 0), (b, 0.5), (unexpected, 1)],
            [(a, 0), (a, 0.5)], [(a, 0), (unexpected, 0.5)]
        ]
        for gallery in invalidGalleries {
            XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
                sface: a, visionDistances: gallery, expectedIDs: [a, b]))
        }
        XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
            sface: unexpected, visionDistances: [(a, 0), (b, 0.5)], expectedIDs: [a, b]))
        XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
            sface: a, visionDistances: [], expectedIDs: []))
    }

    func testVisionCorruptDistanceRejectsEntireGallery() {
        let a = UUID(), b = UUID()
        for invalid in [Double.nan, .infinity, -.infinity, -0.000001] {
            XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
                sface: a, visionDistances: [(a, 0), (b, invalid)], expectedIDs: [a, b]))
            XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
                sface: a, visionDistances: [(a, invalid), (b, 0.5)], expectedIDs: [a, b]))
        }
    }

    func testVisionGalleryMaximum() {
        let original = UUID()
        var gallery: [(id: UUID, distance: Double)] = [(original, 0)]
        for _ in 1..<20 { gallery.append((UUID(), 0.5)) }
        XCTAssertEqual(FamiliarFacePolicy.corroboratedCandidate(
            sface: original, visionDistances: gallery, expectedIDs: Set(gallery.map { $0.id })), original)
        gallery.append((UUID(), 0.5))
        XCTAssertNil(FamiliarFacePolicy.corroboratedCandidate(
            sface: original, visionDistances: gallery, expectedIDs: Set(gallery.map { $0.id })))
    }

    func testAgreeingWrongPipelinesCanStillReturnMisleadingID() {
        // Synthetic counterexample: the policy sees no ground truth. Agreement is not proof.
        let misleadingID = UUID(), actualID = UUID()
        let result = FamiliarFacePolicy.corroboratedCandidate(
            sface: misleadingID, visionDistances: [(misleadingID, 0), (actualID, 0.5)],
            expectedIDs: [misleadingID, actualID])
        XCTAssertEqual(result, misleadingID)
        XCTAssertNotEqual(result, actualID)
    }

    func testFreshInclusiveBoundaries() {
        XCTAssertTrue(FamiliarFacePolicy.fresh(capturedAt: 8.5, now: 10, frameAt: 9.5))
        XCTAssertTrue(FamiliarFacePolicy.fresh(capturedAt: 10, now: 10, frameAt: 10))
        XCTAssertTrue(FamiliarFacePolicy.fresh(capturedAt: 0, now: 0, frameAt: 0))
    }

    func testStaleCaptureOrFrameRejects() {
        XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: 8.499, now: 10, frameAt: 10))
        XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: 9, now: 10, frameAt: 9.499))
    }

    func testFutureOrNonMonotonicTimesReject() {
        XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: 11, now: 10, frameAt: 10))
        XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: 10, now: 10, frameAt: 11))
        XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: 9.9, now: 10, frameAt: 9.8))
        XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: -1, now: 0, frameAt: 0))
    }

    func testNonfiniteTimesReject() {
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: invalid, now: 10, frameAt: 10))
            XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: 10, now: invalid, frameAt: 10))
            XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: 10, now: 10, frameAt: invalid))
        }
    }
    func testStrictBackendDimensions() {
        let aura = [Float](repeating: 1, count: 512)
        XCTAssertFalse(FamiliarFacePolicy.validFeature(aura))
        XCTAssertTrue(FamiliarFacePolicy.validFeature(aura, expectedDimension: 512))
        XCTAssertFalse(FamiliarFacePolicy.validFeature(axis(), expectedDimension: 512))
        XCTAssertFalse(FamiliarFacePolicy.validFeature([1], expectedDimension: 1))
        XCTAssertEqual(FamiliarFacePolicy.normalizedMean([aura], expectedDimension: 512)?.count, 512)
        XCTAssertNil(FamiliarFacePolicy.normalizedMean([aura, axis()], expectedDimension: 512))
        XCTAssertNil(FamiliarFacePolicy.normalizedMean([aura], expectedDimension: 7))
    }
    func testExplicitCalibratedExperimentParameters() {
        let a = UUID(), b = UUID()
        XCTAssertEqual(FamiliarFacePolicy.candidate(scores: [(a, 0.7), (b, 0.5)], cosineThreshold: 0.7, minimumMargin: 0.2), a)
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(a, 0.699)], cosineThreshold: 0.7, minimumMargin: 0.2))
        XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(a, 0.5), (b, 0.301)], cosineThreshold: 0.5, minimumMargin: 0.2))
        XCTAssertEqual(FamiliarFacePolicy.candidate(scores: [(a, 0.5), (b, 0.3)], cosineThreshold: 0.5, minimumMargin: 0.2), a)
        for invalid in [Double.nan, .infinity, -1.01, 1.01] {
            XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(a, 1)], cosineThreshold: invalid))
        }
        for invalid in [Double.nan, .infinity, -0.01, 2.01] {
            XCTAssertNil(FamiliarFacePolicy.candidate(scores: [(a, 1)], minimumMargin: invalid))
        }
        XCTAssertEqual(FamiliarFacePolicy.candidate(probe: axis(), gallery: [(a, axis())], cosineThreshold: 0.7, minimumMargin: 0.2), a)
        let aura = [Float](repeating: 1, count: 512)
        XCTAssertEqual(FamiliarFacePolicy.candidate(probe: aura, gallery: [(a, aura)], expectedDimension: 512, cosineThreshold: 0.5, minimumMargin: 0.2), a)
    }
    func testSnapshotSpeechDoesNotExtendLiveResult() {
        XCTAssertFalse(FamiliarFacePolicy.fresh(capturedAt: 0, now: 12, frameAt: 12))
        XCTAssertTrue(FamiliarFacePolicy.snapshotSpeechFresh(capturedAt: 0, now: 12, frameAt: 12))
        XCTAssertFalse(FamiliarFacePolicy.snapshotSpeechFresh(capturedAt: 0, now: 12.001, frameAt: 12.001))
        XCTAssertFalse(FamiliarFacePolicy.snapshotSpeechFresh(capturedAt: 1, now: 3, frameAt: 2.49))
        XCTAssertFalse(FamiliarFacePolicy.snapshotSpeechFresh(capturedAt: 4, now: 3, frameAt: 3))
        XCTAssertFalse(FamiliarFacePolicy.snapshotSpeechFresh(capturedAt: .nan, now: 3, frameAt: 3))
        XCTAssertFalse(FamiliarFacePolicy.snapshotSpeechFresh(capturedAt: -1, now: 3, frameAt: 3))
    }

    func testOneShotLossUnusablePoseMultifaceAndOutOfOrderNeverRetainName() {
        let old = UUID(), current = UUID(), mom = UUID(), other = UUID()
        func decide(_ request: UUID, _ count: Int, _ feature: [Float], _ id: UUID) -> UUID? {
            FamiliarFacePolicy.candidateForAttempt(requestID: request, currentRequestID: current,
                faceCount: count, feature: feature, scores: [(id, 0.9)])
        }
        XCTAssertEqual(decide(current, 1, axis(), mom), mom)
        XCTAssertNil(decide(current, 0, [], mom)) // No face is not proof somebody turned away.
        XCTAssertNil(decide(current, 1, [], mom)) // Unusable alignment/pose does not name a parent.
        XCTAssertNil(decide(current, 2, axis(), mom))
        XCTAssertNil(decide(old, 1, axis(), mom))
        XCTAssertEqual(decide(current, 1, axis(), other), other) // Next request can differ.
    }
    func testRetakeGuidanceCooldown() {
        XCTAssertTrue(FamiliarFacePolicy.shouldSpeakFaceGuidance(lastAt: nil, now: 0))
        XCTAssertFalse(FamiliarFacePolicy.shouldSpeakFaceGuidance(lastAt: 0, now: 7.99))
        XCTAssertTrue(FamiliarFacePolicy.shouldSpeakFaceGuidance(lastAt: 0, now: 8))
        XCTAssertFalse(FamiliarFacePolicy.shouldSpeakFaceGuidance(lastAt: 10, now: 8))
        XCTAssertFalse(FamiliarFacePolicy.shouldSpeakFaceGuidance(lastAt: nil, now: .nan))
    }

}
