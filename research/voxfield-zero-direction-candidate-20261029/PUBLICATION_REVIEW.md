# Independent D1 publication review

2026-10-29 05:17 UTC. Source/receipt review only; no native rerun. All original packet hashes and the independent completed review's resource, integrity, ELF and client-log hashes were verified. Direct saved-log recount confirms 32 traces per arm: 28 strict and four observational. Original control has 17 mismatches; candidate matches all 28 strict and four observational traces. Observational cases remain separate. The independent reviewer verified 479 frozen inputs and separate original/candidate ELF closures.

Only the six exactly-zero guards and limits include change in the candidate. No nonzero arithmetic/epsilon policy, D2 native invalid-input/lifecycle handling, N1 threshold repair, room gain or physical-safety result is included. Allocated weight zero is not observed-free support. Original mismatches and the earlier incomplete gate remain evidence. No full upstream-suite pass is implied. This checkpoint excludes the separately completed NP continuation, which requires its own publication packet/review.

## Record chronology and sanitization

SOURCE_CONTRACT.json describes the initial proposal; its applied/built/executed false values are historical. APPLIED_COPY_RECEIPT.json and RESULT.json document subsequent execution. RESULT.md's request for final review is superseded by the included INDEPENDENT_COMPLETED_REVIEW.json. Only execute.py and ELF.json replace the ephemeral absolute workspace root with <WORKSPACE_ROOT>; PUBLICATION_REVIEW.json records both hashes. Binary/library hashes and results remain unchanged. ORIGINAL_PACKET_SHA256SUMS records original bytes, not sanitized copies. PUBLICATION_SHA256SUMS records published bytes.

## Reproduction constraints

Official source: https://github.com/v4rl-ucy/voxfield/tree/78ee6403720e0aed87f4720c04c813bb38a3b260 ; BSD-3-Clause licence included. Apply EXACT_ZERO_ONLY.patch to an isolated copy of that source, keeping the original library/control separate. Dependencies and original core build are not bundled; prior voxfield-build-gate-20261029 source pins describe the tested Linux x86-64 prefix layout. Third-party notices remain separate.

This is not a turnkey runner. execute.py is an environment-specific execution record; the placeholder, directory layout, original build, dependencies and EXECUTION_FREEZE.json must be supplied locally. The original local freeze is not bundled. Do not run it expecting these unpublished paths to exist after checkout. A new reproduction needs a separately reviewed local freeze and matching CMake source/build/dependency roots. Keep the one-worker CPU/wall/process-tree-memory/disk guard rather than invoking unbounded tests. These sources, synthetic expected lists, result logs and independent review permit inspection without binaries, whole upstream trees or real recordings.
