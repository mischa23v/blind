# Fixed real-Camera audit-scope control

The main full-app audit at d75ec3 identified the Practice header after Camera
readiness succeeded: Large category, frame `(20, 568.33, 400, 40.33)`, Dynamic Type
finding 65536. The independent focused run never executed its audit because the
runner failed during bootstrap. The earlier isolated host passed separate Dynamic
Type and hit-region audits, not the default full audit. These results do not yet
identify a production defect or establish an SDK false positive.

## One factor, two cases

Run exactly these selectors once, serially, after one build on one owned, explicitly
boot-ready iPhone 18 Pro Max / iOS 27 simulator:

1. Existing `LaunchTests/testAccessibilityAuditOfCameraAndAsk`: unchanged default
   full audit and original contrast exemption; compare only its Camera phase.
2. New `CameraAuditScopeTests/testCameraDynamicTypeOnly`: same synthetic launch,
   navigation, readiness, frame/screenshot collection and callback handling, but
   requesting `.dynamicType` instead of the default full audit.

The original file/callsite is not edited. Source contracts compare copied setup,
navigation and evidence helpers byte-for-byte, permitting only the explicit opt-in
skip gate, helper name and audit-type argument. The new class skips before launching
unless `BLIND_AUDIT_SCOPE_CONTROL=1` is passed to the test runner. That skip is not
acceptance evidence. Only its UI-test source entry is added to the existing project;
no app source, font, layout, model state or existing workflow changes.

Reset and verify Large before each fresh launch. Retain both native outcomes,
bounded issue/readiness/frame logs and named screenshots. The unchanged full test
may reach Ask if Camera passes, so the bounded evidence allowance is at most six
PNGs across both cases. Missing after-capture on a stopped failing XCTest remains
an explicit evidence failure, not a pass. No retries, timer changes, old layout
probes, or fifteen-case isolated comparison reruns. Cleanup targets only the created
UUID and cleanup failure fails the run.

## Limits and decision rule

Compare pre-audit Camera category/window/header/button/footer geometry. Missing or
different state makes the scope comparison inconclusive. If both report Practice
65536, a full-versus-Dynamic-Type scope interaction is not needed to reproduce it.
If only the full audit reports that same finding, scope interaction is a candidate,
not proof from one pair. If the full audit reports a different hit-region or other
finding, it does not establish the cause of the historical Dynamic Type failure.
A typed audit pass never clears the original full audit or blind-usability gates.

Native compilation/execution of this new opt-in class remains pending until CI.

Source baseline: commit `39b3296ee76ebe442a7b758fdf8d13429f69180a`, unchanged
LaunchTests blob `bb8284fcf3fda2e3501af14ee7d45e97dcc9c917`, project preimage
`c712105de2bf02176cb4b6b0b1ecee7de3f3de32`. Five source-contract checks pass,
including exact helper equivalence and UI-test-only project placement. Independent
source review accepted; no native outcome is claimed yet.

Eight synthetic runner checks also pass: one build/two selectors once, original
failure retained while the second case runs, partial evidence retained, build and
cleanup failures explicit, verified Large required, missing/mismatched geometry
inconclusive even when native tests pass, and wrong SDK rejected before creating a
simulator or building. These are orchestration fixtures, not native audit results.
