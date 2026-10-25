#!/usr/bin/env python3
"""Bounded synthetic XCTest phase evidence; never dumps a complete runner log."""
from collections import deque
import re
import sys

PHASE_LIMIT = 400
FAILURE_LIMIT = 3
LINE_LIMIT = 4096
START = re.compile(r"Test Case .*ConnectedJourneyRuntimeTests.* started\.")
END = re.compile(r"Test Case .*ConnectedJourneyRuntimeTests.* (passed|failed) \(")
PHASE = re.compile(r"NATIVE_RUNTIME_(?:IO|WAIT|PHASE) ")


def extract(lines, output):
    start = None
    phases = deque(maxlen=PHASE_LIMIT)
    phase_count = 0
    failed_wait = None
    emitted = 0
    omitted = 0

    def emit(end):
        nonlocal emitted, omitted
        if emitted == FAILURE_LIMIT:
            omitted += 1
            return
        emitted += 1
        output(f"NATIVE_RUNTIME_FAILURE_BEGIN index={emitted} retained={len(phases)} dropped={phase_count - len(phases)}")
        output(start)
        # Keep the exact timeout-return line even if later callbacks fill the ring.
        if failed_wait is not None and failed_wait not in phases:
            output(failed_wait)
        for line in phases:
            output(line)
        output(end)
        output("NATIVE_RUNTIME_FAILURE_END")

    for raw in lines:
        line = raw.rstrip("\r\n")
        if len(line) > LINE_LIMIT:
            line = line[:LINE_LIMIT] + " [line truncated]"
        if START.search(line):
            if start is not None and failed_wait is not None:
                emit("NATIVE_RUNTIME_TEST_END_MISSING")
            start = line
            phases.clear()
            phase_count = 0
            failed_wait = None
            continue
        if start is None:
            continue
        if PHASE.search(line):
            phases.append(line)
            phase_count += 1
            if "fulfilled=false" in line:
                failed_wait = line
        end = END.search(line)
        if end:
            if end.group(1) == "failed" or failed_wait is not None:
                emit(line)
            start = None
    if start is not None and failed_wait is not None:
        emit("NATIVE_RUNTIME_TEST_END_MISSING")
    output(f"NATIVE_RUNTIME_FAILURE_SUMMARY emitted={emitted} omitted={omitted} phase_limit={PHASE_LIMIT} failure_limit={FAILURE_LIMIT}")


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8", errors="replace") as log:
        extract(log, print)
