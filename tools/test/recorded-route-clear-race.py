#!/usr/bin/env python3
"""Execute actual native clear method with controllable storage boundaries, no ARKit claim."""
import pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1])
source = (root / 'ios/BlindAssist/NativeARObservationBridge.swift').read_text()
start = source.index('    func clearHistory(')
pos = source.index('{', start); depth = 1; end = pos + 1
while depth:
    if source[end] == '{': depth += 1
    elif source[end] == '}': depth -= 1
    end += 1
method = source[start:end].replace('MemoryStore', 'Int')
harness = '''import Foundation
final class Pipeline {
    enum Outcome { case cleared, failed }
    var session = "A", cleared: [String] = []
    var callback: ((Outcome) -> Void)?
    func clear(storage: Int, completion: @escaping (Outcome) -> Void) {
        cleared.append(session); callback = completion
    }
}
final class Trail {
    var callback: ((Bool) -> Void)?
    func clear(_ completion: @escaping (Bool) -> Void) { callback = completion }
}
final class Bridge {
    let pipeline = Pipeline(), recordedRoute = Trail()
    var memory: Int? = 1
    var lastOutcome: Pipeline.Outcome?
    func stop() {}
    static func storage(_ memory: Int) -> Int { memory }
''' + method + '''
}
let bridge = Bridge(); var completed = false
bridge.clearHistory(memory: 1) { success in precondition(success); completed = true }
precondition(bridge.pipeline.cleared == ["A"])
bridge.pipeline.session = "B"
bridge.recordedRoute.callback?(true)
precondition(bridge.pipeline.cleared == ["A"], "Old trail callback cleared new session B")
bridge.pipeline.callback?(.cleared)
let deadline = Date().addingTimeInterval(2)
while !completed && Date() < deadline { _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
precondition(completed)
print("PASS: actual native clear method fences both stores before delayed callbacks; new session B unchanged")
'''
out = pathlib.Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
(out/'clear-race.swift').write_text(harness)
subprocess.run(['swiftc', str(out/'clear-race.swift'), '-o', str(out/'clear-race')], check=True)
subprocess.run([str(out/'clear-race')], check=True)
