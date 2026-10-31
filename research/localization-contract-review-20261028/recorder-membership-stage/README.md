# Recorder hookup and canonical native membership — 2026-10-28

## Scope and reviewed source freeze

This stage maintains the canonical project and exact historical verification for the separately authored/reviewed opt-in recorder hookup. Recorder implementation is owned by `research/navigation-test-recording-20261028/PUBLICATION_MANIFEST.json`; this stage does not edit its app/Core/Store/UI sources.

- Preserve all prior 62 app sources; add only `NavigationTestRecordingView.swift`: **63 app sources**.
- Add existing `RecordedRouteStoreTests.swift` to hosted tests. It was **not previously in this target**, despite existing as a file. Whole-file membership includes older Store tests and four new diagnostic methods; none are retroactively claimed to have run in native CI.
- Existing app package/framework linkage and all build settings/flags remain unchanged.
- Root explicitly approved **hosted-test-only** product links for existing BlindMemory and GRDB. The explicit GRDB PBX package reference uses the SAME `https://github.com/groue/GRDB.swift.git`, exact **7.11.1**, already pinned in `BlindMemory/Package.swift`. No new library/version, local download, resolver execution or workflow change.
- This avoids relying on implicit transitive imports for Store tests' actual `DatabaseQueue` usage. Native resolution/import/link correctness remains pending existing CI.

## Exact reversible history

`integrated/navigation-test-recording.patch` covers only the reviewed NavigationModel hookup plus this PBX membership/linkage delta. The checker reverses it first and verifies:

- NavigationModel before recorder: `5275400e782a88374641aa0b61d2c85b1d35f20330b58e5b2d86b7b9626b4d67`.
- Project before recorder: `cee0cbac7dc54bba1ba5845b6d901f00b32afaa44e1647c0fca73490c59142a1`.

It then performs every preceding connected-preview/canonical/practice/critical/original stage85 reversal. Historical patches and original/intermediate pins are unchanged. Current project: `63fc5fcd1d9ef153c87ca48b9fa195f270fec3c039ee58887d407d46b300d87c`.

## Bounded results

- `check-membership.mjs`: exact generator equality; 63 app sources; only two new Swift memberships; prior sources intact; explicit hosted product ownership; identical GRDB URL/version to existing manifest; unchanged app linkage/build settings.
- Integrated checker: **45/45 source checks passed**, including exact original recovery.
- Generator/photo project regressions: **61/61 source checks passed**.
- Initial expanded regression: **59/60**, because the old mesh-project test prohibited every remote PBX reference. Preserved as `regression-before-existing-grdb-allowlist.log`. The test now allows **only** the exact already-used GRDB reference, verifies it against the Memory manifest, preserves bans on other remote URLs/shell scripts, and adds actual hosted product/framework ownership checks. This is an explicit approved contract update, not a hidden native failure.

Commands from repository root:

```sh
node research/localization-contract-review-20261028/recorder-membership-stage/check-membership.mjs
python3 research/native-candidate-app-integration-85/integrated/check.py
node --test tools/test/mesh-package-project.test.mjs tools/test/room-reference-photo-trash.test.mjs tools/test/selected-photo-reference.test.mjs tools/test/currency-device-test-project.test.mjs tools/test/currency-reference-project.test.mjs tools/test/object-detector-project.test.mjs
```

**No Swift/native execution, dependency download or physical navigation validation occurred.** Earlier membership checkers/receipts remain historical snapshots of their 61/62-source states; this checker supersedes their fixed-count assumptions for the current tree. Existing device/CI validation is still required before calling the recorder usable or the hosted tests passed.
