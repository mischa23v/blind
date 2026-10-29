# Isolated diagnostics proposal — not applied

`diagnostics-only.patch` changes four existing files and adds one extractor (five paths total): DEBUG receipt sampling/storage, two synthetic receipt consumers, the existing CI logger, and a bounded metadata-only Ask trace extractor. No app runtime policy, UI font/layout, deadline, QoS, default, assertion or caller activation changes.

## Timing semantics

Capture wall time immediately before the optional CPU sample, before the diagnostic owner lock. Capture lock-request/acquisition times separately and store the wait in microseconds. Consumers emit a separate bounded `CLASSIFICATION_DIAGNOSTIC_LOCK` summary, so the existing CPU receipt grammar does not silently change. Sampling and lock-wait instrumentation are DEBUG-only and explicit synthetic opt-in. No clocks or storage are added to release builds.

Cross-thread stage append order can differ from pre-lock event timestamp order. Existing consumers already reject reversed wall intervals; do not sort or reinterpret invalid pairs as valid. A max lock-wait summary is an observation, not attribution of all native delay to the lock. Wall and CPU sampling are adjacent, not atomic; the lock acquisition timestamp includes tiny instrumentation overhead.

## Ask preservation

Existing UI-mode raw log is scanned on success and failure. Only exact known roles (`reason`, `ask-form`), events, Dynamic Type categories, numeric CGRect formatting and fixed provenance can pass. No arbitrary labels, paths, errors or model text. At most 64 records plus one producer truncation marker; at most 8 MiB scanned; oversized lines are discarded without retaining their contents. Scan-budget exhaustion is explicit, not a claim of complete absence. Exact CGRect/category spelling must be checked against real retained raw logs when available; unsupported format is safely omitted. This does not create historical callback evidence or guarantee app stdout reaches the raw xcodebuild log.

## Review and verification before application

- `git apply --check` passed against the recovered checkout; **patch is not applied**.
- Source-hash manifest records pre/post images; root integration owner must recheck preimages for concurrent changes.
- Native compile and all tests remain **not run**.
- Prepare bounded extractor fixtures: each accepted category/event/role; negative controls for arbitrary role, extra fields, signed path, NaN/inf, oversized lines, >64 records, repeated truncation and scan-budget exhaustion. Verify no raw unapproved bytes escape.
- Check all DEBUG `DiagnosticStageReceipt` initializers and consumers before application; added property affects API shape only in DEBUG.
- Verify success/failure logger paths preserve the original command status even if extractor fails.
- Verify source-only timing checks require both samples outside lock and independently sampled lock wait.
- No native rerun, installs, spending or publication is authorized by this proposal.

## Portable fixtures staged for independent review

`test_proposal.py` materializes only hash-verified preimages in a temporary directory, applies the patch there, verifies postimage hashes, and checks closed grammar, private-text rejection, oversize/unterminated/non-ASCII records, input/output budgets, original end-anchored CPU receipt compatibility, DEBUG source boundaries and pre-lock sample order. A synthetic shell-only logger harness checks original UI command exit statuses 0 and 7 with both working and deliberately failing extractor. It invokes no native commands. Unknown native formats produce no accepted record and are not called passing evidence. The active checkout patch remains unapplied. These fixtures are staged, **not executed** in this handoff.

### Semantic tightening

The staged parser now requires finite uptime in [0, 1e9], signed coordinates with magnitude <= 1e6, and dimensions in [0, 1e6]. Matching-prefix malformed/unknown records are counted as rejected without echoing contents. More than 64 valid records increments a dropped counter and reports partial status; a producer truncation marker or scan-budget exhaustion also reports incomplete observation. Zero accepted records explicitly reports unavailable. Footer always says `ui_outcome=not_inferred native_format=unverified`; observed metadata is not a native test pass. New lock metadata allows 1–15 decimal digits only (0 through 999999999999999 microseconds); larger/unrecognized records cannot pass the filter. The old end-anchored CPU print/grep grammar is unchanged. Fixtures cover these added limits and metadata.

### Root-owned portable execution

Root executed the exact hash-bound proposal fixtures: all 7 passed in 2.330 seconds, exit 0, under 20-second wall / 15-second CPU / 512 MiB virtual-memory limits. `PORTABLE_RESULT.json` binds the patch, tests and source manifest to the checked evidence. This supersedes only the earlier not-executed portable-fixture status; Swift/native execution and real Ask format remain unverified. Active integration remains unapplied.
