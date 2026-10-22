import XCTest
@testable import BlindCore

final class FamiliarPeopleCommandTests: XCTestCase {
    func testNamedSearchPreservesExactLabelWithoutInferringParent() {
        XCTAssertEqual(FamiliarPeopleCommand.parse("find person Mom"), .find("Mom"))
        XCTAssertEqual(FamiliarPeopleCommand.parse("find person Dad"), .find("Dad"))
        XCTAssertEqual(FamiliarPeopleCommand.parse("ابحث عن شخص أمي"), .find("أمي"))
        // A literal label is not resolved to a parent, guardian, or either enrolled relative.
        XCTAssertEqual(FamiliarPeopleCommand.parse("find person parent"), .find("parent"))
        for text in ["find my parent", "find Mom", "find person Mom or Dad", "ابحث عن شخص أمي أو أبي",
                     "he said find person Mom", "\"find person Dad\"", "find person ", "find person Mom\u{202E}"] {
            XCTAssertNil(FamiliarPeopleCommand.parse(text), text)
        }
    }

    func testExactEnglishCommands() {
        let cases: [(String, FamiliarPeopleCommand)] = [
            ("familiar people", .open), ("who is this", .recognize),
            ("capture face", .capture), ("import face photos", .importPhotos),
            ("confirm face action", .confirm), ("cancel face action", .cancel),
            ("retry face capture", .retry), ("finish face enrollment", .finishEnrollment),
            ("stop familiar people", .stop)
        ]
        for (text, expected) in cases { XCTAssertEqual(FamiliarPeopleCommand.parse(text), expected, text) }
        XCTAssertEqual(FamiliarPeopleCommand.parse("  WHO IS THIS?  "), .recognize)
    }

    func testExactArabicCommands() {
        let cases: [(String, FamiliarPeopleCommand)] = [
            ("الأشخاص المألوفون", .open), ("من هذا؟", .recognize),
            ("التقط الوجه", .capture), ("استورد صور الوجه", .importPhotos),
            ("أكد إجراء الوجه", .confirm), ("ألغ إجراء الوجه", .cancel),
            ("أعد التقاط الوجه", .retry), ("أنهِ تسجيل الوجه", .finishEnrollment),
            ("أوقف الأشخاص المألوفين", .stop)
        ]
        for (text, expected) in cases { XCTAssertEqual(FamiliarPeopleCommand.parse(text), expected, text) }
    }

    func testLabelsPreserveCaseAndDoNotInferKinship() {
        let cases: [(String, FamiliarPeopleCommand)] = [
            ("enroll person Mom", .enroll("Mom")), ("ADD FACE EXAMPLES FOR Mary Jane", .addExamples("Mary Jane")),
            ("replace face examples for Dad", .replaceExamples("Dad")), ("review person O'Connor", .review("O'Connor")),
            ("delete person Anne-Marie", .deletePerson("Anne-Marie")),
            ("سجل شخص أُمّي", .enroll("أُمّي")), ("أضف أمثلة وجه للشخص أبي", .addExamples("أبي")),
            ("استبدل أمثلة وجه للشخص خالد", .replaceExamples("خالد")), ("راجع شخص محمد علي", .review("محمد علي")),
            ("احذف شخص أختي", .deletePerson("أختي"))
        ]
        for (text, expected) in cases { XCTAssertEqual(FamiliarPeopleCommand.parse(text), expected, text) }
    }

    func testUnknownQuotedAndCompoundUtterancesAreNotCommands() {
        for text in ["yes", "no", "نعم", "لا", "confirm", "cancel", "stop", "Mom", "that's my mother",
                     "he said familiar people", "say who is this", "\"who is this\"", "‘delete person Mom’",
                     "I want to know who is this", "who is this and where is the exit", "capture face now",
                     "delete person Mom and Dad", "enroll person Mom then capture", "review person Dad please",
                     "احذف شخص أمي ثم أبي", "enroll person \"Mom\"", "familiar people!!",
                     "enroll person this is a very long explanation about a person"] {
            XCTAssertNil(FamiliarPeopleCommand.parse(text), text)
        }
    }

    func testLabelBoundsAndMalformedLabels() {
        let sixty = String(repeating: "a", count: 60)
        XCTAssertEqual(FamiliarPeopleCommand.parse("enroll person " + sixty), .enroll(sixty))
        XCTAssertNil(FamiliarPeopleCommand.parse("enroll person " + sixty + "a"))
        for label in ["", " ", "-Mom", "Mom-", "A/B", "Mom; capture face", "Mom  Dad", "A B C D E", "👩", "Mom\tDad", "Mom\nDad", "Mom\u{0000}", "Mom\u{202E}", "Mom\u{200B}"] {
            XCTAssertNil(FamiliarPeopleCommand.parse("enroll person " + label), label)
        }
        XCTAssertNil(FamiliarPeopleCommand.parse("\nconfirm face action"))
        XCTAssertNil(FamiliarPeopleCommand.parse("confirm face action\u{2028}"))
    }

    func testDeleteExampleIndicesAreStrictOneBasedAndBounded() {
        for index in 1...6 {
            XCTAssertEqual(FamiliarPeopleCommand.parse("delete face example \(index)"), .deleteExample(index))
        }
        for (offset, digit) in ["١", "٢", "٣", "٤", "٥", "٦"].enumerated() {
            XCTAssertEqual(FamiliarPeopleCommand.parse("احذف مثال الوجه \(digit)"), .deleteExample(offset + 1))
        }
        for index in ["", "0", "7", "-1", "+1", "01", "1.0", "one", "1 2", "1 and 2", "١٢", "٠", "٧"] {
            XCTAssertNil(FamiliarPeopleCommand.parse("delete face example " + index), index)
        }
    }
}
