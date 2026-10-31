# Koivu seven-objective comparator — failed attempt preserved; retry pending

## Later execution failure and narrow repair — 2026-10-29

The initial preparation notes below remain historical. Root subsequently ran
`conference-native-comparison-attempt-001` at source
`d40c1e193511305364c90b42e1c44038d901c0cb`. Its 26 graph controls exited 0, but
the comparator exited 1: final `verify()` read the route-start list through the
shadowed argparse variable `a`. All seven proposal records remain saved;
**the failed attempt is not an accepted comparison**. Its receipt, logs and
proposals are unchanged. `ATTEMPT_001_FAILURE.json` records the public failure
summary and retained file hashes, without raw geometry; the exact previous
manifest is preserved as `SOURCE_PINS.attempt-001.json`.

The only comparator change is a dedicated `cli_args` binding and the three
pin-check/load lines that use it. Four bounded standard-library source controls passed, including a
negative control reproducing the original bug and checks that manifest/input
mutation is still rejected after endpoint iteration. They execute extracted
source bindings, not native routes or graph controls. The closure-sensitive
binding audit and exact source hashes are in `ATTEMPT_002_PREPARATION.json`.

`SOURCE_PINS.json` now proposes fresh
`conference-native-comparison-attempt-002`; only the comparator hash and the two
attempt output paths changed. The same 25 inputs, endpoints, native settings,
limits and authority restrictions remain. No second native comparison has been
run by this repair; root must review, publish and separately admit it.

Prepared for root's separately admitted conference-room repeat after the active Coffee stages. **No extraction, scientific import, native load, route, body check or movement has been executed by this packet.** The initial task is exact source recovery and source-only planning; no FARO, floor filling or invented exclusions.

## Extraction

After root confirms that the download is complete, the exact bounded command is:

```sh
python -B research/conference-replay-source-20261029/extract_source.py \
  --archive /workspace/scratch/90f3f6703064/conference-source-recovery/koivu_iphone.tar.gz \
  --out /workspace/scratch/90f3f6703064/conference-source-recovery/extracted-001
```

This is a proposed invocation, not a record of execution. Fresh output only. The helper pins archive length146,575,749/SHA256`68735cfa…`, verifies full compressed bytes before extraction, validates all member names/types/duplicates and scans≤256MiB decompressed. It copies only the exact original OBJ and associated original pose/intrinsics JSON (3,705,297bytes total), verifying each member hash. It drains gzip for CRC and rehashes the same archive descriptor after extraction, checking file identity/timestamps. Limits60CPU/180wall/384MiB address space/4MiB individual output;768MiB free-disk reserve. No native imports, RGB/texture/depth extraction or network transfer. Completed and failed receipts are distinct, and a partial attempt is never overwritten. An outer supervisor is still responsible for a terminal receipt if OS limits forcibly kill the process.

Source-data license/attribution: Xuqian Ren et al., MuSHRoom, CC BY4.0. Exact official URL, original member paths and expected hashes are embedded in the helper and retained in the sibling input inventory.

## Registration boundary — explicit blocker for physical interpretation

The official Polycam export is not supplied aligned to the camera poses; it is a visualization mesh. The retained stage37 transform is **a historical fitted comparator, not official calibration**. Its `register.py` loads the old Open3D phone TSDF and expresses it through historical `koivu_floorfix` R/t metadata before the fixed high-wall/floor fit. No FARO or route result enters that fit, but the target is still an experimentally estimated level frame, and reserved checks share the capture. `REGISTRATION_AUDIT.json` identifies the exact source/member/hash and lines.

This worker reads neither corrected occupancy nor corrected poses and does not refit anything. It reproduces the already-supplied registered endpoints and source transform as **diagnostic inputs only**. Exact transformed byte matching does not establish original camera-to-Polycam alignment, calibrated gravity/floor, body localization or authority to fuse raw depth physically into that mesh. If root excludes even this historical estimated-frame comparator, withhold this arm; the original unaligned camera anchors cannot simply be reused on raw OBJ coordinates.

## Scene-input adapter

`run_comparison.py` only replaces scene inputs around existing code:

- Original18,398vertices/29,366triangles, no reordering, winding change, cleanup, floor surgery, scaling or refit.
- Preserved source-only proper-rigid stage37 OBJ→level mapping, then `[levelX,levelZ,-levelY]`. Requires exact historical transformed Float32 vertex bytes and Int32 triangle bytes **before constructing the native engine**. If the existing input representation cannot reproduce those bytes, fail and inspect; never relax the expected digest.
- All seven fixed requested objectives:92→120→200→220→20→92,130→160,160→130. Preserve requested XYZ, native projections, every native failure and requested connectors. An incomplete/association-failed native route has no invented complete connector chain.
- Current already-built Coffee002 `Native(...,exclusion=False)`, unchanged stage55 `build_graph`, unchanged current `selector.select` using SciPy. No historical custom search or extra framework. One graph, seven requests. If a required anchor cannot associate, retain **all** native baselines and report all grid arms unavailable instead of dropping the difficult objective.
- Fixed proposal settings: radius.225m; height1.75m; cell size/height/climb.025m; slope15°; explicit20/30/20cm association query half-extents and≤10cm horizontal displacement. Zero marked exclusion spans required.
- Declared actual body remains**.45×.30×1.60m with separate.15m horizontal margin**, not the native disc/height. The worker does not validate that body. Retain current unfiltered shortest-grid cap`1.5×shortest+.5m`, current tier/exposure constants, full-XYZ requested connectors and no smoothing.
- Coffee's manual windows cannot transfer. No Koivu window, coverage polygon, semantic floor or source tabletop hull is fabricated. Manual-repair/joint-cost arm is explicitly unavailable, not implicitly replaced with unfiltered results.

This is **not** a complete unchanged-policy physical replay. It prepares historical-estimated-frame geometry candidates for the existing independently admitted full-body/contact/support workflow. A future authoritative camera-world mapping arm must instead use original depth with the documented pose/camera convention in its own world frame; this visualization-mesh comparator cannot establish that alignment. Even valid candidate routes retain`physicalAuthority=false`,support unknown and body validation not established. Continuous table/doorway/return movement, same-actor handoff, winding and current sensing require separate checks; camera anchors are not body ground truth. Earlier phone-map failures, VARPU support failures and later assisted zero-margin successes remain in the sibling inventory and must not be relabelled.

## Source freeze, after exact extraction

```sh
python -B research/conference-replay-source-20261029/freeze.py \
  --source-dir /workspace/scratch/90f3f6703064/conference-source-recovery/extracted-001 \
  --work-root /workspace/scratch/90f3f6703064/conference-source-comparison-attempt-001 \
  --manifest research/conference-replay-source-20261029/SOURCE_PINS.json
```

The freeze uses only the Python standard library and hashes the exact original source, transforms, requests, current adapters and runtime metadata. It refuses an existing manifest or output directory. It does **not** admit native execution. The prepared `run_aggregate.py` reuses the Coffee supervisor with seven-objective terminal checks and unchanged 120 CPU second / 180 wall second / 1 GiB observed RSS / 16 MiB output caps. Root must review and commit the final manifest and source before explicitly admitting it. See `AGGREGATE_PROTOCOL.md`, `GUARD_ADAPTATION.diff` and `GUARD_REUSE.json`. No automatic native invocation is provided.

No tests or extraction were run during preparation. Python AST parsing is a syntax check only. No stage/commit/push performed by this child.
