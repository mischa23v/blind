import XCTest
@testable import BlindCore

final class LocateCommandTests: XCTestCase {
    func testTargetsAreShortWholeUtterances() {
        XCTAssertEqual(LocateCommand.target("Where is the exit sign?"), "exit sign")
        XCTAssertEqual(LocateCommand.target("find the door"), "door")
        XCTAssertEqual(LocateCommand.target("أين الباب"), "الباب")
        XCTAssertNil(LocateCommand.target("Where is the nearest place in this mall that sells warm winter coats for children?"))
        XCTAssertNil(LocateCommand.target("What is on the table?"))
        XCTAssertNil(LocateCommand.target("Where is the "))
    }

    func testMatchingIsCaseAndWordBased() {
        XCTAssertTrue(LocateCommand.matches(target: "exit", label: "EXIT ->"))
        XCTAssertTrue(LocateCommand.matches(target: "exit sign", label: "Emergency exit sign"))
        XCTAssertFalse(LocateCommand.matches(target: "door", label: "window"))
        XCTAssertFalse(LocateCommand.matches(target: "", label: "door"))
    }
}
