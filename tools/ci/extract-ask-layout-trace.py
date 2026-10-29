#!/usr/bin/env python3
"""Bounded synthetic metadata only; no UI outcome inference or arbitrary text."""
import math
import re
import sys

number = r"-?[0-9]+(?:\.[0-9]+)?"
record = re.compile(
    r"ASK_LAYOUT_TRACE schema=1 sequence=([1-9]|[1-5][0-9]|6[0-4]) uptime=("+number+r") "
    r"event=(appear|disappear|category|geometry) role=(reason|ask-form) "
    r"category=(xSmall|small|medium|large|xLarge|xxLarge|xxxLarge|accessibility[1-5]) "
    r"frame=\(\(("+number+r"), ("+number+r")\), \(("+number+r"), ("+number+r")\)\) "
    r"provenance=app_callback_not_audit_failure_state"
)
marker = b"ASK_LAYOUT_TRACE truncated=true limit=64"
limit = 8 * 1024 * 1024
seen = rejected = dropped = consumed = 0
marker_seen = oversize = False
print("ASK_LAYOUT_TRACE_BEGIN max_records=64 max_bytes=8388608")
with open(sys.argv[1], "rb") as stream:
    while consumed < limit:
        raw = stream.readline(min(2049, limit - consumed))
        if not raw:
            break
        consumed += len(raw)
        ends = raw.endswith(b"\n")
        if oversize or len(raw) > 2048 or not ends:
            if not oversize and raw.startswith(b"ASK_LAYOUT_TRACE "):
                rejected += 1
            oversize = not ends
            continue
        line = raw.rstrip(b"\r\n")
        if line == marker:
            if not marker_seen:
                print(marker.decode())
                marker_seen = True
            continue
        match = record.fullmatch(line.decode("ascii", errors="replace"))
        valid = False
        if match:
            uptime, x, y, width, height = (float(match.group(i)) for i in (2,6,7,8,9))
            valid = (all(math.isfinite(v) for v in (uptime,x,y,width,height))
                     and 0 <= uptime <= 1e9 and abs(x) <= 1e6 and abs(y) <= 1e6
                     and 0 <= width <= 1e6 and 0 <= height <= 1e6)
        if valid:
            if seen < 64:
                print(line.decode())
                seen += 1
            else:
                dropped += 1
        elif line.startswith(b"ASK_LAYOUT_TRACE "):
            rejected += 1
budget = consumed >= limit
incomplete = budget or marker_seen or dropped > 0
status = "unavailable" if seen == 0 else ("partial" if incomplete or rejected else "observed")
print(f"ASK_LAYOUT_TRACE_END records={seen} rejected_prefix_records={rejected} dropped_valid_records={dropped} scan_budget_reached={str(budget).lower()} status={status} ui_outcome=not_inferred native_format=unverified")
