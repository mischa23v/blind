# Accessibility evidence follow-up — 2026-10-28

## Verdict

**No Dynamic Type production layout correction is established by the published evidence.** Text grew, then Practice content moved beyond the Form viewport and later role geometry was absent. This is not proof of a pinned font, unreachable footer, or an Apple false positive. Do not shrink fonts, suppress findings, or equate a source check with native accessibility success.

The concrete coverage defect is separate: `testAccessibilityAuditOfCameraAndAsk` fails at Camera with `continueAfterFailure=false`, preventing Ask execution. Run 40598054378 exports camera-before and camera-issue-1, no camera-after, and Ask not observed. Missing after evidence must remain missing; a `defer` is not a guarantee XCTest can produce it after failure.

## Exact isolated proposal

`fresh-ask-proposal.patch` is **not applied**. It changes only LaunchTests.swift and the bounded attachment exporter, never workflow definitions or native shell selectors. It adds `BlindAssistUITests/LaunchTests/testAccessibilityAuditOfAskIndependently`, using existing full-app synthetic setup and direct Settings → Ask navigation. It invokes the unchanged default-all audit helper with namespace `askfresh`; Camera findings and original combined test are untouched. Fresh-app Ask neither changes content-size category nor executes the blocked cold Large/AX5 Practice endpoint control.

Distinct attachment names prevent collision if the combined test later reaches Ask. The CLI export requires both Camera and independent-Ask before/after evidence. Legacy combined Ask remains optional unless any of its roles appear. Missing, partial, duplicate, corrupt or oversized evidence stays incomplete. `nativeAuditOutcome` remains `not_inferred_from_attachments`. Even complete before/after attachments are **not** a passing audit: read the exact case status and all issue logs from the native result bundle. A suite timeout or absent test status is **unknown/not completed**, not a pass. The existing diagnostic-only selector does not include this new case; this proposal is for the existing full UI suite, not an alternate endpoint route.

## Budget and activation review

No native execution is authorized or performed by this document. Parent review/application/push is separate. The existing full UI job retains its 20-minute wall bound, single destination, no retries. Additional cost is one app launch plus one full Ask audit and bounded captures; duration has **not** been measured. If Camera later passes, Ask is audited twice by different cases, so this has a real redundancy/runtime cost. Do not claim no lag or extend the time bound automatically. On a bounded run, report each exact case's terminal status and elapsed time; if the new case is not reached or the suite times out, coverage remains open.

Exporter retains the existing 90-second export timeout and global 16 MiB authored screenshot limit; issue metadata remains 16 KiB each and result JSON 16 KiB. Maximum authored images rises from 8 to 12 (three destinations × before/after/two issue images), while the byte cap does not increase. Existing exporter exports attachments before checking retained byte limits; this is **not** a bound on the raw xcresult or temporary export disk use. At most six issue metadata records (96 KiB). Omitted issue captures do not suppress issue logs or audit failures. Exceeding the same byte cap fails evidence completeness, not native auditing.

## Evidence inspected

- `research/apple-camera-geometry-result-20261027/RESULT.md`, `ASK_FOLLOWUP.md`, `GEOMETRY_RECOUNT.json`: 3 unsuppressed Camera Dynamic Type findings; Practice header at AX2 begins y944.33 with Form bottom873; footer at AX1 extends to1102.67. Larger role geometry is missing. Disposable continue-after-failure scope control also observed Ask contrast and clipped-text findings. That diagnostic is not production audit policy.
- `research/native-candidate-app-integration-85/integrated/evidence/run40598054378/`: 149 hosted tests pass/6 skipped; UI 13 pass/3 skipped/2 fail, Ask not observed. These are prior saved results, not rerun here.
- `research/practice-endpoint-native-20261027/`: inactive endpoint proposal remains pending. This patch cannot establish complete largest-size footer warning reachability, VoiceOver continuity or real-device acceptance.

## Reproduction and limits

Run `python research/accessibility-followup-20261028/verify.py`. It checks exact local source hashes, applies only the proposal in a disposable temporary tree, runs existing exporter fixtures against the candidate, and seven fresh-Ask completeness fixtures. Source hashes describe the parent-owned working snapshot, **not a published commit**; rebase/review if the parent changes either source. No build, install, XCTest, artifact download, workflow activation or push occurs. No denial was encountered. Native evidence is the outstanding blocker, not a portable-test failure.

`VALIDATION.json` is the actual portable result. `SHA256SUMS` hashes the isolated review package. This is a coverage proposal, not a completed Dynamic Type fix or native acceptance result.
