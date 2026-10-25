#if DEBUG && BLIND_WORKFLOW_TESTS && BLIND_ACCESSIBLE_OUTPUT_TESTS
import Foundation
import AVFoundation
import XCTest
@testable import BlindAssist

/// A real native-output producer probe, NOT a listener-comprehension or actor trial.
/// Inputs are authored; completions must come from the actual AVSpeech delegate.
private final class AccessibleProbeNetworkDeny: URLProtocol {
    private static let lock = NSLock()
    private static var count = 0
    static var attempted: Int { lock.lock(); defer { lock.unlock() }; return count }
    override class func canInit(with request: URLRequest) -> Bool {
        ["http", "https"].contains(request.url?.scheme?.lowercased() ?? "")
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.count += 1; Self.lock.unlock()
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}

@MainActor final class NativeAccessibleOutputTests: XCTestCase {
    private var receipts: [Feedback.AccessibleOutputReceipt] = []
    private var inputs: [String] = []
    private struct ActorVisibleOutput: Codable {
        let kind = "accessible_output"
        let receipt_id: String
        let text: String
        let monotonic: Double
        let delivery_evidence = "actual_AVSpeech_completion_callback_not_proof_listener_heard_or_understood"
    }

    private func attach<T: Encodable>(_ value: T, name: String) throws {
        let data = try JSONEncoder().encode(value)
        let artifact = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        artifact.name = name; artifact.lifetime = .keepAlways; add(artifact)
    }
    private func availablePlayback() throws {
        // Enumerate system-advertised available voices; do NOT request/download assets.
        // A listed voice is not by itself delivery proof: callbacks remain mandatory.
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let selected = AVSpeechSynthesisVoice(language: "en-US")
        let listed = selected.map { voice in voices.contains { $0.identifier == voice.identifier } } ?? false
        var evidence = ["selectedVoice": selected?.identifier ?? "UNAVAILABLE",
                        "voiceListedBySystem": String(listed),
                        "listedVoiceCount": String(voices.count),
                        "voiceAssetInstallationVerified": "NO_PUBLIC_ASSET_PROOF_CALLBACK_REQUIRED",
                        "microphoneRequested": "false", "downloadsRequested": "false"]
        guard listed, let selected, selected.language == "en-US" else {
            try attach(evidence, name: "AccessibleAvailability-BLOCKED")
            throw NSError(domain: "NativeAccessibleOutputUnavailable", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "BLOCKED: no system-listed en-US voice; no asset download attempted"])
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            evidence["routeStatus"] = "PLAYBACK_SESSION_FAILED"
            try attach(evidence, name: "AccessibleAvailability-BLOCKED")
            throw error
        }
        let ports = session.currentRoute.outputs.map { $0.portType.rawValue }
        evidence["outputPortTypes"] = ports.joined(separator: ",")
        try attach(evidence, name: "AccessibleAvailability")
        guard !ports.isEmpty else {
            throw NSError(domain: "NativeAccessibleOutputUnavailable", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "BLOCKED: playback route absent; no mocked route or completion"])
        }
    }
    private func receiveCompletedOutput(_ input: String, model: NavigationModel) async throws -> Feedback.AccessibleOutputReceipt {
        let first = receipts.count
        let done = expectation(description: "Actual AVSpeech.didFinish for authored turn \(inputs.count + 1)")
        done.assertForOverFulfill = true
        var finished: Feedback.AccessibleOutputReceipt?
        model.feedback.accessibleOutputObserver = { [weak self] event in
            self?.receipts.append(event)
            if event.event == "completed" {
                finished = event; done.fulfill()
            }
        }
        inputs.append(input)
        model.receiveCompanionUtterance(input, fromVoice: false)
        // Timeout is a failed/unavailable native-output probe, NEVER a fabricated finish.
        await fulfillment(of: [done], timeout: 40, enforceOrder: true)
        let terminal = try XCTUnwrap(finished, "BLOCKED: native completion unavailable; text-only fallback does not satisfy this test")
        let turnEvents = Array(receipts.dropFirst(first))
        let admission = try XCTUnwrap(turnEvents.first { $0.event == "admitted" && $0.receiptID == terminal.receiptID })
        let start = try XCTUnwrap(turnEvents.first { $0.event == "started" && $0.receiptID == terminal.receiptID })
        XCTAssertEqual(admission.destinationID, terminal.destinationID)
        XCTAssertEqual(start.destinationID, terminal.destinationID)
        XCTAssertEqual(admission.text, terminal.text)
        XCTAssertEqual(start.text, terminal.text)
        XCTAssertEqual(terminal.transport, "speech")
        XCTAssertEqual(terminal.cause, "AVSpeech.didFinish")
        XCTAssertEqual(terminal.outcome, "completed")
        XCTAssertLessThanOrEqual(admission.monotonic, start.monotonic)
        XCTAssertLessThanOrEqual(start.monotonic, terminal.monotonic)
        XCTAssertFalse(turnEvents.contains { $0.event == "cancelled" })
        return terminal
    }
    func testBackpackCorrectionUsesActualNativeSpeechCallbacks() async throws {
        guard Bundle.main.bundleIdentifier == "org.blindassist.accessibleworkflowtests",
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            throw NSError(domain: "UnsafeAccessibleProbeHost", code: 1)
        }
        guard URLProtocol.registerClass(AccessibleProbeNetworkDeny.self) else {
            throw NSError(domain: "AccessibleIsolationUnavailable", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "BLOCKED: app URL-loading tripwire could not be installed"])
        }
        defer {
            URLProtocol.unregisterClass(AccessibleProbeNetworkDeny.self)
            try? AVAudioSession.sharedInstance().setActive(false)
            try? attach(["blockedAppNetworkAttempts": AccessibleProbeNetworkDeny.attempted], name: "AccessibleIsolation-network")
        }
        try availablePlayback()
        let model = NavigationModel()
        model.beginAccessibleOutputProbe()
        defer {
            try? attach(receipts, name: "AccessibleCallbackProbe-all-events")
            try? attach(inputs, name: "AccessibleProbe-authored-inputs-NOT-ACTOR-DECISIONS")
            // Actor-visible export contains only actual completed accessible output.
            // Neither state snapshots nor authored expected replies enter this channel.
            let visible = receipts.filter { $0.event == "completed" && $0.cause == "AVSpeech.didFinish" }.map {
                ActorVisibleOutput(receipt_id: $0.receiptID, text: $0.text, monotonic: $0.monotonic)
            }
            try? attach(visible, name: "AccessibleActorOutput-ONLY-COMPLETED-OUTPUT")
            model.feedback.accessibleOutputObserver = nil
            model.endAccessibleOutputProbe()
        }
        XCTAssertTrue(model.textOnly, "Capture/microphone isolation must remain enabled")
        XCTAssertFalse(model.running)
        XCTAssertFalse(model.cameraAwareness)
        XCTAssertFalse(model.voice.listening)
        let first = try await receiveCompletedOutput("I left my backpack on the shelf.", model: model)
        XCTAssertTrue(first.text.lowercased().contains("shelf"))
        let corrected = try await receiveCompletedOutput("I left my backpack on the desk.", model: model)
        XCTAssertTrue(corrected.text.lowercased().contains("desk"))
        let recalled = try await receiveCompletedOutput("Where did I leave my backpack?", model: model)
        XCTAssertTrue(recalled.text.lowercased().contains("desk"))
        XCTAssertFalse(recalled.text.lowercased().contains("shelf"))
        XCTAssertTrue(recalled.text.lowercased().contains("told me"))
        XCTAssertEqual(model.workflowModelInvocationsBlocked, 0)
        XCTAssertEqual(AccessibleProbeNetworkDeny.attempted, 0)
        XCTAssertFalse(model.running)
        XCTAssertFalse(model.voice.listening)
        let committed = await model.workflowCommit()
        XCTAssertTrue(committed)
        // This proves callbacks for a nonphysical history task only. It does not
        // prove acoustic output, listener understanding, or actual backpack retrieval.
    }
}
#endif
