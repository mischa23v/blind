from pathlib import Path
import sys
root=Path(__file__).resolve().parent
s=(root/'ConnectedJourneyRuntimeTests.swift').read_text()
method=s[s.index('    private func untilPublication('):s.index('    private func installed(')].replace('    private func untilPublication(', '    func untilPublication(',1)
prefix='''import Foundation
@MainActor enum FailureSink { static var failures = 0 }
@MainActor func XCTFail(_ message: String, file: StaticString, line: UInt) { FailureSink.failures += 1 }
func runtimeTaskContext() -> String { "taskPriority=\\(Task.currentPriority.rawValue) hasTask=\\(withUnsafeCurrentTask { $0 != nil })" }
@MainActor final class RuntimeTraceBuffer { func record(_ value: String) {} }
@MainActor final class ConnectedJourneyRuntime {
    var ready = false
    var installations = 0
    var onFirstInstall: (() -> Void)?
    var onChange: (() -> Void)? { didSet {
        installations += 1
        if installations == 2 { onFirstInstall?() }
    } }
    var loading = false; var pendingMapWorkCount = 0; var pendingWriteCount = 0
    var storageError = false; var status = "synthetic"
}
@MainActor final class Harness {
    enum WaitError: Error { case timedOut }
    let traceBuffer = RuntimeTraceBuffer(); let name = "synthetic"
'''
suffix='''}
@main struct IntegrationWitness {
    @MainActor static func main() async throws {
        // Synchronous publication while observer is installed, before continuation installation.
        let runtime = ConnectedJourneyRuntime(); let harness = Harness()
        var previousCalls = 0
        runtime.onChange = { previousCalls += 1 }
        runtime.onFirstInstall = { runtime.ready = true; runtime.onChange?() }
        try await harness.untilPublication(runtime, file: #filePath, line: #line) { runtime.ready }
        precondition(previousCalls == 1 && runtime.installations == 3)
        runtime.onChange?(); precondition(previousCalls == 2)
        // Already-cancelled parent task: no continuation leak, observer restored.
        let cancelledRuntime = ConnectedJourneyRuntime(); cancelledRuntime.onChange = {}
        let task = Task { @MainActor in
            try await harness.untilPublication(cancelledRuntime, file: #filePath, line: #line) { false }
        }
        task.cancel()
        do { try await task.value; preconditionFailure("Cancellation accepted as success") }
        catch is CancellationError {}
        precondition(cancelledRuntime.installations == 3)
        // Real monotonic three-second bound; no fake-clock runtime acceptance.
        let timed = ConnectedJourneyRuntime(); timed.onChange = {}
        let clock = ContinuousClock(); let start = clock.now
        do {
            try await harness.untilPublication(timed, file: #filePath, line: #line) { false }
            preconditionFailure("Missing timeout")
        } catch Harness.WaitError.timedOut {}
        precondition(clock.now >= start.advanced(by: .seconds(3)))
        precondition(timed.installations == 3 && FailureSink.failures == 1)
        print("PASS actual extracted waiter: synchronous preinstall publication, cancelled parent, real3s timeout, observer restoration")
    }
}
'''
Path(sys.argv[1]).write_text(prefix+method+suffix)
