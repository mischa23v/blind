# Review-branch source integration receipt

2026-10-27 20:33 UTC. The exact reviewed stage85 three-file patch is now applied **locally to the review branch**, before actual app compilation succeeds. This explicitly supersedes the former sequencing rule “remain unapplied until compilation passes.” It does not change runtime or physical-safety gates. No master merge, device activation or push was performed by this agent.

Patch SHA256: `3cbde1075811ebab3d9fc1a54101ffad0b3749030c3dfc920cbcdca4fde2c619`.

The integration is lifecycle/counters only, fenced by DEBUG plus BLIND_MESH_CANDIDATE_DIAGNOSTICS. Process-local enabled starts false, has no production opt-in caller, and is not persisted. It does not copy mesh buffers, call ingest, change callback queues or create guidance. The independent callback provenance/ownership audit remains open; compilation does not solve those issues.

The established native Apple workflow continues its unchanged default app build and existing package/unit/UI tests. A separate job uses the same helper/base invocation and existing jobs2/unsigned policy, adding only the diagnostics compilation condition. Its fresh runner/derived data cannot contaminate default hosted/UI tests. It builds only: no test, install, simulator launch, opt-in or sensor execution.

**Resource-policy change:** this path uses the established native workflow's runner and step budgets (flag-only job25min, build step20min). It does not use, satisfy or claim compliance with the experimental harness's CPU300s/file128MiB/scratch2GiB limits. Those repeated failures remain preserved and unresolved. Both baseline and proposal failed even after normalizing commands; no crash mechanism has been established. The custom stage85 workflow is retired (no push trigger, unconditional false job guard), because its pre-patch checks are no longer applicable.

`check.py` and its separate manifest verify integrated source, exact reversal to the historical originals in a temporary three-file copy, no-copy/default-off guards, flag isolation, default invocation and retired experiment. Historical stage85 manifests/results are not rewritten to pretend their unapplied-state checks still pass. Actual native compilation in both flag modes remains pending. Root owns review/publication and all subsequent runs.

## Critical-retirement ordering layer — 2026-10-27

`critical-order.patch` is a separate, reversible follow-on to the published stage85 integration. Optional mesh stops now follow the existing critical cancellation/authority-retirement prefixes, while still preceding camera pause, frame throttling or recovery as applicable. The original `app-integration.patch` remains byte-for-byte unchanged.

The integrated checker reverses this new layer first and verifies NavigationModel SHA-256 `06305bbb3a8f1b8800cb3454eade606b2749230b359a3d32fec36dda95a52307`, then reverses the original three-file patch and checks its historical originals. It also checks that removing only the exact mesh feature fences recovers the entire original default NavigationModel. The current source remains default-off, no-copy and without physical-output authority. These are portable source checks; native compilation/execution of the revised source remains separate.
