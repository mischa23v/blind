# Review-branch real-camera audit comparison

Proposal only; root reviews and copies `review-camera-audit-comparison.yml` to `.github/workflows/review-camera-audit-comparison.yml` before publishing. No production/test/helper changes are proposed. Base reviewed: e9e18d15fe1fdac1ff1487b3c2a8a2e731607427.

## Why this experiment

Main run40463262075 on8d878c86 reported Camera StaticText Practice, Dynamic Type65536, frame(20,568.33,400,40.33). Downloaded callback artifact12716436511 corroborates this. Existing endpoint run40209239473/artifact12605995482 shows header height40.33→83.33 at Large→AXXXL and visibly untruncated enlarged text. The exact static modifiers also passed the isolated host's12 typed audits and3 endpoint cases (run40223169463). These observations do not support a font/fixedSize repair or prove an SDK false positive.

## Smallest adaptation

Reuse existing `tools/ci/camera-audit-scope-control.py` unchanged. Existing workflow push trigger covers master, not this review branch. Proposed additional workflow permits only `codex/recovery-hazard-order-20261027`, with an explicit matching job guard (including manual dispatch), and push path restricted to its own new workflow. Navigation commits do not automatically repeat this comparison. No changes to existing master workflows. Source-contract and synthetic orchestration checks precede native execution.

The harness creates one owned iPhone18 Pro Max/iOS27 simulator, boots and waits explicitly, performs one build-for-testing, then exactly these selectors once serially using test-without-building:
1. LaunchTests/testAccessibilityAuditOfCameraAndAsk (unchanged full audit; Ask only if Camera passes).
2. CameraAuditScopeTests/testCameraDynamicTypeOnly (diagnostic-only explicit opt-in).

Large is set and verified before each fresh launch. Required before-state category, readiness, window and Practice header/button/footer frames must match. Cleanup deletes only the owned UUID. No full suite, prewarming, retry, font alteration, ignored failure or broadened exemption.

## Budgets and evidence

Keep existing600-second build cap: recent2–3minute builds reported in the task handoff fit comfortably; this does not justify increasing the cap after the historical600-second timeout. Keep300seconds per selector,120seconds per export,40minute harness deadline and45minute workflow cap (including setup/cleanup). Timeout records sanitized build progress and process termination metrics, then stops native testing; no retry. Missing after/Ask evidence remains failed/partial, while the second independent selector is still attempted within deadline.

Retain existing artifact bounds:12 PNGs/24MiB combined, bounded metadata/outcomes, three-day retention. Original audit failure remains workflow failure even if typed audit passes. Interpret matched both-fail as reproduced without combined scope; matched full-only fail as a scope-interaction candidate, not proof; different findings or mismatched/missing geometry remain inconclusive. No result closes actual VoiceOver/device/user acceptance.

## Local verification

See orchestration-checks.log (synthetic subprocesses only) and source-contracts.log. These are not native compilation or audit acceptance. Root should inspect final logs before publication. Production and test source remain unchanged.

### Fixture race found during validation

Original Python fixture result: 10/11 passed; the timeout case sometimes terminates its synthetic Python process before the flushed SwiftCompile marker exists, leaving an empty log and failing the unchanged sanitizer-tail assertion. Preserve this failure in `orchestration-checks.log`.

`timeout-fixture-readiness.patch` proposes a test-only bounded five-second readiness handshake in the timeout shim before its existing 0.1-second forced timeout. Missing readiness still fails explicitly. It does not change native runner code, the 600-second assertion, signal assertions, sanitizer assertions or scenario count. Root must apply this separately to `tools/test/camera-audit-scope-control.test.py` before the workflow runs its orchestration step. Validation uses temporary copies, not shared-file edits; see `orchestration-readiness-patch-checks.log` for outcome.
