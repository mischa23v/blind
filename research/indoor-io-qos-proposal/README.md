# Applied review candidate: foreground SpatialMapIO QoS

2026-10-27. **Applied locally as a review candidate; not yet published or deployed.**
Independent review approved the exact one-line candidate. `candidate.patch` changes only
SpatialMapIO's serial queue QoS from `.utility` to `.userInitiated`. It contains no
observer, new mechanism, deadline change or storage workaround. Before-file SHA-256
and applied-file SHA-256 are verified and pinned in `manifest.json`.

## Intent, independently of the diagnostic outcome

Apple's current [DispatchQoS.userInitiated documentation](https://developer.apple.com/documentation/Dispatch/DispatchQoS/userInitiated)
assigns this class to work delivering immediate results for the user's current action
or preventing active app use. [Utility documentation](https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass-swift.enum/utility)
places non-immediate work the user need not actively follow at a lower priority.

The archived [Apple energy/QoS guide](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/PrioritizeWorkWithQoS.html)
distinguishes opening a saved document from imports that need no immediate result.
It explicitly allows the latter at utility: “import” alone does **not** justify raising
priority. Higher priority can cost energy and compete for resources; QoS is intent,
not a deadline guarantee. The candidate is justified by the current callers'
user-gating/readiness semantics, not by operation names or a blanket rule for disk IO.

## Complete current production-consumer review

Repository search found two production owners of SpatialMapIO:

| Owner / path | Requests and relevance |
|---|---|
| `RegisteredIndoorNavigation.swift:39`, owned by `IndoorNavigator.swift:63` | All transactions go through the same bounded serial ownership worker. |
| `IndoorNavigator.swift:65–70`; `NavigationModel.swift:294`; `BlindAssistApp.swift:5` | Automatic initial map restore for the opened app. This is **not an explicit import gesture**. It establishes current map readiness; while pending, map export/configuration and map-dependent operations are gated and pose remains unknown. |
| `DashboardView.swift:737–746`; `IndoorNavigator.swift:138–176` | User deletes map or selects a file to import; pending state/receipt gates map use. |
| `CommunityMapsView.swift:33–55`; `IndoorNavigator.swift:185–200` | User-confirmed community-route replacement; active intent remains fenced across separate cache preparation, then the worker publishes the current map. |
| `KeepOutZonesView.swift`; `IndoorNavigator.swift:257–306`; `NavigationModel.swift:1729–1734` | User changes keep-out restrictions or reports blocked way; publication/replan waits for durable current transaction. Output retirement remains immediate and independent of IO. |
| `BodyProfileStore.swift:18,20` | **Second consumer**: private body-profile transactions, not just map files. |
| `NavigationModel.swift:668–677` | Automatic startup profile load establishes bounds available to active warning consumers. Not a user save gesture, not periodic maintenance. Missing profile remains unknown. |
| `BodyProfileSettingsView.swift:66–70,93–98,133–138` | View load, user save and explicit delete; busy/result state and current geometry gate further interaction. Deferred reads after mutation belong to these same foreground requests. |

No background-only sync, indexing, periodic refresh, bulk prefetch or BGTask consumer
of SpatialMapIO was found. These automatic startup loads are finite, foreground-app
readiness work; they are **not** evidence that all app startup work merits this QoS.
Work already admitted may finish after the app backgrounds; this patch adds no
background entitlement, restart, wakeup or execution guarantee.

`IndoorNavigator.restoreCommunityContext` deliberately retains its separate
`Task.detached(priority: .utility)` metadata matching. Public downloads/cache,
private memory engines and unrelated queues are out of scope. The existing worker
is one serial executor per owner, with one running/latest pending request and an
ordered deletion barrier; this change neither adds concurrency nor touches that
contract. Future truly background consumers should get explicit separate priority
configuration rather than inheriting this policy silently. A per-request scheduler
rewrite is not justified by the current caller inventory.

**Recommendation:** current callers support the one-line candidate for review,
including body-profile interaction/readiness. Do not claim every caller was explicitly
clicked. If the product later makes startup loads discretionary prefetch rather than
readiness dependencies, split their admission/QoS then; do not preemptively redesign
the transactional worker now.

## Actual comparison, not causal proof

Run [40564108627](https://github.com/mischa23v/blind/actions/runs/40564108627), source
e9e18d15fe1fdac1ff1487b3c2a8a2e731607427, harness
1c53f27b2a3b9497bec269af1fd9a843d6fe7600:

- Utility built; original selected test failed once, command eventually hit its
  original 360s cap. Complete 55-event/no-drop snapshot: fixture submit→worker
  3.438s, prior-file open span ≥14.252s at right-censor, no completion by snapshot.
- UserInitiated built and passed the original test once with zero failures and command
  exit 0. Complete 91-event/no-drop snapshot: submit→completion 1.897ms,
  submit→worker 0.396ms, prior-file open→throw 0.103ms, actual wait 2.151ms.
- Both had identical source/toolchain/observer hashes and independent fresh simulators.
  Actual generated source hashes match the two declared arms; no unintended changes.

This supports evaluating the candidate. N=1 per arm, separate host conditions and
remaining observer overhead prevent attributing the difference exclusively to QoS.
It does not prove a Foundation bug, repair all timeouts or establish device safety.
The buffered observer is **not** included in this patch. Raw verified artifacts and
assessment are retained at `recovered-checkpoints/buffered-io-40564108627/` in the
parent workspace, outside this repository.

## Regression plan after independent approval/application

1. Verify one-line app diff against manifest; no instrumentation or fixture changes.
   Reuse the project's pinned Apple environment, original assertions, original
   deadlines and full-native-check scope. Never turn a timeout into an expected pass.
2. Run the original complete native regression workflow, not only the successful
   focused test. Specifically include `IndoorGoalContinuityTests`,
   `SpatialMapIOTests`, `RegisteredIndoorNavigationTests`, `IndoorNavigatorAsyncTests`
   and `SpatialRouteOutputControllerTests` with their existing coverage.
3. Preserve blocked writer/main warning responsiveness; bounded supersession;
   before/after-main CAS; delete barriers; failed deletion/retry; rollback failure;
   delayed restore/import; failed newer writes; pending restriction union; goal/task
   cancellation; late cache/purge callbacks; pose remains unknown after restore.
4. Because this changes BodyProfileStore too, run its existing extracted executable
   verification at `research/evaluations/body-aware-warning/verification/run-tests.sh`
   and `Tests/BodyProfileStoreTests.swift`, under its documented environment and
   resource limits. Keep protected-file, save/reopen, delete/no-resurrection,
   superseded read/mutation and revision-check cases. This harness is not a substitute
   for native protected-storage and settings UI verification.
5. In native/device acceptance check import/settings busy-to-result transitions,
   delete/reopen and background interruption, preserving main-owner responsiveness
   and independent sensor warnings. Review energy/thermal contention before broad
   reliability claims. Higher QoS is not authorization to run physical guidance.

Stop at the actual outcomes. Report per-suite failures/unrun stages and retain old
failures; do not add hidden retries or increase budgets. Local application ran only patch/static/shell checks, not those regression steps.
Full native and body-profile regression results remain pending.

## Current-source body-profile check (prepared, not run)

`body-profile-current.yml` is a proposal for root to review and install as
`.github/workflows/body-profile-current.yml`; its presence here does not enable CI.
It uses the existing `xcode-27` / Xcode 27.0 installation, public-repository and exact
branch guards, read-only permissions, pinned checkout/upload actions, a 15-minute
job cap, and a 12-minute step cap. No installs, models, Docker or hidden retries.
The unchanged verification script retains `swift test --jobs 2` and original tests.

`run-current-body-profile.py` copies only the existing `verification/` directory to
a fresh `RUNNER_TEMP` stage (no sibling `source/`), explicitly sets
`BLIND_SOURCE_ROOT` to the workflow's current checked-out commit, and uses a unique
`BODY_WARNING_WORK`. This deliberately avoids the historical evaluation source
overlay. A 600-second command cap fails on timeout. Evidence includes the current
commit, toolchain, unchanged harness SHA, complete compiled-input manifest, log,
and result. Every manifest hash is rechecked against the checkout/fresh harness;
the actual copied SpatialMapIO compilation input must match the candidate SHA.
This extracted macOS regression is not protected-storage or iOS UI/device proof.

The existing `.github/workflows/native-apple.yml` is unchanged and its existing
`ios/**` path trigger covers the one-line source change. Full native suites and
body-profile results are both **pending**; earlier N=1 diagnostic evidence is not
causal proof and has not been promoted into a regression pass.

### Required executable coverage and bounded evidence

A zero process exit is insufficient: `body_profile_evidence.py` derives all nine
exact test names from the unchanged `BodyProfileStoreTests.swift`, and requires
one `started` then one `passed` XCTest record per name. Missing, skipped, failed,
duplicate, out-of-order, malformed or unexpected case records fail closed. The
separate Swift Testing “0 tests” footer is not XCTest coverage. Coverage evidence
is saved separately and must pass along with process exit and input hashes.

The full output stream is parsed with bounded lines/events and only a 512 KiB
head plus 512 KiB tail is retained; truncation is explicit. Overlong lines fail
coverage rather than allowing an incomplete parser result to pass. The manifest
is limited to 256 KiB; an unexpected aggregate artifact size over 2 MiB fails and
explicitly truncates oversized evidence before upload. No global file-size limit
is imposed on Swift builds or sparse caches.

Lightweight synthetic parser fixtures: `python3
research/indoor-io-qos-proposal/test_body_profile_evidence.py` — **12 passed**,
covering Darwin/dotted XCTest, the extra Swift Testing footer, absent/skipped/failed/
duplicate/malformed events, order, long lines and capped logs. These are parser
checks only, not native regression results.
