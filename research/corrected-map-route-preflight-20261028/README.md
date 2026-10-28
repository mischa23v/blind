# Corrected-map route preflight: actual native component smoke

2026-10-28. **Build passed; all 12 unchanged native wrapper fixtures passed. No recorded room route or movement episode ran.**

The existing stage75 CDetour adapter was compiled against the project's pinned, unmodified Recast/Detour source. All 43 upstream source/header/license files matched the independently retained `tools/navigation-recast/UPSTREAM_MANIFEST.json` from repository checkpoint `3750788`. Revision `9f4ce64458dfae86e1239c525ddc219c4e9e06f1`; upstream https://github.com/recastnavigation/recastnavigation; Zlib license. The 55-file current stage75 Apple source manifest also matched before staging. These are local source/component results, not an upstream test-suite rerun or Apple execution.

## Executed

`python3 research/corrected-map-route-preflight-20261028/run_smoke.py`

The script ran one serial `g++` command followed by the existing, unchanged `tools/navigation-recast/test_detour_engine.py` via `python -m unittest -v test_detour_engine`. The full command and process samples are retained in resource receipts. The Python ctypes binding also came unchanged from `3750788`. The built adapter is the current stage75 `clearance_adapter.cpp` / `blind_detour_exclusion.cpp`, not the older `tools/navigation-recast/blind_detour.cpp`.

- Build: 4.717 s elapsed; 63,127,552 B sampled aggregate RSS including wrapper.
- Test subprocess: 0.207 s elapsed; unittest reports 12 cases in 0.035 s, zero failures/skips.
- Combined: 4.927 s elapsed; 4.756 CPU s; 1,175,052 B stage disk at result capture.
- Limits: one CPU, 1 GiB sampled aggregate RSS, 1 GiB stage disk, 300 s total wall. No dependency installation, model/data download, upstream modification or remote mutation.
- Retained upstream GCC `-Wmaybe-uninitialized` warnings in `DetourNavMesh.cpp`; no warning was patched away.
- Binary SHA256: `aafd4aedbf212384e23ced5cdb6329589f31f80f319a2f50ce9a582bf1a606f2`.

Fixtures cover flat routes, real box detours, unknown floor gaps, walls, overhead clearance, width-limited passage, invalid starts, truncated paths, malformed input, candidate velocity, floor winding and closed handles. The 12 fixtures use the legacy `bn_build` entry point; they do **not** establish the classified-support entry point or an occupancy adapter.

## Recorded-data inspection, not routing

`LEDGER_SCHEMA_INSPECTION.json` inspects the already-produced corrected OctoMap ledger without reconstruction or reference queries. There are 2,268,956 records; 139 are 8 cm leaves and the rest 4 cm. Native occupied-ground labels span Z=-1.46 to +0.30 m, with median -1.26 m and P95 -0.58 m. Therefore neither constant-size cubes nor treating every ground label as verified floor is justified. The schema itself explicitly says `floorSupportVerified=false`.

See `NEXT_ADAPTER_PROPOSAL.md` for the narrow representation gap and proposed first fixtures. Nothing here establishes independently checked full-body contacts, full-footprint support, table/door/return paths, current localization or physical guidance.

## Publication and reproduction

`PUBLICATION_MANIFEST.json` is the exact text-only allowlist. Generated `.so`/object files, duplicate native third-party sources, map/depth/image/reference payloads and local historical investigation copies are excluded. `SOURCE_RECEIPT.json` retains the source pin chain; paths naming excluded files are provenance, not a claim those payloads are shipped.

To reproduce in a fresh output directory, recover the exact source files named by `SOURCE_RECEIPT.json` from the stated repository checkpoint: stage75's `BlindRoomMesh/Sources/CDetour` supplies the native adapter and upstream subdirectories; its `LICENSE-Recast.txt` supplies `native/upstream/License.txt`. Verify every source hash, then run `run_smoke.py`. The script refuses to overwrite an existing result. This packet does not install tools or fetch dependencies. A compatible existing g++, Python and NumPy are prerequisites. Existing historical 20×5 route metadata is not silently reused as a coordinate-compatible corrected-map experiment.
