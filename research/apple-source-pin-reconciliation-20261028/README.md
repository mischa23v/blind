# Reconcile active stage75/83 Apple source pins

## Observed failure

At exact source `9284719fe477135d4bcd85b2cbd2a587609ed428`, [room-mesh proof run 40710093201](https://github.com/mischa23v/blind/actions/runs/40710093201) and [ingress proof run 40710093419](https://github.com/mischa23v/blind/actions/runs/40710093419) both failed before building or executing tests: the stage75 manifest expected an obsolete `Bridge.swift` digest. No native proof receipt was produced. This was a correct fail-closed source check, not a Swift compilation or runtime result.

## Exact cause and repair

The last stage75 Apple manifest update was `eb0fc673a72d1c9003cbceb5ef0f68c60e4f5563`. Classified-floor adaptation in `4182e99544003abcc4778cf4b15801c4ca93084b` changed four local adapter sources without updating these Apple pins:

- `Bridge.swift`: typed triangle support and classified native bridge.
- `RoomMeshCandidate.swift`: explicit classified/legacy support policy and ingress validation.
- `blind_detour_exclusion.cpp`: classified raster provenance and floor-only walkability.
- `include/blind_detour.h`: classified build entry point.

The runtime then gained DEBUG-only timing in `9284719…`. Therefore the Bridge failure is **not caused by timing alone**. Old pin values were verified against the exact old source bytes; current bytes and Git blobs were verified against exact `9284719…`.

Only these four adapted-source digests changed in `APPLE_SOURCE_PINS.json`. All 55 targets match; the other 51 pins, including upstream sources, native fixture tests, public client, package manifest, runner and workflow proposal, are unchanged. The repaired manifest SHA-256 is `d96e7e5ecf2f1bfdfe42e95e1717119ffccb7e306bfd54aa4815b2f5f40b8530`.

The stage83 owner updated its active nested manifest reference alongside its separately reviewed opt-in classification adaptation. No stage75/83 build command, compiler option, budget, platform guard, test count or result assertion is bypassed or weakened. No workflow was changed or manually run by this repair.

Historical portable `FROZEN.json`/receipts and audit manifests remain historical. The old stage85 pre-integration workflow is explicitly retired; stage86 has an inert opt-in runner and no installed workflow. Their old evidence is not repinned green. The current cumulative stage85 integration checker remains separately maintained by the integration owner.

## Verification and limits

- Independent reviewer re-fetched baseline pins and four current sources, then verified all 55 SHA-256/length/Git-blob records and the exact four-entry delta.
- `python3 research/apple-source-pin-reconciliation-20261028/check.py`: **8 source contracts passed**, including actual existing pin-verifier rejection of a modified synthetic file.
- Unchanged `research/mesh-candidate-ingress-83/check_static.py`: **42 source contracts passed** against the current coordinated candidate.
- Apple SwiftPM builds, host fixture execution and iOS Simulator linking: **not run locally**. The earlier failed native runs remain failed; updated hashes do not establish a native pass.

`source-reconciliation.json` contains every current file hash/blob and old/new adapted-source provenance. `pin-mismatches.json` preserves the pre-repair observation; `.before` preserves the old manifest. `publication-manifest.json` is the explicit publication allowlist. The 55 restored unchanged source files and unchanged workflow/dependency copies are not publication changes. Root alone publishes and monitors resulting native proofs.
