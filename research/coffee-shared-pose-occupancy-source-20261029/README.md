# Three-frame Coffee shared-pose occupancy — source-only proposal

**Prepared, not executed.** The old Stage B camera-local experiment is unchanged. This candidate asks whether the same three retained full processed-depth rasters remain represented in one supplied-pose 3D occupancy map. It is not a held-out test, originalPolycam alignment, SLAM, room-completeness result, table-extent measurement, route acceptance or physical-clearance claim.

## Why the map has its own frame

The [official MuSHRoom release README](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/README.md#data-structure) explicitly says the released Polycam mesh is not aligned with its poses. Local metadata inventory of the checksum-verified archive found no mesh alignment metadata or FARO reference transform. The source-only audit is retained in `ARCHIVE_METADATA_AUDIT.json`; it does not contain photos, depth arrays, mesh vertices or host paths.

The [official iPhone converter](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/iphone_tools/1_nerfstudio_to_sdfstudio_within.py) loads the original `transformations.json` and changes OpenGL camera basis to CV by negating columns Y/Z. Thus `T_CV_to_P = T_frame @ diag(1,-1,-1,1)`. Transform endpoints forward with this matrix and use the unchanged translation column as the sensor origin. `camera_model: OPENCV` describes intrinsics, not CV extrinsic axes. The [embedded Polycam importer](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/mushroom_method/nerfstudio/process_data/polycam_utils.py) already maps raw world rows to `[2,0,1]`; this candidate performs **no additional world-axis permutation, centering or scaling**.

`P` is the original long-capture supplied-pose world. It is not the `originalPolycam` OBJ frame. No OBJ or authored mesh trajectory enters this experiment. A source-provided exact bridge or independently validated registration is still necessary before making that comparison. [PolyCam's raw-data specification](https://github.com/PolyCam/polyform/blob/ad0111832d3b3860e60efd8928e76f4fe97c8b72/README.md#rawglb-thumbnail-video-mesh_info) explains a column-major mesh alignment transform, but those bytes and proof of this exact OBJ export are absent here.

## Reuse and fixed batch

- `FRAME_SELECTION.json` was saved before controls were authored; its hash is pinned in driver and controls. Frames 00290, 00357, 00391 are the exact existing retained Stage B batch, **not the first chronological frames and not held out**. No frame is replaced after inspecting map results.
- Reuse the corrected `../coffee-table-retention-default-guard-source-20261029/retention.py` `project` function byte-for-byte through a verified import. Full 738×994 uint16 raster, original per-frame K, /1000 metres, strict positive axial depth below 4 m. No ROI, label, plane fit or floor filter selects mapper points. Missing/out-of-range rays generate no evidence; another valid ray may independently observe the same space.
- Reuse that sibling's identical rebuilt wrapper and explicitly supplied library SHA256 `0a044001b1455634ab881cc42fb5954362d960abf5cd851b7b6dc99b6c3eb963`. No compile/install/download. Actual prior native controls and Stage B receipts stay separate; they do not validate this new shared-world adapter.
- Keep original-pose/K choice explicit: this archive has 388 original long frames with per-frame K, versus 353 COLMAP frames with different shared K. The [pinned DN-Splatter iPhone utility](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/data/mushroom_utils/pointcloud_utils.py) uses COLMAP by default, the same camera-basis conversion, and an inverse only because Open3D integration consumes world-to-camera. We do not transplant its pose-file choice, training, meshing or resizing.

The new glue consists of standard-library rigid-pose validation/conversion, full-array transformation via the same scalar-tested arithmetic, one-tree sequencing and observation receipts. NumPy/Pillow and the prior native adapter are loaded only in the explicitly admitted run. The pure module does not import NumPy/ctypes or open any native library.

## Controls and execution boundaries

`test_pose_contract.py` contains 14 authored pure-standard-library controls: CV/GL direction; asymmetric rotated forward transform; origin translation; inverse round-trip and wrong-direction distinction; metric translation; the exact runtime column arithmetic; no repeated world permutation; absent/ragged/nonnumeric/nonfinite matrices; scale/shear/reflection/homogeneous-row refusal; missing per-frame intrinsics/shape; frozen batch/non-heldout binding; actual mapper argument AST; validation-before-native ordering; and standard-library-only pose imports. Tolerance `2e-6` checks float32-source rotation representation, not physical pose accuracy. Invalid poses are refused, not repaired.

The preparer AST-parsed all three Python files and checked launcher syntax. **No control suite, real-data transformation, native load or shared map has been executed.** Root must review and admit the exact new source before execution.

Prepared pure controls (no native load):

```sh
"$REVIEWED_PYTHON" -I -B research/coffee-shared-pose-occupancy-source-20261029/test_pose_contract.py
```

Only after source/control review, a separately admitted native run may use:

```sh
bash research/coffee-shared-pose-occupancy-source-20261029/run_bounded.sh \
  "$REVIEWED_PYTHON" "$RETAINED_DEPTH_DIR" "$ORIGINAL_TRANSFORMATIONS_JSON" \
  "$FROZEN_DIAGNOSTIC_DIR" "$PINNED_NATIVE_LIBRARY" "$FRESH_OUTPUT_DIR"
```

The launcher imposes TERM at 178 wall seconds and KILL two seconds later; the Python worker has 120 CPU seconds, 512 MiB address-space cap, single-CPU affinity, 175-second internal timer and 32 MiB per-file cap. It refuses direct invocation without explicit native opt-in/outer-guard marker, source/hash drift or existing output. The marker is an execution guard, not permission. Child subprocesses/builds are absent. Root retains command, exit/stdout/stderr, process retirement and outer resource evidence; a killed process may lack its final JSON and must never count as a pass. The 500,000 map-node/leaf ceiling is a resource stop, never an instruction to discard geometry or raise limits silently.

## What the proposed run records

One shared tree, 5 cm resolution, unchanged hit/miss/occupancy defaults. Adapter scan IDs 0/1/2 bind to the original frame names. Poses and depth hashes are checked before native loading. Each insertion receives all accepted endpoints and that frame's supplied sensor origin. The receipt records accepted counts, exact poses/conversion/origins, transformed-point hashes, Float32 conversion errors, native insertion counters and unknown control.

After every scan, query every retained frame's distinct endpoint keys and evaluator-only table keys, preserving known/occupied/not-occupied counts, hit/free contradictions, evidence maxima, probability ranges, and transitions from the immediately preceding scan. Never force prior hits to remain occupied: later free evidence may change their posterior. A current hit must add exactly one hit-scan vote, not one per interpolated pixel; it need not overcome previous free votes. No floor plane is fitted or supplied.

Local outputs are `RESULT.json` and geometry-only `occupancy_leaves.npz` (known leaf XYZ, size, occupancy probability, log odds and hit/free scan counts). Unobserved volume is not exported as free. Completion means the observation sequence finished, **not validation passed**; contradictions and losses remain visible. Data and numeric map artifacts remain caller-local and are not included in this source publication packet.

## Next gate, not implemented here

Held-out non-table walls/furniture, with preregistered distinct views and adequate overlap, must check pose-world consistency before table-boundary claims. The same frames cannot independently validate the map they populated. Same-capture agreement is not independent physical calibration. Inset table rectangles establish neither corners nor complete extents. Any later route needs measured support, full-body clearance/unknown treatment, localization uncertainty, coverage and hazard checks in the **same** frame; it cannot inherit originalPolycam paths.

Data: Xuqian Ren et al., [MuSHRoom iPhone Basic Data](https://zenodo.org/records/10230733), CC BY 4.0. Original files remain unchanged/local. See `PROVENANCE.json` for separate upstream code, dataset and adapter bindings. No raw photos or personal data are included.
