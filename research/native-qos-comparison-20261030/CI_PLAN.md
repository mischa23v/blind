# Isolated hosted QoS comparison: CI proposal, not executed

These additions exist only in `coordination/native-qos-comparison-20261030/after`. Root review and a later explicit source publication are required before any hosted execution. No shared app source, workflow, permission, billing, runner setting, deadline or acceptance criterion was changed by this preparation.

## Lane and compiler isolation

- New branch-only push workflow: `.github/workflows/native-qos-comparison.yml`.
- Exact experiment triggers: the workflow, `research/native-qos-comparison-20261030/**`, the one new Swift test, and the two new CI Python files. A shared runtime-only edit does not independently trigger this diagnostic lane.
- Public `mischa23v/blind` repository and exact branch checked before allocating the standard `xcode-27` runner. Fork/private guards, read-only token, pinned checkout, no persisted credentials.
- Uses the existing installed iOS 27.0 / iPhone 18 Pro Max Simulator and ordinary hosted `BlindAssistTests` context. No new runtime or dependency install instruction, runner download, service or cache. Existing project dependency resolution is unchanged.
- Generator/project add source membership for `NativeQoSComparisonTests.swift` only. The generated default project remains byte-exact to its generator and contains **no** `BLIND_QOS_COMPARISON` setting. Ordinary acceptance compiles the empty guarded source, discovers none of its test methods, and keeps existing scheduling.
- Dedicated command passes `SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG BLIND_QOS_COMPARISON`, selects exactly `BlindAssistTests/NativeQoSComparisonTests/testIsolatedUtilityUserInitiatedABBA`, and disables parallel testing. This command-line flag is not persisted into the app project or package manifest. The package hook is independently `DEBUG`-only and inactive unless explicitly called; the lane does **not** assume the custom test flag propagates into SwiftPM. Actual successful compilation is still unobserved.
- Build and test are separate `build-for-testing` / `test-without-building` steps with an isolated DerivedData directory. No build/retry during ABBA measurement. Same ordinary host startup context, but the test deliberately bypasses ingress83/controller and thus cannot replace seated acceptance.

## Bounded execution and failure evidence

Original four arms and each 10-second source/query/normal-drain deadline remain unchanged. A late 45-second drain observation never erases an original failure. Source failure may skip query, and missing native acknowledgement aborts remaining arms.

Dedicated wrapper bounds: build 900 seconds; test-launch observation 120 seconds; after observing the exact XCTest-start stdout marker, case observation 360 seconds; whole test process 480 seconds; command log 64 MiB. Watchdog expiry records the original process exit and wrapper failure 124. These are diagnostic process ceilings, **not** extended acceptance deadlines. Workflow job ceiling 30 minutes. Root must review these bounds before execution. The marker is observation-based; stdout buffering/backlog can cause a launch-observation timeout/incomplete result, not proof that XCTest itself started late.

`NATIVE_QOS_COMMAND` and `NATIVE_QOS_RECEIPT` are emitted in ordinary job logs. Final receipt also goes to the normal job summary on success or failure. It independently preserves failed case identity/counts, command outcomes, and accepted timing records when another input is missing. Arbitrary geometry, error/model text and unrelated case identifiers are not exported. Native timing grammar is closed: four fixed prefixes, fixed arm/request/stage vocabularies, 4 KiB line cap, 64 metadata records, bounded numeric fields. Missing CPU stays `-1,false`.

A clean diagnostic requires all of: both command exits zero, same clean source commit/hashes, exactly one passed selected XCTest reconciled with xcresult counts, four exact ABBA arm rows, four source rows, all 12 original deadlines met, no late observation, no malformed/overflow metadata. Four arm records alone cannot pass. Identical or unavailable effective QoS is explicitly inconclusive separation. Both arms enforce work-item QoS, so the utility arm is not an untreated timing baseline of the ordinary nil-override dispatch path. No result establishes QoS causality, fixes normal acceptance or authorizes physical guidance.

No `upload-artifact` action exists in the new workflow. `.xcresult` and raw logs remain only in the ephemeral runner workspace; they are **not** uploaded. Built-in logs/summary carry the bounded receipt. No artifact allowance or payment setting is assumed.

## Source-only verification and remaining adoption work

61 portable stdlib controls pass: clean/failed/skipped/missing/duplicate cases, late drain, skipped query, command/status/source mismatches, unknown fields, CPU pairs, byte/line/record bounds, exact test/flag selection, source hook default, and independent watchdog bounds. Before/after project generation is byte-exact. No Apple compilation, Simulator run, timing measurement or CI dispatch occurred.

Current seven-file proposal audited against all 43 workflows (42 existing plus new): native Apple, owned ingress, room-mesh package and the new diagnostic would trigger; all relevant existing uploads are default-disabled, and the new lane has none. Master-only familiar workflow does not trigger. See `CI_TRIGGER_AUDIT.json`. The runtime change therefore also reruns ordinary acceptance with its existing defaults; it is not a substitute for those jobs.

Before adoption, source/provenance author must add current hashes and a reversible historical layer for generator/project/runtime/CI files, preserve old baseline validators, and include the published proposal packet. Final combined publication paths require another trigger audit. Existing frozen failure receipts are not modified. Root publishes only after independent review.

## Primary references

Apple documents test automation and `-only-testing` in [Testing with Xcode](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/08-automation.html), and conditional compilation in its [build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference). SwiftPM's [target Swift settings](https://docs.swift.org/latest/documentation/packagedescription/target/swiftsettings/) are separate package settings, not a reason to assume app flags reach dependencies. GitHub's [standard hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [Actions billing rules](https://docs.github.com/en/billing/concepts/product-billing/github-actions) support the reviewed public-standard-runner / built-in-log choice; no paid storage feature is enabled by this lane.
