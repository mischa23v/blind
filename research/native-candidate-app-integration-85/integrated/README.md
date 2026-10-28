# Connected bench and recorded preview membership — 2026-10-28

The separate `connected-bench-preview-membership.patch` adds only the reviewed `RecordedRoomRoutePreview.swift` app source and two hosted test sources (`KoivuSourceAnchorBenchFixture.swift`, `ConnectedNavigationBenchIntegrationTests.swift`) to canonical project membership. There are now 62 app Swift sources. No new package dependency, feature flag, workflow or device activation is introduced. This is membership, not evidence that the tests compile or navigation works.

The checker first reverses this exact new layer and verifies pre-membership project SHA `e80ced174477574a28b45c594e2a10029d14da9c6ef588845a93f9eab3321cd1`, then reverses the canonicalization layer and the existing historical patches. Earlier source receipts/patches remain unchanged. Native compilation and execution are pending existing CI.

---

# Canonical generated project follow-on — 2026-10-28

`project-canonicalization.patch` is an exact reversible serialization-only layer for the normal Xcode project. The same 61 native Swift paths, mesh local package/product identities and existing compilation flags remain. The current generator places `MeshCandidateDiagnostics.swift` with canonical IDs and source/group ordering instead of the former manual insertion. No source or new flag is added.

The checker reverses this layer first and requires the exact pre-canonical project hash `5aa44c32a0692dd650823d85f89b8334d59e9dd8a2d0c21900f82be14ce10614`, then runs the existing practice/critical/original patch reversals. The historical `app-integration.patch` and all prior original/intermediate pins remain intact. This fixes full checked/generated text parity, not a missing-membership defect and not native compilation. Diagnostic before/after evidence lives in `research/localization-contract-review-20261028/pbx-diagnostic/`.

---

# Review-branch source integration receipt

## Current follow-on — 2026-10-27 23:33 UTC

A separate `practice-publication.patch` now binds a narrow non-mesh change: equal-value presentation publication is suppressed only for generated simulation, while every live publication and detector/continuity/policy/watchdog tick remains unchanged. The reviewed app also shows practice-only status beside End practice and its UI test checks that visible status. This is a candidate fix for the preserved003788a idle/snapshot failure, not a claimed native pass.

The checker first reverses this exact new NavigationModel layer and requires the published pre-practice hash `ef35a58edbebd33f5d30ef4921169227ec1dfe2e9fb06664ba5a520687684c14`, then performs both historical reversals below. The default-flag/original comparison applies to that recovered pre-practice source; it does not pretend the new non-mesh presentation change never happened. Historical patch bytes are unchanged. Current native verification is pending.

The older dated receipts below are preserved as history.

---

2026-10-27 20:33 UTC. The exact reviewed stage85 three-file patch is now applied **locally to the review branch**, before actual app compilation succeeds. This explicitly supersedes the former sequencing rule “remain unapplied until compilation passes.” It does not change runtime or physical-safety gates. No master merge, device activation or push was performed by this agent.

Patch SHA256: `3cbde1075811ebab3d9fc1a54101ffad0b3749030c3dfc920cbcdca4fde2c619`.

The integration is lifecycle/counters only, fenced by DEBUG plus BLIND_MESH_CANDIDATE_DIAGNOSTICS. Process-local enabled starts false, has no production opt-in caller, and is not persisted. It does not copy mesh buffers, call ingest, change callback queues or create guidance. The independent callback provenance/ownership audit remains open; compilation does not solve those issues.

The established native Apple workflow continues its unchanged default app build and existing package/unit/UI tests. A separate job uses the same helper/base invocation and existing jobs2/unsigned policy, adding only the diagnostics compilation condition. Its fresh runner/derived data cannot contaminate default hosted/UI tests. It builds only: no test, install, simulator launch, opt-in or sensor execution.

**Resource-policy change:** this path uses the established native workflow's runner and step budgets (flag-only job25min, build step20min). It does not use, satisfy or claim compliance with the experimental harness's CPU300s/file128MiB/scratch2GiB limits. Those repeated failures remain preserved and unresolved. Both baseline and proposal failed even after normalizing commands; no crash mechanism has been established. The custom stage85 workflow is retired (no push trigger, unconditional false job guard), because its pre-patch checks are no longer applicable.

`check.py` and its separate manifest verify integrated source, exact reversal to the historical originals in a temporary three-file copy, no-copy/default-off guards, flag isolation, default invocation and retired experiment. Historical stage85 manifests/results are not rewritten to pretend their unapplied-state checks still pass. Actual native compilation in both flag modes remains pending. Root owns review/publication and all subsequent runs.

## Critical-retirement ordering layer — 2026-10-27

`critical-order.patch` is a separate, reversible follow-on to the published stage85 integration. Optional mesh stops now follow the existing critical cancellation/authority-retirement prefixes, while still preceding camera pause, frame throttling or recovery as applicable. The original `app-integration.patch` remains byte-for-byte unchanged.

The integrated checker reverses this new layer first and verifies NavigationModel SHA-256 `06305bbb3a8f1b8800cb3454eade606b2749230b359a3d32fec36dda95a52307`, then reverses the original three-file patch and checks its historical originals. It also checks that removing only the exact mesh feature fences recovers the entire original default NavigationModel. The current source remains default-off, no-copy and without physical-output authority. These are portable source checks; native compilation/execution of the revised source remains separate.
