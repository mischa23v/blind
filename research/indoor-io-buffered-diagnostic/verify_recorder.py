#!/usr/bin/env python3
"""Static Swift source contracts plus explicitly non-Swift recorder reference-model checks."""
import json
from recorder import LOGGER

emit = LOGGER.split('    static func emit(', 1)[1].split('    static func flushAfterWait()', 1)[0]
flush = LOGGER.split('    static func flushAfterWait()', 1)[1]
assert LOGGER.count('print(') == 3 and flush.count('print(') == 3
assert not any(term in emit for term in ('print(', 'FileHandle', 'write(', 'append(', 'sorted(', 'uuidString'))
assert 'private static let capacity = 256' in LOGGER
assert '[Event?](repeating: nil, count: capacity)' in LOGGER
assert emit.index('let captured =') < emit.index('lock.lock()')
assert emit.index('guard !closed') < emit.index('guard count < capacity') < emit.index('events[count] =') < emit.index('count += 1')
assert 'if dropped < Int.max { dropped += 1 }' in emit
assert flush.index('closed = true') < flush.index('let snapshot = events') < flush.index('lock.unlock()\n        // Snapshot') < flush.index('print(')
assert 'guard !closed else { lock.unlock(); return }' in flush
assert '$0.uptime == $1.uptime ? $0.sequence < $1.sequence : $0.uptime < $1.uptime' in flush
assert 'late_events=censored missing_events=inconclusive' in flush
assert 'file.open.end' not in LOGGER  # recorder has no fabricated operation outcomes

class ReferenceRecorder:
    """Executable desired semantics, not proof of the Swift implementation."""
    def __init__(self):
        self.events = [None] * 256
        self.count = self.dropped = 0
        self.closed = False
    def emit(self, timestamp):
        if self.closed:
            return
        if self.count == 256:
            self.dropped += 1
            return
        self.events[self.count] = (timestamp, self.count + 1)
        self.count += 1
    def flush(self):
        if self.closed:
            return None
        self.closed = True
        return sorted(e for e in self.events if e is not None), self.dropped

r = ReferenceRecorder()
for t in [3, 1, 1, 2] + list(range(252)):
    r.emit(t)
r.emit(-1)
assert r.count == 256 and r.dropped == 1 and len(r.events) == 256
snapshot, dropped = r.flush()
assert len(snapshot) == 256 and dropped == 1
assert snapshot == sorted(snapshot)
assert snapshot.index((1, 2)) < snapshot.index((1, 3))
r.emit(-2)
assert r.flush() is None and r.count == 256 and r.dropped == 1
assert ReferenceRecorder().flush() == ([], 0)
print(json.dumps({'swift_source_contracts': 'passed', 'reference_model_cap_order_close_flush': 'passed',
                  'swift_compilation_concurrency_runtime': 'not_run',
                  'limit': 'Reference model does not execute the Swift recorder.'}, indent=2))
