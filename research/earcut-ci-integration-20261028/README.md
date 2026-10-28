# Explicit current Earcut dependency/CI integration

This checkpoint does not rewrite previous native evidence. `APPLE_SOURCE_PINS.json` (stage75), `SOURCE_PINS.json` (stage83) and classified-bench `INPUT_PINS.json` remain byte-identical historical records. Their old “unchanged dependency” checks should not be presented as passes against the new package.

## Active consumers

- `.github/workflows/native-apple.yml`: preflight hashes project/Core/Memory, checks installed Xcode/Simulator; no stage75 pin validation here. The diagnostic job invokes stage85 `integrated/check.py`. Its current workflow digest must be updated separately to the final reviewed workflow; no check removal.
- `.github/workflows/native-room-mesh-package.yml`: stage75 source changes trigger `research/room-mesh-package-75/apple/ci.py`.
- `.github/workflows/mesh-candidate-ingress.yml`: the same dependency changes also trigger stage83 `apple/ci.py`, which validates its source manifest and stage75's manifest.
- The new classified-bench job runs actual SwiftPM fixtures. It does not invoke the historical classifier `check_source.py` pin loop.

## Reviewed current manifests

Stage75 now reads `APPLE_CURRENT_SOURCE_PINS.json`; stage83 reads `CURRENT_SOURCE_PINS.json` and the stage75 current manifest. These explicit manifests retain baseline manifest digests, changed-file before/after hashes and new file paths. Original manifest digests are checked before current files are validated. No generic bypass or arbitrary override is added.

`CURRENT_INPUT_PINS.json` records classified-bench current dependency inputs separately from its frozen provenance. Run `check_current_pins.py` here for current hash verification and the unchanged classifier source-contract checks. That script does not rewrite the historical `SOURCE_RESULT.json` or claim the old connector receipt covers newly edited local bytes.

The CEarcut adapter, C header, upstream header, license and Swift bridge are all included in stage75 current coverage and classified current inputs. The stage83 manifest pins the whole stage75 current manifest in addition to its existing inputs.

## Manual client linking

Both old native package runners assemble Swift clients from object files rather than using a normal executable SwiftPM target. Adding CEarcut to Package.swift alone is insufficient: those clients must also link `CEarcut.build` object files and import the SwiftPM-generated `CEarcut.build/module.modulemap`. Both runners now require those outputs, retain the existing object-count ceiling, and preserve their SDK/time/resource restrictions. They do not install a dependency or replace the upstream algorithm.

## Evidence limits

`CURRENT_SOURCE_RESULT.json` contains source/hash checks, not Apple compilation. Historical runner scripts are copied under `historical/` for review. The final candidate must execute actual Apple jobs again; previous stage75/83/classified results do not cover changed C++ language mode, dependency graph, bridge or floor adapter.

Run `prepare_current_pins.py` only after the sole source writer freezes its reviewed files, followed by `check_current_pins.py`. The preparation command rejects changes outside the specifically reviewed historical input paths; it is not a general re-pin command. Root owns publication and must recheck remote source before pushing.
