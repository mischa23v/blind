# Current full-app Practice footer-end control

Proposal,2026-10-27. No native execution or active workflow yet. Root owns review/publication.42 portable source/receipt checks passed. No app/test source is edited.

The normal native workflow does not set BLIND_LAYOUT_DIAGNOSTIC or configure system content size; its two endpoint tests skip by design. The current full native run therefore does not replace this control (confirmed with its owner). Prior full-app AX5 screenshots visibly show enlarged button/header but not the end of the footer. Isolated host endpoint success is not this full-app check.

This reuses the already-published LaunchTests endpoint selectors, including their existing8up/8down footer-end traversal, exact full label, hittability, and bottom-between-navigation-and-tab requirement. It changes neither production scrolling nor any audit filter. Source is pinned tofb879d235f38a3f0121b69b023e8ee14c0ded61c and exact current DashboardView/LaunchTests/exporter hashes. A separate clean checkout is mandatory.

One owned simulator, one build-for-testing, two serial test-without-building calls: Large then accessibilityXXXL. The requested simulator category is explicitly set/read, and the endpoint receipt requires the runner's matching category plus exactly one started/passed selected test, no skip/failure, all three content-role records and endVisible=true. Each case exports its four exact authored role screenshots including footer-end, at most8PNGs/24MiB combined. A failing receipt does not prevent attempted image export.

The orchestration adapts tools/ci/camera-audit-scope-control.py, with reviewed stronger owned-process cleanup:600seconds build,300seconds each selector,180seconds bootstatus,120seconds export,2400seconds runner,45minute workflow. No repeats, caps raised, new dependencies, camera or private data. Existing logs are summarized boundedly; source remains unchanged apart from separately validated generated GRDB Package.resolved metadata, which is never called a source-clean checkout. Unexpected source changes fail.

`workflow-proposal.yml` remains inactive until reviewed. The workflow's proposed path is separate from camera-geometry diagnostics so publishing this control does not rerun those experiments. `python3 .../verify.py <pinned source>` runs only synthetic parser/source checks.

Interpretation: readable complete endpoint pixels plus native reachability assertions would support actual full-app scrolling at the two endpoints. They would not prove every intermediate size, VoiceOver focus continuity, all locales, or that the unsuppressed Dynamic Type audit is false. A failure preserves its exact stage and needs diagnosis before any layout fix.

## Review hardening

Every command reaps its leader and checks the owned process group, including a normal leader exit. A live group receives SIGTERM then, after a bounded grace, SIGKILL even if the leader has already exited. Remaining group evidence is reported unknown and fails the run rather than claiming cleanup. Simulator creation uses an unpredictable exact owned name; uncertain creation gets one bounded exact-name recovery listing/cleanup, otherwise remains creation-uncertain (never a sweep of other devices).

The pinned exporter writes only to private staging outside the upload tree. All four names, regular-file/signature checks, and the aggregate 8 PNG / 24 MiB cap pass before atomic directory publication. Oversized/private partial outputs are not uploaded; failure metadata retains measured staging counts/bytes where available, while previous accepted endpoint evidence remains. Native failures still attempt bounded images. Malformed generated package metadata preserves a final failed provenance receipt.

Adversarial fixtures include an exited leader with a SIGTERM-ignoring descendant, a 28 MiB single endpoint, and individually valid endpoints exceeding the aggregate cap. These are tooling bounds, not accessibility results.
