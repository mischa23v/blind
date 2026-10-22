import XCTest
@testable import BlindCore

final class SaudiBanknotePolicyTests: XCTestCase {
    // Synthetic policy tests only. These thresholds are NOT a calibrated model profile.
    let thresholds = SaudiBanknotePolicy.Thresholds(confidence: 0.99, margin: 0.2, minimumArea: 0.1)
    func note(_ value: Int, score: Double = 0.999, x: Double = 0.1, width: Double = 0.7) -> SaudiBanknotePolicy.Detection {
        var scores = Dictionary(uniqueKeysWithValues: SaudiBanknotePolicy.denominations.map { ($0, 0.001) })
        scores[value] = score
        return .init(scores: scores, x: x, y: 0.2, width: width, height: 0.5)
    }
    func testAllDenominationsExactNotPrefix() {
        for value in SaudiBanknotePolicy.denominations {
            XCTAssertEqual(SaudiBanknotePolicy.decide([note(value)], thresholds: thresholds), .denomination(value))
        }
    }
    func testOneHundredVersusOneRequiresMargin() {
        var scores = Dictionary(uniqueKeysWithValues: SaudiBanknotePolicy.denominations.map { ($0, 0.001) })
        scores[100] = 0.999; scores[1] = 0.9
        let d = SaudiBanknotePolicy.Detection(scores: scores, x: 0.1, y: 0.2, width: 0.7, height: 0.5)
        XCTAssertEqual(SaudiBanknotePolicy.decide([d], thresholds: thresholds), .unknown)
    }
    func testUnknownLowConfidenceAndMultipleNeverSpeakValue() {
        XCTAssertEqual(SaudiBanknotePolicy.decide([], thresholds: thresholds), .unknown)
        XCTAssertEqual(SaudiBanknotePolicy.decide([note(100, score: 0.98)], thresholds: thresholds), .unknown)
        XCTAssertEqual(SaudiBanknotePolicy.decide([note(100), note(1, score: 0.05)], thresholds: thresholds), .multiple)
    }
    func testMeasuredFramingOnly() {
        XCTAssertEqual(SaudiBanknotePolicy.decide([note(5, x: 0)], thresholds: thresholds), .clipped)
        XCTAssertEqual(SaudiBanknotePolicy.decide([note(5, width: 0.1)], thresholds: thresholds), .tooSmall)
    }
    func testMalformedOutputsFailClosed() {
        for scores in [[100: Double.nan], [100: 1.1], [999: 1.0], [100: 1.0]] {
            XCTAssertEqual(SaudiBanknotePolicy.decide([.init(scores: scores, x: 0.1, y: 0.2, width: 0.7, height: 0.5)], thresholds: thresholds), .unknown)
        }
        XCTAssertEqual(SaudiBanknotePolicy.decide([note(100, x: .infinity)], thresholds: thresholds), .unknown)
        XCTAssertEqual(SaudiBanknotePolicy.decide([note(100)], thresholds: .init(confidence: .nan, margin: 0.1, minimumArea: 0.1)), .unknown)
    }
    func testUnknownScoreVetoesConfidentKnownLabel() {
        var scores = Dictionary(uniqueKeysWithValues: SaudiBanknotePolicy.denominations.map { ($0, 0.001) })
        scores[100] = 0.999
        let d = SaudiBanknotePolicy.Detection(scores: scores, unknownScore: 0.9, x: 0.1, y: 0.2, width: 0.7, height: 0.5)
        XCTAssertEqual(SaudiBanknotePolicy.decide([d], thresholds: thresholds), .unknown)
    }
    func testSnapshotExpiresAndRejectsFutureOrInvalidTime() {
        XCTAssertTrue(SaudiBanknotePolicy.fresh(capturedAt: 10, now: 12))
        XCTAssertFalse(SaudiBanknotePolicy.fresh(capturedAt: 10, now: 12.001))
        XCTAssertFalse(SaudiBanknotePolicy.fresh(capturedAt: 10, now: 9))
        XCTAssertFalse(SaudiBanknotePolicy.fresh(capturedAt: .nan, now: 10))
    }
    func testGenericMoneyValuesBlockedIncludingWrittenAmounts() {
        for text in ["This is 100 Saudi riyals", "One hundred riyals", "هذه ورقة من فئة ١٠٠ ريال", "خمسة ريالات", "A 20 dollar banknote", "﷼100", "100.", "It’s a hundred."] {
            XCTAssertTrue(SaudiBanknotePolicy.containsUnverifiedMoneyValue(text), text)
        }
        XCTAssertFalse(SaudiBanknotePolicy.containsUnverifiedMoneyValue("There is a banknote in view"))
        XCTAssertFalse(SaudiBanknotePolicy.containsUnverifiedMoneyValue("The book is on a table"))
        for text in ["What is the value of this banknote?", "read this banknote please", "ما قيمة العملة؟", "What denomination is this?", "How much is this bill?", "How much is this?"] {
            XCTAssertTrue(SaudiBanknoteCommand.matches(text), text)
        }
    }
    func testRoutesCashQuestionsButNotTransactions() {
        XCTAssertTrue(SaudiBanknoteCommand.matches("Read this banknote?"))
        XCTAssertTrue(SaudiBanknoteCommand.matches("اقرأ النقود"))
        XCTAssertTrue(SaudiBanknoteCommand.matches("is this money real"))
        XCTAssertTrue(SaudiBanknoteCommand.matches("count all my money"))
        XCTAssertTrue(SaudiBanknotePolicy.containsUnverifiedMoneyValue("This banknote is genuine"))
        for text in ["send money", "I need money", "read my bank account"] {
            XCTAssertFalse(SaudiBanknoteCommand.matches(text))
        }
    }
}
