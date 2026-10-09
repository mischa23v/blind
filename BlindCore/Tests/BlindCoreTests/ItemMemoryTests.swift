import XCTest
@testable import BlindCore

final class ItemMemoryTests: XCTestCase {
    let saved = Date(timeIntervalSince1970: 1_800_000_000)

    func testRememberFindReplaceAndForget() throws {
        var memory = ItemMemory()
        let first = try XCTUnwrap(memory.remember(name: " Braille Book ", roomID: "r1", roomName: "bedroom", at: saved))
        XCTAssertEqual(first.name, "Braille Book"); XCTAssertEqual(first.key, "braille book"); XCTAssertEqual(first.source, "user")
        XCTAssertEqual(memory.find("braille book")?.id, first.id)
        let moved = try XCTUnwrap(memory.remember(name: "braille book", roomID: "r2", roomName: "kitchen",
                                                  position: Point3(1, 0, -2), frameID: "home-v3",
                                                  at: saved.addingTimeInterval(60)))
        XCTAssertEqual(memory.items.count, 1); XCTAssertEqual(moved.id, first.id)
        XCTAssertEqual(memory.find("Braille Book")?.roomName, "kitchen")
        XCTAssertTrue(memory.valid)
        XCTAssertFalse(memory.forget("book")) // loose phrases never delete
        XCTAssertTrue(memory.forget("my braille book"))
        XCTAssertNil(memory.find("braille book")); XCTAssertFalse(memory.forget("braille book"))
    }

    func testContainsMatchPrefersMostRecentAndUsesWholeWords() {
        var memory = ItemMemory()
        memory.remember(name: "braille book", at: saved)
        memory.remember(name: "story book", at: saved.addingTimeInterval(300))
        memory.remember(name: "open box", at: saved)
        XCTAssertEqual(memory.find("book")?.name, "story book")
        XCTAssertEqual(memory.find("my big braille book")?.name, "braille book")
        XCTAssertNil(memory.find("pen")) // "pen" is not a whole word of "open box"
        XCTAssertNil(memory.find("my")); XCTAssertNil(memory.find("  "))
    }

    func testNormalizationCaseMyArticleAlefAndTaaMarbuta() {
        var memory = ItemMemory()
        memory.remember(name: "Café Key", at: saved)
        memory.remember(name: "كتاب البرايل", at: saved)
        memory.remember(name: "أقلامي", at: saved)
        memory.remember(name: "حقيبة المدرسة", at: saved)
        XCTAssertEqual(memory.find("my cafe key")?.name, "Café Key")
        XCTAssertEqual(memory.find("THE CAFE KEY")?.name, "Café Key")
        XCTAssertEqual(memory.find("الكتاب برايل")?.name, "كتاب البرايل")
        XCTAssertEqual(memory.find("اقلامي")?.name, "أقلامي")
        XCTAssertEqual(memory.find("حقيبه مدرسه")?.name, "حقيبة المدرسة")
        XCTAssertEqual(memory.find("أقلامِي")?.name, "أقلامي") // tashkeel ignored
    }

    func testInputBoundsAndSixtyFourItemLimit() {
        var memory = ItemMemory()
        XCTAssertNil(memory.remember(name: "   ", at: saved))
        XCTAssertNil(memory.remember(name: "my", at: saved))
        XCTAssertNil(memory.remember(name: String(repeating: "a", count: 81), at: saved))
        XCTAssertNil(memory.remember(name: "cup", position: Point3(1, 0, 1), at: saved)) // position needs a frame
        XCTAssertNil(memory.remember(name: "cup", position: Point3(.nan, 0, 1), frameID: "f1", at: saved))
        XCTAssertNotNil(memory.remember(name: String(repeating: "a", count: 80), at: saved))
        for index in 1..<ItemMemory.limit { XCTAssertNotNil(memory.remember(name: "item \(index)", at: saved)) }
        XCTAssertEqual(memory.items.count, 64)
        XCTAssertNil(memory.remember(name: "one more", at: saved))
        XCTAssertNotNil(memory.remember(name: "item 5", roomName: "hall", at: saved)) // replacing still works
        XCTAssertEqual(memory.items.count, 64); XCTAssertTrue(memory.valid)
    }

    func testParseEnglishCommands() {
        XCTAssertEqual(ItemCommand.parse("Remember my braille book here."), .remember("braille book"))
        XCTAssertEqual(ItemCommand.parse("remember my braille book is here"), .remember("braille book"))
        XCTAssertEqual(ItemCommand.parse("remember my keys are here"), .remember("keys"))
        XCTAssertEqual(ItemCommand.parse("Remember where my cane is"), .remember("cane"))
        XCTAssertEqual(ItemCommand.parse("Where is my braille book?"), .find("braille book"))
        XCTAssertEqual(ItemCommand.parse("where are my shoes"), .find("shoes"))
        XCTAssertEqual(ItemCommand.parse("Where did I leave my headphones?"), .find("headphones"))
        XCTAssertEqual(ItemCommand.parse("Forget my old ball."), .forget("old ball"))
    }

    func testParseArabicCommands() {
        XCTAssertEqual(ItemCommand.parse("تذكر كتابي هنا"), .remember("كتابي"))
        XCTAssertEqual(ItemCommand.parse("أين كتابي؟"), .find("كتابي"))
        XCTAssertEqual(ItemCommand.parse("اين كتابي"), .find("كتابي"))
        XCTAssertEqual(ItemCommand.parse("وين شنطتي"), .find("شنطتي"))
        XCTAssertEqual(ItemCommand.parse("انس كتابي"), .forget("كتابي"))
        XCTAssertEqual(ItemCommand.parse("انسَ كتابي"), .forget("كتابي"))
    }

    func testOrdinaryQuestionsAreNotCaptured() {
        XCTAssertNil(ItemCommand.parse("Where is the bathroom in this mall?"))
        XCTAssertNil(ItemCommand.parse("Can you tell me where is my book?"))
        XCTAssertNil(ItemCommand.parse("Remember to call grandma"))
        XCTAssertNil(ItemCommand.parse("where is my"))
        XCTAssertNil(ItemCommand.parse("remember my here"))
        XCTAssertNil(ItemCommand.parse(""))
    }

    func testAnswerWordingEnglish() throws {
        XCTAssertEqual(ItemMemory.answer(for: nil, asked: "braille book", now: saved, sameFrame: false,
                                         measuredRelation: nil, arabic: false),
                       "I don't have your braille book saved. Say: remember my braille book here, when you put it down.")
        var memory = ItemMemory()
        let plain = try XCTUnwrap(memory.remember(name: "braille book", roomName: "bedroom", at: saved))
        XCTAssertEqual(ItemMemory.answer(for: plain, asked: "braille book", now: saved.addingTimeInterval(300),
                                         sameFrame: true, measuredRelation: "about 2 meters ahead", arabic: false),
                       "Your braille book was saved in the bedroom 5 minutes ago. Its current position is not confirmed.")
        let placed = try XCTUnwrap(memory.remember(name: "braille book", roomName: "bedroom",
                                                   position: Point3(1, 0, -2), frameID: "home-v3", at: saved))
        XCTAssertEqual(ItemMemory.answer(for: placed, asked: "book", now: saved.addingTimeInterval(7200),
                                         sameFrame: true, measuredRelation: "about 2 meters ahead, slightly left", arabic: false),
                       "Your braille book was saved in the bedroom 2 hours ago. Measured from here: about 2 meters ahead, slightly left.")
        XCTAssertEqual(ItemMemory.answer(for: placed, asked: "book", now: saved.addingTimeInterval(7200),
                                         sameFrame: false, measuredRelation: "about 2 meters ahead", arabic: false),
                       "Your braille book was saved in the bedroom 2 hours ago. Its current position is not confirmed.")
        XCTAssertEqual(ItemMemory.answer(for: placed, asked: "book", now: saved.addingTimeInterval(90),
                                         sameFrame: true, measuredRelation: nil, arabic: false),
                       "Your braille book was saved in the bedroom just now. Its current position is not confirmed.")
        XCTAssertEqual(ItemMemory.answer(for: placed, asked: "book", now: saved.addingTimeInterval(3 * 86400),
                                         sameFrame: false, measuredRelation: nil, arabic: false),
                       "Your braille book was saved in the bedroom 3 days ago. Its current position is not confirmed.")
    }

    func testAnswerWordingArabic() throws {
        XCTAssertEqual(ItemMemory.answer(for: nil, asked: "كتابي", now: saved, sameFrame: false,
                                         measuredRelation: nil, arabic: true),
                       "لم أحفظ مكان كتابي. قل: تذكر كتابي هنا، عندما تضعه.")
        var memory = ItemMemory()
        let placed = try XCTUnwrap(memory.remember(name: "كتابي", roomName: "غرفة النوم",
                                                   position: Point3(1, 0, -2), frameID: "home-v3", at: saved))
        XCTAssertEqual(ItemMemory.answer(for: placed, asked: "كتابي", now: saved.addingTimeInterval(300),
                                         sameFrame: false, measuredRelation: nil, arabic: true),
                       "تم حفظ كتابي في غرفة النوم قبل 5 دقائق. موقعه الحالي غير مؤكد.")
        XCTAssertEqual(ItemMemory.answer(for: placed, asked: "كتابي", now: saved.addingTimeInterval(7200),
                                         sameFrame: true, measuredRelation: "مترين أمامك", arabic: true),
                       "تم حفظ كتابي في غرفة النوم قبل ساعتين. القياس من هنا: مترين أمامك.")
    }

    func testCodableRoundTripAndLegacyEmpty() throws {
        var memory = ItemMemory()
        memory.remember(name: "braille book", roomID: "r1", roomName: "bedroom",
                        position: Point3(1.5, 0, -2.25), frameID: "home-v3", at: saved)
        memory.remember(name: "كتاب البرايل", at: saved)
        let restored = try JSONDecoder().decode(ItemMemory.self, from: JSONEncoder().encode(memory))
        XCTAssertEqual(restored, memory); XCTAssertTrue(restored.valid)
        let empty = try JSONDecoder().decode(ItemMemory.self, from: Data("{}".utf8))
        XCTAssertTrue(empty.items.isEmpty); XCTAssertTrue(empty.valid)
    }
}
