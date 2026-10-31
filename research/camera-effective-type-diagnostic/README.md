# Proposed app-effective Dynamic Type trace — category only

Prepared 2026-10-27. **Not published or native-built/run.** Execute only after review, on the existing review branch. No fonts, text, size limits, audit decisions, assertions, retries or timeouts are repaired/relaxed here.

## Question and known evidence

Run 40545204758 attempt 2 on `fb879d235f38a3f0121b69b023e8ee14c0ded61c` had matched Large camera geometry, but both scopes failed Dynamic Type: full audit named Practice header, typed-only named start-simulation. Four PNGs show unchanged Large before/callback state. Existing category output comes from the XCTest runner, not app SwiftUI. No app/test forced-category override was found. This experiment measures app-effective categories during the actual audit; it does not assume a font defect, frozen category, or SDK false positive.

## Implementation

- `instrument.py` requires four SHA-256-pinned files from the exact failing source. All checks and unique anchors validate before writes. It operates only on a separate disposable checkout, never the shared app files.
- Adds category-observing `ViewModifier`s at the existing header/button/footer. Reads **both** `@Environment(\.dynamicTypeSize)` and `@Environment(\.sizeCategory)`; emits appearance and change events. The modifier returns existing content with observation callbacks, without an overlay, GeometryReader, background, new view/AX content, size/trait setting, font change, identifier or accessibility override.
- Geometry is deliberately **not** instrumented: additional layout probes could affect measurement. Existing XCUI before/callback frames remain available but are not historical audit-transition geometry. SwiftUI observer modifiers still change view structure/dependencies and synchronous bounded file writes can affect timing. This is minimally scoped diagnostic instrumentation, **not a proof of zero observer effect**.
- Only when both `--ui-testing` and new `--audit-effective-type` launch arguments are present, writes app tmp `blind-effective-type-synthetic.jsonl`. Stable category tags, fixed roles/events, monotonic uptime, sequence and launch UUID only. No content, hierarchy, paths, environment, sensor data, images or identifiers from users. At most 128 observations plus explicit overflow row (129 total, each <=1 KiB); first row replaces old file.
- Exact UI-test launch setup gains only the diagnostic flag. Existing audit helpers gain uptime markers immediately before audit and on issue callback; all assertions, original scopes, contrast exception, callback return decisions and continueAfterFailure remain intact. Failed XCTest may not execute its existing defer/after-capture; that remains a failure.
- Reuses original one-build/two-selector runner with unchanged 600/300/120-second budgets, owned simulator cleanup and full-audit failure retention. After each invocation (including failure), `simctl get_app_container` locates only the owned simulator's app data. Copies only the fixed synthetic trace via strict parser, never a container/hierarchy dump. Collector enforces exact, separate dynamic/legacy category allowlists, 1 KiB per row including newline and the 129 KiB total cap. Arbitrary values are rejected; the fixed `unknown` sentinel is retained as partial evidence and fails. Collector also rejects stale, missing, oversize, symlink, malformed, mixed-launch, incomplete or overflow records. Partial/overflow parsed records are retained but still fail the run.
- Additional collector lookup is capped at 30 seconds inside the original 40-minute runner deadline. Trace outputs add at most two bounded JSON files; existing screenshot bounds remain unchanged. Provenance reports source and transformed hashes. No actual xcresult bundles or app containers are uploaded.

## Review / execution

`workflow-proposal.yml` remains here, not `.github/workflows`. It permits manual dispatch and pushes only to `codex/recovery-hazard-order-20261027` touching `.github/workflows/camera-effective-type-diagnostic.yml` or `research/camera-effective-type-diagnostic/**`; the job independently guards the same public repository/review branch and has read-only repository permissions. No master or other source path triggers it. Root owns activation at that exact workflow path. First checkout obtains diagnostic tools; second is an exact pinned source under `pinned-camera-source`. The dedicated run wrapper refuses any other destination or dirty/wrong-commit checkout. No third-party dependency or new project file is needed. Source pins must be deliberately refreshed/reviewed to measure a different revision; do not loosen mismatch failure.

Portable check command (copies four files to a temporary directory, never executes native runner):

```sh
python3 research/camera-effective-type-diagnostic/verify.py
```

For CI it receives the second pinned checkout as argument. Local result: **55 portable synthetic checks passed**, covering exact transformations, unchanged tests/fonts, runner Python compilation and collector failures. Swift/SwiftUI native compilation, callback delivery, app tmp retrieval and actual audit traces remain **unverified**. Root should review before copying/publishing the proposed workflow or authorizing remote execution.

## Interpretation and stopping rule

One bounded instrumented pair, no retries. Preserve both native outcomes regardless of trace quality. Correlate app monotonic timestamps to `ACCESSIBILITY_AUDIT_EFFECTIVE_BEGIN` and `ACCESSIBILITY_AUDIT_EFFECTIVE_ISSUE` markers, and inspect each role's category sequence. Report whether both categories transition, disagree, or stay constant. The callbacks are not atomic and may coalesce; absence of emitted changes is not proof that the audit never adjusted native text traits. Unknown category tags require investigation, not a green result.

A trace with all three roles is **collected evidence**, not passing Dynamic Type or whole-app acceptance. A change in audit outcome under instrumentation is an observer-effect lead, not a repair. If categories change while failure persists, category pinning is not established; next isolate actual layout/transition behavior with a separately reviewed probe. If they remain fixed, verify observation delivery and compare the same read-only probe in the isolated host before attributing cause. No production repair is justified solely by this prepared diagnostic.

## Reviewer hardening — 2026-10-27

Exact category allowlists and per-row byte enforcement added before activation. New portable fixtures cover every supported category, each unknown sentinel retained-but-failed, arbitrary alphanumeric categories, cross-family category rejection, 1025-byte rejection and exact 1024-byte acceptance. All 55 portable checks pass. Narrow push-trigger proposal awaits reviewer confirmation; no remote execution or publication by this task.
