#!/usr/bin/env python3
"""Fail-closed, diagnostic-only instrumentation of an exact disposable checkout."""
from pathlib import Path

FILES = ['ios/BlindAssist/SpatialMapIO.swift', 'ios/BlindAssist/RegisteredIndoorNavigation.swift',
         'ios/BlindAssist/IndoorNavigator.swift', 'ios/BlindAssistTests/CommunityTests.swift']

from recorder import LOGGER

def instrument(root, arm="utility"):
    assert arm in ("utility", "userInitiated"), "Unknown predeclared arm"
    root = Path(root)
    originals = {p: (root / p).read_text() for p in FILES}
    texts = dict(originals)
    def change(path, old, new, count=1):
        assert texts[path].count(old) == count, f'Instrumentation anchor mismatch: {path}: {old[:90]}'
        texts[path] = texts[path].replace(old, new)
    io, reg, nav, test = FILES
    change(io, 'import BlindCore\n', 'import BlindCore\n' + LOGGER)
    change(io, '        let job = Job(token: token,', '        IndoorIOPhaseTrace.emit("submit", token.generation)\n        let job = Job(token: token,')
    change(io, '        if start { queue.async { self.drain() } }', '        IndoorIOPhaseTrace.emit(start ? "worker.enqueue" : "worker.already-running", token.generation)\n        if start { queue.async { self.drain() } }')
    change(io, '        DispatchQueue.main.async {\n            // Second CAS', '        IndoorIOPhaseTrace.emit("finish.enqueue", job.token.generation)\n        DispatchQueue.main.async {\n            IndoorIOPhaseTrace.emit("finish.main", job.token.generation)\n            // Second CAS')
    change(io, '        publishOnMain {\n', '        IndoorIOPhaseTrace.emit("publish.enqueue", job.token.generation)\n        publishOnMain {\n            IndoorIOPhaseTrace.emit("publish.main", job.token.generation)\n')
    change(io, '            self.queue.async {\n', '            IndoorIOPhaseTrace.emit("publish.callback-returned", job.token.generation)\n            self.queue.async {\n                IndoorIOPhaseTrace.emit("ack.worker", job.token.generation)\n')
    change(io, '        while let job = take() {\n', '        IndoorIOPhaseTrace.emit("drain.enter")\n        while let job = take() {\n            IndoorIOPhaseTrace.emit("job.taken", job.token.generation)\n')
    change(io, '                let candidate = try prepare(storage)', '                IndoorIOPhaseTrace.emit("prepare.begin", job.token.generation)\n                let candidate = try prepare(storage)\n                IndoorIOPhaseTrace.emit("prepare.end", job.token.generation)')
    change(io, '                    previous = try previousBytes()', '                    IndoorIOPhaseTrace.emit("previous-read.begin", job.token.generation)\n                    previous = try previousBytes()\n                    IndoorIOPhaseTrace.emit("previous-read.end", job.token.generation)')
    change(io, '                    do { try storage.write(bytes) }', '                    do {\n                        IndoorIOPhaseTrace.emit("write.begin", job.token.generation)\n                        try storage.write(bytes)\n                        IndoorIOPhaseTrace.emit("write.end", job.token.generation)\n                    }')
    change(io, '            } catch { finish(job, .failure(error)) }', '            } catch {\n                IndoorIOPhaseTrace.emit("job.error", job.token.generation)\n                finish(job, .failure(error))\n            }')
    change(reg, '    func restore(completion: @escaping Completion) {', '    func restore(completion: @escaping Completion) {\n        IndoorIOPhaseTrace.emit("restore.request")')
    change(reg, '    func install(_ data: Data, completion: @escaping Completion) {', '    func install(_ data: Data, completion: @escaping Completion) {\n        IndoorIOPhaseTrace.emit("install.request")')
    change(reg, '        io.submit(expected: expected, prepare: prepare) { [weak self] token, result in', '        io.submit(expected: expected, prepare: prepare) { [weak self] token, result in\n            IndoorIOPhaseTrace.emit("registered.callback", token.generation)')
    change(nav, '        start { [weak self] result in', '        IndoorIOPhaseTrace.emit("navigator.start", expected)\n        start { [weak self] result in\n            IndoorIOPhaseTrace.emit("navigator.callback", expected)')
    # Mark original helpers, keeping waits, assertions, result handling and test bodies intact.
    change(test, '        try action { result = $0; done.fulfill() }', '        IndoorIOPhaseTrace.emit("test.action.begin")\n        try action {\n            IndoorIOPhaseTrace.emit("test.completion")\n            result = $0; done.fulfill()\n        }\n        IndoorIOPhaseTrace.emit("test.wait.begin")', count=2)
    change(test, '        IndoorIOPhaseTrace.emit("test.wait.begin")\n        await fulfillment(of: [done], timeout: 10)\n        try XCTUnwrap(result).get()', '        IndoorIOPhaseTrace.emit("test.wait.begin")\n        await fulfillment(of: [done], timeout: 10)\n        IndoorIOPhaseTrace.emit("test.wait.end")\n        try XCTUnwrap(result).get()')
    change(test, '        IndoorIOPhaseTrace.emit("test.wait.begin")\n        wait(for: [done], timeout: 10); try XCTUnwrap(result).get()', '        IndoorIOPhaseTrace.emit("test.wait.begin")\n        wait(for: [done], timeout: 10); IndoorIOPhaseTrace.emit("test.wait.end"); try XCTUnwrap(result).get()')
    # Flush only after the original wait returns, before XCTUnwrap can throw.
    change(test, 'IndoorIOPhaseTrace.emit("test.wait.end"); try XCTUnwrap',
           'IndoorIOPhaseTrace.emit("test.wait.end"); IndoorIOPhaseTrace.flushAfterWait(); try XCTUnwrap')
    change(test, '        IndoorIOPhaseTrace.emit("test.wait.end")\n        try XCTUnwrap',
           '        IndoorIOPhaseTrace.emit("test.wait.end")\n        IndoorIOPhaseTrace.flushAfterWait()\n        try XCTUnwrap')
    from refine import refine
    refine(texts, FILES)
    if arm == "userInitiated":
        change(io, 'DispatchQueue(label: "BlindAssist.spatial-map-io", qos: .utility)',
               'DispatchQueue(label: "BlindAssist.spatial-map-io", qos: .userInitiated)')
    # Validate every anchor before touching any file.
    for path in FILES:
        assert texts[path] != originals[path]
    for path in FILES:
        (root / path).write_text(texts[path])
    return FILES
