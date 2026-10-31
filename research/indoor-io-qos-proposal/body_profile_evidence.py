"""Bounded log capture and fail-closed XCTest coverage; never invokes Swift."""
import re

LOG_HALF = 512 * 1024
MAX_LINE = 64 * 1024


def required_names(source):
    names = re.findall(r'\bfunc\s+(test\w+)\s*\(', source)
    if not names or len(names) != len(set(names)):
        raise ValueError('Missing or duplicate required test declarations.')
    return names


class Evidence:
    def __init__(self, names):
        self.names = names
        self.events = {name: [] for name in names}
        self.errors = []
        self.head = bytearray()
        self.tail = bytearray()
        self.pending = bytearray()
        self.total = 0
        self.overflow = False

    def error(self, message):
        if len(self.errors) < 16:
            self.errors.append(message)

    def line(self, raw):
        line = raw.decode('utf-8', errors='replace')
        if not line.startswith('Test Case ') or 'BodyProfileStoreTests' not in line:
            return
        # Darwin XCTest and SwiftPM's equivalent dotted XCTest spelling only.
        match = re.fullmatch(
            r"Test Case '(?:-\[(?:\w+\.)?BodyProfileStoreTests (test\w+)\]|"
            r"(?:\w+\.)?BodyProfileStoreTests\.(test\w+))' "
            r"(started|passed|failed|skipped)(?: \([^\r\n]*\))?\.", line.strip())
        if not match:
            self.error('Unrecognized BodyProfileStoreTests case record.')
            return
        name = match[1] or match[2]
        if name not in self.events:
            self.error('Unexpected BodyProfileStoreTests test: ' + name)
        elif len(self.events[name]) >= 3:
            self.error('Repeated test events: ' + name)
        else:
            self.events[name].append(match[3])

    def feed(self, data):
        self.total += len(data)
        take = min(len(data), LOG_HALF - len(self.head))
        self.head.extend(data[:take])
        self.tail.extend(data[take:])
        if len(self.tail) > LOG_HALF:
            del self.tail[:-LOG_HALF]
        for segment in data.splitlines(keepends=True):
            if not self.overflow:
                self.pending.extend(segment)
                if len(self.pending) > MAX_LINE:
                    self.error('Overlong log line; coverage unavailable.')
                    self.pending.clear()
                    self.overflow = True
            if segment.endswith(b'\n'):
                if not self.overflow:
                    self.line(bytes(self.pending).rstrip(b'\r\n'))
                self.pending.clear()
                self.overflow = False

    def finish(self):
        if self.pending:
            self.line(bytes(self.pending))
            self.pending.clear()
        missing = {name: events for name, events in self.events.items()
                   if events != ['started', 'passed']}
        return {'verified': not self.errors and not missing,
                'required_names': self.names, 'events': self.events,
                'invalid_or_missing': missing, 'errors': self.errors,
                'log_bytes_seen': self.total,
                'log_truncated': self.total > 2 * LOG_HALF}

    def write_log(self, path):
        marker = b'\n[LOG TRUNCATED: bounded head/tail; coverage parsed from entire stream]\n'
        path.write_bytes(bytes(self.head) + (marker if self.total > 2 * LOG_HALF else b'') + bytes(self.tail))
