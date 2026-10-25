#!/usr/bin/env python3
"""Bounded public-source Core diagnostics; never alter the test exit status."""
import collections
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
if not path.is_file():
    print('CORE_DIAGNOSTIC log=unavailable runtime_result=unknown')
    raise SystemExit(0)
pattern = re.compile(r'recorded an issue|error:|fatal|failed|Test run with|Executed .*tests', re.I)
matches = []
matched = 0
tail = collections.deque(maxlen=60)
lines = 0
truncated_lines = 0
with path.open(errors='replace') as stream:
    for raw in stream:
        lines += 1
        # Raw evidence remains runner-local; published excerpt redacts local paths.
        line = re.sub(r'/(?:Users|private|var|tmp|home|workspace)/[^\s:]*', '<local-path>', raw.rstrip())
        is_match = pattern.search(line) is not None
        truncated_lines += len(line) > 1200
        line = line[:1200]
        tail.append((lines, line))
        if is_match:
            matched += 1
            if len(matches) < 120:
                matches.append((lines, line))
print(f'CORE_DIAGNOSTIC_BEGIN lines={lines} matching={matched} omitted_matches={matched-len(matches)} truncated_lines={truncated_lines} paths=redacted raw=runner-local')
for number, line in matches:
    print(f'issue line={number} {line}')
print(f'CORE_DIAGNOSTIC_TAIL_BEGIN last=60 omitted_prior_lines={max(0, lines-60)}')
for number, line in tail:
    print(f'tail line={number} {line}')
print('CORE_DIAGNOSTIC_END')
