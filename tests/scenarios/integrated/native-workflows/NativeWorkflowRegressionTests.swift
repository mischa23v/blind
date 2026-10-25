#if DEBUG && BLIND_WORKFLOW_TESTS
import Foundation
import XCTest
import BlindCore
@testable import BlindAssist

/// Authored trusted-interface inputs; no model, microphone, camera or speech claim.
/// Each fixture must run in the dedicated workflow-test app, never the user's app.
@MainActor final class NativeWorkflowRegressionTests: XCTestCase {
    private func model() throws -> NavigationModel {
        guard Bundle.main.bundleIdentifier == "org.blindassist.workflowtests",
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            throw NSError(domain: "UnsafeWorkflowHost", code: 1)
        }
        let model = NavigationModel()
        XCTAssertTrue(model.textOnly)
        model.workflowReset()
        drainAtTeardown(model)
        return model
    }
    private func drainAtTeardown(_ model: NavigationModel) {
        addTeardownBlock {
            let committed = await model.workflowCommit()
            XCTAssertTrue(committed, "Each model must drain real persistence before the next test")
        }
    }
    private func record(_ id: String, _ snapshots: [NavigationModel.WorkflowSnapshot]) throws {
        // Always attach observations, including when assertions have failed.
        let bytes = try JSONEncoder().encode(snapshots)
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = id + "-authored-input-native-controller-observations"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testBackpackCorrectionSurvivesCommittedReopen() async throws {
        let first = try model()
        defer { try? record("backpack-before-reopen", first.workflowReceipts) }
        first.receiveCompanionUtterance("I left my backpack on the shelf.")
        first.receiveCompanionUtterance("I left my backpack on the desk.")
        let committed = await first.workflowCommit()
        XCTAssertTrue(committed, "Actual database commit required before reopen")
        // New controller reads actual persisted working-state; not JSON roundtrip injection.
        let reopened = NavigationModel()
        drainAtTeardown(reopened)
        defer { try? record("backpack-reopened", reopened.workflowReceipts) }
        reopened.receiveCompanionUtterance("Where did I leave my backpack?")
        reopened.workflowRecord("historical-reply-after-dispatch")
        XCTAssertTrue(reopened.currentReply.lowercased().contains("desk"))
        XCTAssertFalse(reopened.currentReply.lowercased().contains("shelf"))
        XCTAssertEqual(first.workflowModelInvocationsBlocked, 0)
        XCTAssertEqual(reopened.workflowModelInvocationsBlocked, 0)
        XCTAssertFalse(reopened.currentReply.lowercased().contains("i can see"))
    }
    func testFridgeCompletionIsRecordedBeforeCodeReply() async throws {
        let model = try model()
        defer { try? record("fridge-completion", model.workflowReceipts) }
        model.receiveCompanionUtterance("Help me find my fridge")
        model.receiveCompanionUtterance("I found my fridge")
        let receipt = try XCTUnwrap(model.workflowReceipts.last { $0.event == "code-reply" })
        XCTAssertTrue(receipt.completedReports.contains { $0.contains("I found my fridge") })
        XCTAssertFalse(receipt.taskCompletions.isEmpty)
        // Pending/committed revisions are observations, not a new immediate-durability contract.
        if receipt.reply.lowercased().contains("saved") {
            XCTAssertEqual(receipt.committedMemoryRevision, receipt.requestedMemoryRevision)
            XCTAssertFalse(receipt.memoryPending)
            XCTAssertEqual(receipt.memoryError, "")
        }
        XCTAssertEqual(receipt.reply, "Okay, I've noted that you said that step is done.")
        XCTAssertEqual(model.workflowModelInvocationsBlocked, 0)
        XCTAssertFalse(receipt.reply.contains("verified"))
        let committed = await model.workflowCommit()
        XCTAssertTrue(committed)
        let reopened = NavigationModel()
        drainAtTeardown(reopened)
        let persisted = reopened.workflowSnapshot("fridge-reopened-after-confirmed-commit")
        XCTAssertTrue(persisted.completedReports.contains { $0.contains("I found my fridge") })
        try record("fridge-reopened", [persisted])
    }
    func testQuietRetainsGoalCancelRemovesItNeitherClearsHazard() throws {
        let model = try model()
        defer { try? record("quiet-versus-cancel", model.workflowReceipts) }
        model.receiveCompanionUtterance("Help me find my backpack")
        let before = model.workflowSnapshot("before")
        XCTAssertFalse(before.goal.isEmpty)
        model.workflowInjectHazard(.obstacle)
        model.receiveCompanionUtterance("quiet")
        let quiet = model.workflowSnapshot("quiet")
        XCTAssertEqual(quiet.goal, before.goal)
        XCTAssertFalse(quiet.ambient)
        XCTAssertEqual(quiet.hazard, "obstacle")
        model.workflowRecord("quiet-after-dispatch")
        model.receiveCompanionUtterance("Cancel the task")
        let cancelled = model.workflowSnapshot("cancelled")
        XCTAssertEqual(cancelled.goal, "")
        XCTAssertEqual(cancelled.taskState, "cancelled")
        XCTAssertEqual(cancelled.hazard, "obstacle")
        XCTAssertEqual(cancelled.reply, "I've cancelled the current task.")
        XCTAssertEqual(model.workflowModelInvocationsBlocked, 0)
        model.workflowRecord("cancel-after-dispatch")
        // Hazard-state continuity only; actual warning/audio delivery is NOT RUN.
    }
}
#endif
