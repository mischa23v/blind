import XCTest
@testable import BlindCore

final class ReadingToolsTests: XCTestCase {
    func testCommands() {
        XCTAssertEqual(ReadingToolCommand.parse("Read the page."), .start(.document))
        XCTAssertEqual(ReadingToolCommand.parse("Can you read text"), .start(.liveText))
        XCTAssertEqual(ReadingToolCommand.parse("What product is this?"), .start(.barcode))
        XCTAssertEqual(ReadingToolCommand.parse("Is the light on?"), .start(.light))
        XCTAssertEqual(ReadingToolCommand.parse("اقرأ الصفحة"), .start(.document))
        XCTAssertEqual(ReadingToolCommand.parse("Stop reading"), .stop)
        XCTAssertEqual(ReadingToolCommand.parse("Call this apple juice"), .nameProduct("apple juice"))
        XCTAssertNil(ReadingToolCommand.parse("Read one banknote"))
        XCTAssertNil(ReadingToolCommand.parse("Help me find my cup"))
    }

    func testLiveTextSpeaksNewLinesOnceTopToBottom() {
        var reader = LiveTextReader()
        let lines = [TextLine(text: "Exit", confidence: 0.9, x: 0.5, y: 0.6), TextLine(text: "Room 12", confidence: 0.9, x: 0.5, y: 0.2),
                     TextLine(text: "xq", confidence: 0.2, x: 0.1, y: 0.1)]
        XCTAssertEqual(reader.newLines(lines, now: 0), ["Room 12", "Exit"])
        XCTAssertEqual(reader.newLines(lines, now: 1), [])
        XCTAssertEqual(reader.newLines([], now: 20), [])
        XCTAssertEqual(reader.newLines(lines, now: 21), ["Room 12", "Exit"])
    }

    func testDocumentGuidance() {
        XCTAssertEqual(DocumentGuidance.evaluate(nil), .noPage)
        let centred = [(x: 0.2, y: 0.2), (x: 0.8, y: 0.2), (x: 0.8, y: 0.8), (x: 0.2, y: 0.8)]
        XCTAssertEqual(DocumentGuidance.evaluate(centred), .holdStill)
        let cutLeft = [(x: 0.0, y: 0.2), (x: 0.7, y: 0.2), (x: 0.7, y: 0.8), (x: 0.0, y: 0.8)]
        XCTAssertEqual(DocumentGuidance.evaluate(cutLeft), .moveLeft)
        let small = [(x: 0.4, y: 0.4), (x: 0.6, y: 0.4), (x: 0.6, y: 0.6), (x: 0.4, y: 0.6)]
        XCTAssertEqual(DocumentGuidance.evaluate(small), .moveCloser)
        let full = [(x: 0.0, y: 0.0), (x: 1.0, y: 0.0), (x: 1.0, y: 1.0), (x: 0.0, y: 1.0)]
        XCTAssertEqual(DocumentGuidance.evaluate(full), .moveBack)
    }

    func testCodesAndProducts() {
        XCTAssertEqual(CodeReading.speech(payload: "https://school.example/sheet", isQR: true, savedName: nil, arabic: false),
                       "A QR code with a link to school.example. I won't open it by myself.")
        var products = ProductMemory()
        XCTAssertTrue(products.save("apple juice", for: "6281000000001"))
        XCTAssertEqual(CodeReading.speech(payload: "6281000000001", isQR: false, savedName: products.name(for: "6281000000001"), arabic: false), "This is apple juice.")
        XCTAssertTrue(CodeReading.speech(payload: "123", isQR: false, savedName: nil, arabic: false).hasPrefix("Product code: 1 2 3."))
    }

    func testLightLevels() {
        XCTAssertEqual(LightLevel.from(lumens: 30), .dark)
        XCTAssertEqual(LightLevel.from(lumens: 1000), .medium)
        XCTAssertEqual(LightLevel.from(lumens: 5000), .veryBright)
        XCTAssertNil(LightLevel.from(lumens: .nan))
        XCTAssertLessThan(LightLevel.veryBright.beepInterval, LightLevel.dark.beepInterval)
    }
}
