import XCTest
@testable import BlindCore

final class AcousticSpeechOnsetTests: XCTestCase {
    private let rate = 48_000.0
    private func pcm(_ db: Double, frames: Int = 960) -> [Float] {
        let amplitude = pow(10, db / 20) * sqrt(2)
        return (0..<frames).map { Float(amplitude * sin(2 * .pi * 300 * Double($0) / rate)) }
    }
    @discardableResult private func feed(_ detector: inout AcousticSpeechOnset, db: Double,
                                        blocks: Int) -> Int {
        let samples = pcm(db)
        var onsets = 0
        for _ in 0..<blocks {
            samples.withUnsafeBufferPointer { if detector.process(samples: $0, sampleRate: rate) { onsets += 1 } }
        }
        return onsets
    }

    func testSyntheticPCMRequiresSustainedActivityAndDoesNotRepeatWhileHeld() {
        var detector = AcousticSpeechOnset()
        XCTAssertEqual(feed(&detector, db: -60, blocks: 20), 0)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 4), 0) // 80 ms is too brief.
        XCTAssertFalse(detector.isActive)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 2), 1)
        XCTAssertTrue(detector.isActive)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 150), 0)
    }

    func testContinuousUnclassifiedNoiseCannotHoldOrRetriggerForever() {
        var detector = AcousticSpeechOnset()
        feed(&detector, db: -60, blocks: 20)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 6), 1)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 200), 0)
        XCTAssertFalse(detector.isActive)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 200), 0)
        feed(&detector, db: -60, blocks: 20)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 6), 1)
    }

    func testShortImpulseAndSeparateBurstsDoNotAccumulateIntoSpeech() {
        var detector = AcousticSpeechOnset()
        feed(&detector, db: -60, blocks: 20)
        for _ in 0..<20 {
            XCTAssertEqual(feed(&detector, db: -6, blocks: 2), 0)
            XCTAssertEqual(feed(&detector, db: -60, blocks: 2), 0)
        }
        XCTAssertFalse(detector.isActive)
    }

    func testSteadyNoiseAndSlowlyChangingBaselineDoNotTrigger() {
        var detector = AcousticSpeechOnset()
        XCTAssertEqual(feed(&detector, db: -38, blocks: 100), 0)
        for db in stride(from: -38.0, through: -32.0, by: 0.5) {
            XCTAssertEqual(feed(&detector, db: db, blocks: 50), 0)
        }
        XCTAssertGreaterThan(detector.noiseFloorDBFS, -36)
        XCTAssertFalse(detector.isActive)
    }

    func testSilenceReleaseAndCooldownBoundRepeatedOnsets() {
        var detector = AcousticSpeechOnset()
        feed(&detector, db: -60, blocks: 20)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 6), 1)
        feed(&detector, db: -60, blocks: 14)
        XCTAssertTrue(detector.isActive)
        feed(&detector, db: -60, blocks: 1)
        XCTAssertFalse(detector.isActive)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 10), 0) // Cooldown not elapsed.
        XCTAssertEqual(feed(&detector, db: -25, blocks: 8), 1)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 100), 0)
    }

    func testRecognitionRequestRenewalDoesNotResetTheAcousticEnvelope() {
        var detector = AcousticSpeechOnset()
        feed(&detector, db: -60, blocks: 20)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 6), 1)
        // A new recognizer request retains this detector over the same live engine.
        var nextRecognitionRequest = detector
        XCTAssertEqual(feed(&nextRecognitionRequest, db: -25, blocks: 60), 0)
        feed(&nextRecognitionRequest, db: -60, blocks: 20)
        XCTAssertEqual(feed(&nextRecognitionRequest, db: -25, blocks: 6), 1)
    }

    func testNewCaptureRecalibratesAndQuietSpeechStillNeedsRecognizerFallback() {
        var detector = AcousticSpeechOnset()
        feed(&detector, db: -65, blocks: 20)
        XCTAssertEqual(feed(&detector, db: -50, blocks: 80), 0)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 6), 1)
        detector = AcousticSpeechOnset()
        XCTAssertFalse(detector.isActive)
        XCTAssertEqual(feed(&detector, db: -25, blocks: 5), 0)
    }

    func testInterleavedChannelStrideDoesNotReadTheOtherChannel() {
        var detector = AcousticSpeechOnset()
        var values = [Float]()
        let quiet = pcm(-60), loud = pcm(-10)
        for i in quiet.indices { values.append(quiet[i]); values.append(loud[i]) }
        for _ in 0..<40 {
            values.withUnsafeBufferPointer {
                XCTAssertFalse(detector.process(samples: $0, sampleRate: rate, stride: 2))
            }
        }
        XCTAssertFalse(detector.isActive)
    }

    func testInvalidPCMAndUnboundedBlocksCannotEmitOnset() {
        var detector = AcousticSpeechOnset()
        feed(&detector, db: -60, blocks: 20)
        XCTAssertFalse(detector.process(rms: .nan, duration: 0.02))
        XCTAssertFalse(detector.process(rms: 0.5, duration: .infinity))
        XCTAssertFalse(detector.process(rms: 0.5, duration: 10))
        XCTAssertFalse(detector.process(rms: -1, duration: 0.02))
        for values: [Float] in [[], [.nan], [.infinity], Array(repeating: 0.5, count: 24_000)] {
            values.withUnsafeBufferPointer { XCTAssertFalse(detector.process(samples: $0, sampleRate: rate)) }
        }
        pcm(-20).withUnsafeBufferPointer {
            XCTAssertFalse(detector.process(samples: $0, sampleRate: 0))
            XCTAssertFalse(detector.process(samples: $0, sampleRate: rate, stride: 0))
        }
        XCTAssertFalse(detector.isActive)
    }

    func testMailboxCoalescesEdgesWithoutPerBufferQueueGrowth() throws {
        var mailbox = AcousticOnsetMailbox()
        let capture = UUID(), turn = UUID()
        mailbox.beginCapture(capture); mailbox.beginTurn(turn)
        XCTAssertTrue(mailbox.offer(isActive: true, began: true, at: 1))
        for index in 0..<1_000 {
            XCTAssertFalse(mailbox.offer(isActive: index.isMultiple(of: 2), began: false, at: 1.01))
        }
        let update = try XCTUnwrap(mailbox.drain())
        XCTAssertEqual(update.capture, capture); XCTAssertEqual(update.turn, turn)
        XCTAssertEqual(update.onsetAt, 1); XCTAssertFalse(update.isActive)
        XCTAssertNil(mailbox.drain())
        XCTAssertTrue(mailbox.offer(isActive: true, began: true, at: 2))
    }

    func testMailboxCancellationAndTurnRenewalFenceQueuedOnsets() throws {
        var mailbox = AcousticOnsetMailbox()
        mailbox.beginCapture(UUID()); mailbox.beginTurn(UUID())
        XCTAssertTrue(mailbox.offer(isActive: true, began: true, at: 1))
        mailbox.beginTurn(UUID())
        XCTAssertNil(mailbox.drain())
        XCTAssertTrue(mailbox.offer(isActive: true, began: true, at: 2))
        mailbox.cancel()
        XCTAssertFalse(mailbox.offer(isActive: true, began: true, at: 3))
        XCTAssertNil(mailbox.drain())
        let capture = UUID(), turn = UUID()
        mailbox.beginCapture(capture); mailbox.beginTurn(turn)
        XCTAssertTrue(mailbox.offer(isActive: true, began: true, at: 4))
        mailbox.cancel()
        mailbox.beginCapture(capture); mailbox.beginTurn(turn)
        // The already queued main drain is reused, not duplicated.
        XCTAssertFalse(mailbox.offer(isActive: true, began: true, at: 5))
        XCTAssertEqual(try XCTUnwrap(mailbox.drain()).onsetAt, 5)
    }

    func testEnvelopeUsesElapsedAudioRatherThanBufferCount() {
        var first = AcousticSpeechOnset(), second = AcousticSpeechOnset()
        for _ in 0..<30 { _ = first.process(rms: 0.001, duration: 0.01) }
        for _ in 0..<15 { _ = second.process(rms: 0.001, duration: 0.02) }
        var firstOnsets = 0, secondOnsets = 0
        for _ in 0..<12 { if first.process(rms: 0.1, duration: 0.01) { firstOnsets += 1 } }
        for _ in 0..<6 { if second.process(rms: 0.1, duration: 0.02) { secondOnsets += 1 } }
        XCTAssertEqual(firstOnsets, 1); XCTAssertEqual(secondOnsets, 1)
    }
}
