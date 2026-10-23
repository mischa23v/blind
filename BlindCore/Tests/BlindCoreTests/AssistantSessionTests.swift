import XCTest
@testable import BlindCore

final class AssistantSessionTests: XCTestCase {
    func testStartIsExplicitAndForegroundDoesNotRestartEndedSession() {
        var session = AssistantSession()
        XCTAssertEqual(session.state, .idle)
        XCTAssertFalse(session.backgroundAllowed)
        XCTAssertFalse(session.shouldListen)
        XCTAssertFalse(session.mayRespond)
        session.enterBackground(); session.enterForeground()
        XCTAssertEqual(session.state, .idle)
        session.start()
        let generation = session.generation
        XCTAssertTrue(session.shouldListen)
        XCTAssertTrue(session.shouldRunCamera)
        XCTAssertTrue(session.accepts(generation: generation))
        session.end()
        XCTAssertFalse(session.accepts(generation: generation))
        session.enterBackground(); session.enterForeground(); session.unmute()
        XCTAssertEqual(session.state, .ended)
        XCTAssertFalse(session.shouldListen)
        XCTAssertFalse(session.mayRespond)
        XCTAssertFalse(session.shouldRunCamera)
        session.start()
        XCTAssertTrue(session.shouldListen)
        XCTAssertFalse(session.accepts(generation: generation))
    }
    func testMutePreservedAcrossForegroundAndAllowsOnlyTypedResponses() {
        var session = AssistantSession(); session.start()
        let active = session.generation
        session.mute()
        XCTAssertEqual(session.state, .muted)
        XCTAssertFalse(session.shouldListen)
        XCTAssertTrue(session.mayRespond)
        XCTAssertTrue(session.shouldRunCamera)
        XCTAssertFalse(session.accepts(generation: active))
        session.enterBackground()
        XCTAssertFalse(session.mayRespond)
        XCTAssertFalse(session.shouldRunCamera)
        session.enterForeground()
        XCTAssertEqual(session.state, .muted)
        XCTAssertFalse(session.shouldListen)
        XCTAssertTrue(session.mayRespond)
        session.unmute()
        XCTAssertTrue(session.shouldListen)
    }
    func testBackgroundOptInDoesNotAuthorizeCameraOrOverrideMuteAndEnd() {
        var session = AssistantSession(); session.start(); session.enterBackground()
        XCTAssertFalse(session.shouldListen)
        XCTAssertFalse(session.mayRespond)
        session.setBackgroundAllowed(true)
        XCTAssertTrue(session.shouldListen)
        XCTAssertTrue(session.mayRespond)
        XCTAssertFalse(session.shouldRunCamera)
        let backgroundGeneration = session.generation
        session.setBackgroundAllowed(false)
        XCTAssertFalse(session.shouldListen)
        XCTAssertFalse(session.accepts(generation: backgroundGeneration))
        session.setBackgroundAllowed(true); session.mute()
        XCTAssertFalse(session.shouldListen)
        session.end(); session.enterForeground()
        XCTAssertFalse(session.shouldListen)
        XCTAssertFalse(session.mayRespond)
    }
    func testEveryEffectiveTransitionFencesPendingWorkAndNoOpsAreStable() {
        var session = AssistantSession(); session.start()
        var previous = session.generation
        session.start(); session.unmute(); session.enterForeground(); session.setBackgroundAllowed(false)
        XCTAssertEqual(session.generation, previous)
        session.invalidate()
        XCTAssertNotEqual(session.generation, previous)
        previous = session.generation
        session.enterBackground()
        XCTAssertNotEqual(session.generation, previous)
        previous = session.generation
        session.enterBackground()
        XCTAssertEqual(session.generation, previous)
        session.enterForeground()
        XCTAssertNotEqual(session.generation, previous)
    }
    func testPermissionSettingsDoNotStartIdleSession() {
        var session = AssistantSession()
        session.setBackgroundAllowed(true); session.enterBackground(); session.unmute(); session.mute()
        XCTAssertEqual(session.state, .idle)
        XCTAssertFalse(session.shouldListen)
        XCTAssertFalse(session.accepts(generation: session.generation))
    }
}
