import Foundation
@testable import BlindCore

@main
struct DebugNativeSessionTraceHarness {
    enum Failure: Error, Equatable { case write }
    final class ProducerError: Error, @unchecked Sendable {}
    static var passed = 0
    static func check(_ value: @autoclosure () -> Bool, _ name: String) {
        precondition(value(), name)
        passed += 1
        print("PASS \(name)")
    }
    static func read(_ directory: URL) throws -> [[String: Any]] {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let log = files.first { $0.pathExtension == "jsonl" }!
        return try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map {
            try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
        }
    }
    static func main() throws {
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("blind-debug-native-helper-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let nilTrace = DebugNativeSessionTrace(recorder: nil)
        var lazyCalls = 0
        nilTrace?.event(.userInput, source: .userTyped) { lazyCalls += 1; return .init(text: "unused") }
        check(nilTrace == nil && lazyCalls == 0, "disabled optional trace never evaluates payload")

        let disabledDirectory = root.appendingPathComponent("disabled")
        let disabled = DebugSessionLog(directory: disabledDirectory, enabled: false)
        let disabledTrace = DebugNativeSessionTrace(recorder: disabled, requestID: UUID())!
        disabledTrace.event(.userInput) { lazyCalls += 1; return .init(text: "unused") }
        disabled.drainForTesting()
        check(lazyCalls == 0 && !FileManager.default.fileExists(atPath: disabledDirectory.path), "disabled actual recorder rejects helper before payload and IO")

        let enabledDirectory = root.appendingPathComponent("enabled")
        let recorder = DebugSessionLog(directory: enabledDirectory, enabled: true)
        let request = UUID(), utterance = UUID()
        let trace = DebugNativeSessionTrace(recorder: recorder, requestID: request)!
        let original = "Synthetic exact output مرحباً 👋"
        var producerCalls = 0
        func produce() -> String { producerCalls += 1; return original }
        let baseline = produce()
        let baselineCalls = producerCalls
        producerCalls = 0
        let result = produce()
        trace.event(.toolResult, source: .toolRuntime, utteranceID: utterance) {
            lazyCalls += 1
            return .init(text: result, label: "syntheticTool.returnedExistingString")
        }
        check(result == baseline && producerCalls == baselineCalls, "helper preserves producer output and one invocation")
        check(lazyCalls == 1, "enabled actual recorder evaluates admitted payload once")

        producerCalls = 0
        let disabledOutput = produce()
        disabledTrace.event(.toolResult) { lazyCalls += 1; return .init(text: disabledOutput) }
        check(disabledOutput == baseline && producerCalls == 1 && lazyCalls == 1, "disabled helper leaves producer invocation and output unchanged")

        var failedProducerCalls = 0
        let originalError = ProducerError()
        func fail() throws -> String { failedProducerCalls += 1; throw originalError }
        var caught: ProducerError?
        do {
            trace.event(.toolCall, source: .toolRuntime) { .init(label: "syntheticFailure.start") }
            _ = try fail()
        } catch {
            caught = error as? ProducerError
            trace.event(.unavailable, source: .toolRuntime) { .init(label: "syntheticFailure.unchanged") }
        }
        check(caught === originalError && failedProducerCalls == 1, "helper leaves synthetic producer error identity and invocation count unchanged")

        let plan = try ContextWindowPolicy.makePrompt(latest: "A synthetic question", instructions: "Use only supplied synthetic values.",
            mandatoryFields: [.init("profileSource", ["synthetic"])], fields: [.init("historicalSource", ["synthetic prior input"])], reduced: false)
        trace.prompt(plan, instructions: "Use only supplied synthetic values.", scope: "harness")
        let unboundTrace = DebugNativeSessionTrace(recorder: recorder)!
        unboundTrace.event(.outputGate, source: .outputGate) { .init(text: "Unbound synthetic output", label: "harness.unbound") }
        trace.event(.modelResponse) { .init(text: String(repeating: "x", count: 10000), label: "harness.bounded") }
        trace.finish()
        recorder.drainForTesting()
        let records = try read(enabledDirectory)
        func labelled(_ label: String) -> [String: Any] {
            records.first { ($0["label"] as? [String: Any])?["value"] as? String == label }!
        }
        let returned = labelled("syntheticTool.returnedExistingString")
        let binding = returned["correlation"] as! [String: Any]
        check(binding["request"] as? String == request.uuidString && binding["utterance"] as? String == utterance.uuidString && binding["toolCall"] as? String == "unbound", "actual recorded request and utterance stay explicit; unavailable SDK tool ID stays unbound")
        check((returned["text"] as? [String: Any])?["value"] as? String == original, "actual file retains exact bounded returned output")
        let promptRecord = labelled("harness.actualPrompt")
        check((promptRecord["text"] as? [String: Any])?["value"] as? String == plan.prompt, "actual helper logs actual Core-produced prompt unchanged")
        let contextKeys = labelled("harness.includedContextKeys; underlyingRecordIDs=unbound")
        check((contextKeys["text"] as? [String: Any])?["value"] as? String == plan.context.keys.sorted().joined(separator: ","), "context source keys are real and original record IDs explicitly unbound")
        let unbound = labelled("harness.unbound")["correlation"] as! [String: Any]
        check(unbound["request"] as? String == "unbound", "nil request is not replaced with a current global request")
        let bounded = labelled("harness.bounded")["text"] as! [String: Any]
        check((bounded["value"] as? String)?.utf8.count == 8192 && bounded["truncated"] as? Bool == true, "native helper retains actual recorder text bound and visible truncation")
        check(records.last?["kind"] as? String == "sessionEnded", "helper clean finish drains actual recorded events")
        var afterFinishCalls = 0
        trace.event(.modelResponse) { afterFinishCalls += 1; return .init(text: "not after finish") }
        check(afterFinishCalls == 0, "finished recorder rejects helper without evaluating payload")

        let privacyDirectory = root.appendingPathComponent("privacy")
        let privacyRecorder = DebugSessionLog(directory: privacyDirectory, enabled: true)
        let privacyTrace = DebugNativeSessionTrace(recorder: privacyRecorder, requestID: request)!
        privacyTrace.event(.userInput) { .init(text: "Synthetic private test value") }
        privacyRecorder.drainForTesting()
        let done = DispatchSemaphore(value: 0)
        let receipt = Receipt()
        privacyRecorder.purge { success in receipt.set(success); done.signal() }
        var afterPurgeCalls = 0
        privacyTrace.event(.modelResponse) { afterPurgeCalls += 1; return .init(text: "late synthetic value") }
        check(done.wait(timeout: .now() + 3) == .success && receipt.get() == true, "actual privacy clear returns successful developer receipt")
        let freshHelperSameRecorder = DebugNativeSessionTrace(recorder: privacyRecorder, requestID: UUID())!
        freshHelperSameRecorder.event(.toolResult) { afterPurgeCalls += 1; return .init(text: "must not restart") }
        privacyRecorder.drainForTesting()
        let retained = try FileManager.default.contentsOfDirectory(at: privacyDirectory, includingPropertiesForKeys: nil)
        check(afterPurgeCalls == 0 && retained.isEmpty, "old and newly constructed helpers cannot resurrect purged recorder")

        let failed = DebugSessionLog(directory: root.appendingPathComponent("writeFailure"), enabled: true) { _, _ in throw Failure.write }
        let failedTrace = DebugNativeSessionTrace(recorder: failed, requestID: request)!
        failed.drainForTesting()
        var failedPayloadCalls = 0
        failedTrace.event(.modelResponse) { failedPayloadCalls += 1; return .init(text: "not serialized") }
        check(failed.snapshot().writeErrors == 1 && failedPayloadCalls == 0, "actual write failure remains observable and helper stops evaluating payload")
        DebugNativeSessionTrace.reportPurgeResult(false)
        DebugNativeSessionTrace.reportPurgeResult(true)
        DebugNativeSessionTrace.drainDeveloperReportsForTesting()
        check(true, "developer failure reporting callable without UIKit or visible model state")
        print("RESULT \(passed)/\(passed) helper assertions passed; no Apple callback execution claimed")
    }
    final class Receipt: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Bool?
        func set(_ value: Bool) { lock.lock(); self.value = value; lock.unlock() }
        func get() -> Bool? { lock.lock(); defer { lock.unlock() }; return value }
    }
}
