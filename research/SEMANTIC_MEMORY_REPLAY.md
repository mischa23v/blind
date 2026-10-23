# Grounded memory and context replay

2026-10-23. This is a portable adapter regression, **not** a language-model evaluation, perception benchmark, native iPhone result, live localization test or child-use approval.

## What runs

`SemanticMemoryReplayTests.swift` calls the actual `CompanionMemoryRetrieval.read`, `ObservedObjectMemory`, `ItemMemory`, `CompanionToolRuntime`, `CompanionModelContext` and `ContextWindowPolicy` implementations. Sixteen test methods cover:

- Authored furnished-house inventory with English, Arabic-framed and mixed queries; original Arabic saved-item normalization separately.
- Exact source, known versus unknown time, original negation, last-seen wording, updated saved items and stale/restarted observations.
- Same-named rooms in different places, floors, room identities or coordinate frames; labels and generic detections do not establish ownership, personal identity or object counts.
- Authored-map room inventory without exporting map coordinates, live pose, routes or clearance.
- Actual tool byte-budget sanitization and full/reduced context construction. Profile identity/current goal survive role-play names, optional-history collisions and overflow reduction; complete records survive or are dropped whole.

The only production change is alternative-location detection in `CompanionMemoryRetrieval`: it now compares place/floor/room IDs **and coordinate-frame IDs**, not display labels alone. Distinct scopes retain the existing warning; no coordinates or new physical authority are added. Repeated observations within one scope do not imply more items or more locations.

## Sources and adaptation

`tools/generate-semantic-memory-replay.mjs` imports the existing `tools/fixtures/home-awareness.mjs` and extracts four original scenarios (`enter`, `bedroom`, `bathroom-arrival`, `goal-change`), comprising 13 entity records. It preserves the original categories, descriptions, IDs, hierarchy and goals. The generated Swift fixture is readable source data, not desired assistant prose. Run without `--write` to detect source/fixture drift. It also hashes the underlying `maps/center.example.json` and existing OAS package.

The existing bundled `oas-apartment.blindplace.json` fixture is the pinned [Autodesk OAS apartment example](https://github.com/autodesk-platform-services/open-architecture-standards-2d-floor-plans/blob/e54861c1099964607efd86b07e858f309e3fe45f/svg-viewer/examples/apartment_50m2.json), Apache-2.0, already adapted by this repository. Its source attribution/license remains in the existing package. Its actual floor, address, current pose and live alignment are unknown. No furniture is invented in this map. `CompanionPlaceMemory` currently has no source/provenance/floor/frame fields and emits the generic private-inventory source label; this test exercises the saved-place adapter shape, not a complete community-map import or provenance-retention pipeline.

Category fixtures enter `ObservedObjectMemory.observe` through the same typed inputs as the production adapter. This **simulates** a producer; it does not execute a detector. Original authored descriptions, when used, remain separately attributed historical records. Explicit saved-item and correction mutation cases are clearly synthetic user-record inputs, not observations. Neither furniture captions nor person names become detector identities.

Fixture SHA-256:

- Home scenario source: `10cddccd1993dda139a6b008bb06dbe8094ec8d50a6dcc9118261d59c2830474`
- Authored topology: `a111585b2bdb6d2bb8a8f6d63ac75fbb70124a4ea3c2eb105dd963d3d5c24723`
- Existing OAS adapter: `b4ab1db3f38135695720df6ecb17581b972ecedcaa547c64fc5c3950288ac2d3`

## Optional recorded annotation replay

`tools/replay-semantic-memory-ca1m.mjs --sequence /external/path/to/42898570 --swift /path/to/swift --scratch-path /external/build` replays the separately licensed, already available CA-1M validation annotation subset. It makes no network/cloud/model calls and downloads nothing. The source must match SHA-256 `286e7c8268ca6de5be7564ee9d4afc977f729c7500d2aa755db65e62b31f8a9c`: 99 objects, 43 named objects and 33 named categories. It checks one actual recorded 4x4 pose matrix and reports its hash, but does not turn that pose into live alignment authority.

The runner injects original annotation categories, source-object IDs and positions into the production category-memory adapter, then compares retrieval against each original named category under three phrasings (99 query checks). Dates use a declared test clock, not an invented capture wall time. The `onDeviceDetector` enum represents the adapter input being exercised, **not evidence that a detector recognized these objects**. Context construction consumes the resulting production evidence. A match demonstrates retrieval of supplied labels only, not image recognition or geometric correctness.

Raw annotations, derived restricted input, captions and poses are never added to this repository. A private temporary input is deleted after execution; only hashes, counts and test summaries are printed. The normal 16-test run exercises authored input; the optional external branch runs only when this runner supplies `BLIND_SEMANTIC_REPLAY_INPUT`. Do not count a normal run as CA-1M execution. Existing dataset access/license restrictions still apply; this runner grants no redistribution rights.

## Measured limits, not hidden successes

Retrieval is lexical, not a semantic embedding model. `aquarium` can match English/Arabic question framing containing that exact label; `fish tank`, Arabic `حوض الأسماك`, plurals and unrelated strings do not silently become it. `حقيبة` is matched through existing Arabic normalization, not translated to `backpack`. A generic `furniture` caption mentioning a sofa does not create a `sofa` detector record. Full semantic paraphrase/cross-language recall remains unimplemented.

Inventory is bounded to at most four evidence records, 800 evidence scalars and the runtime's stricter JSON byte budget. It is partial, not a complete household inventory. Reduced retry may omit all retrieved evidence but must preserve the mandatory profile/task and never remove a temporal qualifier from a retained record. These tests do not establish the actual Apple tokenizer fit, model obedience, acoustic behavior, source recognition quality or physical safety.

## Verification

Completed portable execution on 2026-10-23:

- Authored fixture regeneration/drift check: passed, four scenarios / 13 source entities.
- Runner syntax check: passed.
- Focused `SemanticMemoryReplayTests`: **16/16 passed**, zero failures, in the coordinated serial Core run. This is only this suite's result, not a statement about unrelated suites in the same invocation.
- Optional recorded annotation replay: **1/1 passed**, with **99/99 category-query checks**, 99 original objects / 43 named / 33 named categories. Actual recorded-pose file hash: `7c961aa1d795118315cfd0375fdc730e0abe3e0217e2961f95fe33413e37ef2b`. Combined command-output receipt SHA-256: `9a33db05803e091718876b098754d3b6920614fee01633f57f0e5dba785fd0b2`.

Swift 6.4.1 on Linux used the existing shared package build, one compiler job for the optional replay. No installs, downloads, model calls, raw-data commits or Apple/device execution occurred. The optional command completed and removed its temporary input. Native Apple/model behavior and physical grounding remain pending.
