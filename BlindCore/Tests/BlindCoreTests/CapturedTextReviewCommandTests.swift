import XCTest
@testable import BlindCore

final class CapturedTextReviewCommandTests: XCTestCase {
    func testExplicitEnglishReviewCommands() {
        let cases: [(String, CapturedTextReviewCommand)] = [
            ("repeat part", .repeatPart), ("repeat the current part", .repeatPart),
            ("repeat the last spoken part", .repeatPart), ("repeat last part", .repeatPart),
            ("previous part", .previousPart), ("read the previous part", .previousPart),
            ("next part", .nextPart), ("read the next part", .nextPart),
            ("read captured text again", .readAgain), ("read the captured text again", .readAgain),
            ("read this page again", .readAgain), ("forget this page", .forget),
            ("forget the captured page", .forget), ("forget captured text", .forget)
        ]
        for (text, expected) in cases {
            XCTAssertEqual(CapturedTextReviewCommand.parse(text), expected, text)
            XCTAssertNil(ReadingToolCommand.parse(text), "Review must not acquire a new source: \(text)")
        }
        XCTAssertEqual(CapturedTextReviewCommand.parse("  PLEASE repeat   the current part!  "), .repeatPart)
    }

    func testExplicitArabicAndDiacritics() {
        let cases: [(String, CapturedTextReviewCommand)] = [
            ("كرر الجزء الحالي", .repeatPart), ("أعد الجزء الأخير", .repeatPart),
            ("أعد آخر جزء قرأته", .repeatPart), ("الجزء السابق", .previousPart),
            ("اقرأ الجزء السابق", .previousPart), ("الجزء التالي", .nextPart),
            ("اقرأ الجزء التالي", .nextPart), ("اقرأ النص الملتقط مرة أخرى", .readAgain),
            ("أعد قراءة النص الملتقط", .readAgain), ("اقرأ هذه الصفحة مرة أخرى", .readAgain),
            ("انس هذه الصفحة", .forget), ("احذف النص الملتقط", .forget)
        ]
        for (text, expected) in cases {
            XCTAssertEqual(CapturedTextReviewCommand.parse(text), expected, text)
            XCTAssertNil(ReadingToolCommand.parse(text), text)
        }
        XCTAssertEqual(CapturedTextReviewCommand.parse("من فضلك أَعِدْ قِراءة النص الملتقط؟"), .readAgain)
    }

    func testNoGenericOrQuotedConditionalNegatedOwnership() {
        for text in ["repeat", "again", "continue", "next", "previous", "read again", "forget it",
                     "أعد", "كرر", "تابع", "التالي", "اقرأ مرة أخرى",
                     "\"repeat part\"", "'repeat part'", "“next part”", "«الجزء التالي»",
                     "do not repeat part", "don't forget this page", "لا تقرأ الجزء التالي",
                     "if I say next part", "say repeat part", "the page says next part",
                     "assistant: next part", "model says forget this page", "اقترح أن تقرأ الجزء التالي",
                     "repeat part and read the page", "next part; forget this page",
                     "please please next part", "read the page", "read text", "read the menu", ""] {
            XCTAssertNil(CapturedTextReviewCommand.parse(text), text)
        }
    }

    func testBoundedInput() {
        XCTAssertNil(CapturedTextReviewCommand.parse(String(repeating: " ", count: 300) + "next part"))
    }
    func testSimpleRepeatIsContextualAndNaturalPartAliasIsExplicit() {
        for text in ["repeat", "كرر", "Please repeat."] {
            XCTAssertNil(CapturedTextReviewCommand.parse(text))
            XCTAssertEqual(CapturedTextReviewCommand.parse(text, hasCapturedSource: true), .repeatPart)
        }
        XCTAssertEqual(CapturedTextReviewCommand.parse("repeat that part"), .repeatPart)
        for text in ["don't repeat", "قال كرر", "\"repeat\"", "repeat description"] {
            XCTAssertNil(CapturedTextReviewCommand.parse(text, hasCapturedSource: true))
        }
    }

}
