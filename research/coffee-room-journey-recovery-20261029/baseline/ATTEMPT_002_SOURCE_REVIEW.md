# Coffee attempt 002 — independent source-only repair review

**No remaining source-review blocker to a separately admitted attempt 002.** Attempt 001 remains a failed compile, with zero queries; see ATTEMPT_001_FAILURE_REVIEW.md. This reviewer has not run compiler, guard or query payload.

Reviewed frozen SHA-256:

- Guard: `0e509781d68232fac5229bed6caa08965ed606fa60e98d545c9205c6fe39034c`
- COFFEE_RUN_PINS.json: `65a764cc00f717c2cd6a5ce7a9ca9f27fa58d297f7c68a9547b3c21dcbe67bd6`
- AGGREGATE_GUARD.md: `233793dd1e5e90b94715d0ad824c8b567076e659b3e6fae35dfc5f149ab46621`

The missing `native025/blind_detour.h` is restored byte-for-byte from published commit `c79fbd33171f78608f9eb2a1484fbc9266e3a695`, path `research/tools/koivu-coffee-room-tests-v1/blind-split-candidate-game-03/body-margin-variants-07/native025/blind_detour.h`. Independent git-show SHA-256 equals staged header `c6270b968024d0703800160d45d4110f04f73ad3ecca50ceb0fd0de3b002dbb4`; this is not a replacement API/header from another adapter. Header has no additional custom includes.

Independent recursive quoted-include traversal from every compile translation unit through relative and frozen include directories now reaches 45 present files with **zero unresolved quoted includes**. The updated preparation additionally records static quoted-include resolution for all staged C++/header files in INCLUDE_CLOSURE.json. Neither check invokes the compiler/preprocessor or proves system-header compatibility.

All 70 manifest pins verify as regular matching files, covering all 60 files in the fresh `coffee-native-replay-prepared-002` owned root. The previous 58 prepared inputs remain byte-identical except BUILD_COMMAND.json (only new root paths) and PREPARED.json (new source metadata); additions are the exact header and closure record. Compiler flags/source order/output semantics are unchanged after root substitution; query source, OBJ, adapter, upstream code, protocol and expected results remain unchanged. No engine, query, margin or acceptance tuning occurred.

The only guard implementation diff from admitted attempt 001 is deterministic @PREPARED@ expansion to the explicit fresh `coffee-native-replay-prepared-002` root. The same aggregate caps, direct serial compile/query sequence, immutable input checks, new-library checks, fail-closed cleanup, exact historical core-result equality and observational limitations remain. No old binary/guard/query output existed in the fresh root at review.

Original failed attempt receipt remains byte-identical (`cb5bbbf5af144ebe4325ff67ab597786cb0cac3e3eaef0ce4a815b0fa7f585cc`); no failed evidence was overwritten. Root must publish the repaired source checkpoint and explicitly admit the new attempt. No automatic rerun is authorized by this review. Any eventual pass remains known-source-mesh query reproduction, not movement/physical clearance or live navigation.
