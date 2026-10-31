# Additive OctoMap read-only ray query — unbuilt source

**Prepared, not compiled or executed.** Twenty-two new synthetic controls are authored, not passing. The original sixteen native occupancy/endpoint controls remain byte-identical and are included in the proposed guarded runner. No held-out image/depth was extracted or read. This packet does not implement the real-data evaluator or confer physical authority.

The two metadata-selected views remain **frame_00232 and frame_00370**. Their frozen selection is `../coffee-heldout-pose-overlap-plan-20261030/HOLDOUT_SELECTION.json`, SHA256 `739c9c3fc7eeeb4a3598ce3e1a011222d6f415d2e47a335999e4f6be658fabfc`. Neither this adapter nor its controls selects or loads those views. The earlier midpoint draft is retained separately.

## Ownership and upstream reuse

`readonly_rays.cpp` **includes the original published adapter source in the same translation unit**, then appends three C functions. It uses that actual `Handle`, `checked()`, `error`, `packed()` and owned `OcTree`; it never casts an opaque handle through a separately guessed structure layout. Original adapter SHA256 is `715b3e544dff913a82ec43f49c0255297af0c3a799397faceaa66ebe97f9dff7`.

The extension calls the retained official OctoMap 1.10.0 implementation at `007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f`: `castRay`, `getRayIntersection`, `coordToKeyChecked`, `search`, `isNodeOccupied`, and tree-count methods. It does not implement traversal, insertion, clearing, plane fitting, tree reconstruction/import, SLAM, or scoring thresholds. Existing OctoMap BSD-3-Clause notices remain in the retained dependency. See `SOURCE_PINS.json` and the [selection/implementation plan](../coffee-heldout-pose-overlap-plan-20261030/README.md).

For a future reviewed build, take the existing serial build recipe and **replace its single `octomap_adapter.cpp` input with this `readonly_rays.cpp`**; retain all official source inputs, include path, flags and compiler pins. Do not compile both adapter translation units, which would duplicate exported symbols. Use a fresh owned output directory and a new binary SHA256; never overwrite the existing library `0a044001b1455634ab881cc42fb5954362d960abf5cd851b7b6dc99b6c3eb963`. No build command has been run here, and build-recipe/guard admission remains a separate root gate.

`ray_binding.py` imports a private, hash-verified copy of the original Python wrapper and explicitly binds it to the **separately reviewed candidate path/hash**, following the existing original-control runner's rebuilt-binding pattern. The original wrapper file and its expected old binary remain unchanged. Callers must supply the externally admitted hash, not compute a hash from an arbitrary file and use that as approval. New methods hold the existing owner's lock and reject a closed owner. The C result struct size is checked before use.

## API and semantics

- `om_ro_result_size()` exposes the result ABI size.
- `om_ro_state(handle, uint64[6])` exposes scan count, tree nodes, leaves, evidence keys, total hit votes and total free votes. These are diagnostic counts, not confidence percentages.
- `om_ro_rays(handle, origin, directions, maxRanges, count, output)` accepts at most **256** rays with one origin. Each range must be finite and **0 < range <= 8 m**. This is a query resource/input bound; out-of-bound values are refused, never clamped or silently shortened.

All output records are initialized. Per-ray statuses distinguish **hit through a known prefix, unknown origin, occupied origin, unknown before a hit, range exhaustion, invalid input, conservative bounds rejection, failed voxel-entry intersection, and unresolved native failure**. Fatal owner/buffer errors return the adapter's existing failure mechanism. Invalid queries do not retire or mutate the map owner. The bounds check conservatively requires the query sphere plus one voxel diagonal inside the native key domain, avoiding overflow ambiguity; refusal is not an occupancy fact.

Every traversal calls `castRay(..., ignoreUnknownCells=false, maxRange)`. Unknown is never skipped or recast as free. Occupied or unknown origin is reported separately and never yields a scored zero-distance hit. On false return, range classification reproduces the upstream float subtraction/product and double accumulation, **before** checking the terminal node, matching upstream ordering. A remaining ambiguous failure is unresolved, not “clear.”

### Center versus voxel entry

Official `castRay` returns the center of its terminal voxel. That center need not lie on an oblique camera ray. Its `maxRange` test is also **center-based**: a voxel face may lie inside the range while its center is beyond it, producing range exhaustion. This censoring is preserved, not patched with a guessed extra distance.

For a genuine occupied hit reached through known space, the extension calls official `getRayIntersection(..., delta=0)` and returns the voxel-entry world point, separately from the center. Both `centerProjectedRange` and `entryProjectedRange` are signed projections onto the input ray's normalized direction in metres; the entry is the candidate depth-comparison location. Original upstream intersection precision/tolerance remains unchanged. Invalid/unscored entry values become JSON-safe `None` in Python, never zero residuals.

The future evaluator must convert the entry using the inverse of the **same original supplied camera transform** and compare axial `predicted_z − recorded_z`, with Euclidean along-ray residuals separately. It must publish coverage denominators, refusal/status counts and full signed/absolute distributions—not a safety-confidence percentage, fabricated pass threshold, or clearance claim. At 5 cm resolution, voxel-entry residuals are discretized observations rather than surface truth.

## Authored controls and proposed runner

The twenty-two new controls cover: unknown origin; axis-aligned hit and center/entry distinction; unknown gap before a distant known occupied cell; occupied origin; known-prefix range exhaustion; center-based range censoring; invalid/non-normalizable directions; invalid ranges; invalid origin versus native bounds; oblique voxel entry; complete status partition; exact non-mutation of state/defaults/export arrays; pre-conversion batch cap; shape refusal; empty typed batch; closed owner; invalid query not retiring or adding a scan; Float32 boundary/key equivalence; maximum batch; and audit counts matching exported evidence.

`run_controls.py` preserves the original test source SHA256 `d1e032ae6be16dbb99255118d1776b0df14ec5c5ffc3271bb47867ed4a434fd5` and requires inventories of **16 original + 22 new** tests. It verifies the source manifest, original adapter/test pins, candidate library, and a separately reviewed build receipt before loading native code. The expected receipt fields are:

```text
success: true
exitCode: 0
librarySHA256: <new exact candidate hash>
adapterTranslationUnitSHA256: <readonly_rays.cpp hash>
includedBaselineAdapterSHA256: 715b3e544dff913a82ec43f49c0255297af0c3a799397faceaa66ebe97f9dff7
sourceManifestSHA256: <this packet manifest hash>
```

These source/binary bindings do not replace reviewing the actual build guard/resource receipt. Root must also externally check the exact manifest immediately before execution; a manifest cannot authenticate itself.

The prepared `run_controls_bounded.sh` requires explicit interpreter/library/receipt hashes and fresh output. It imposes TERM at 178 seconds and KILL two seconds later; worker limits are 120 CPU seconds, 512 MiB address space, one CPU, 175-second internal timer and 32 MiB per-file cap. No subprocess, build or data extraction occurs inside the control worker. Preserve command/interpreter, stdout/stderr, terminal completion, resource evidence and the output JSON/log; a killed run is incomplete, never passing. This launcher has **not** been used.

## Remaining gates

1. Independent source review of this exact manifest and receipt/ownership contract.
2. Separately bounded fresh build from the retained official source, exact new binary/source/guard receipt, then the 38 controls. Authored code, AST parsing and shell syntax are not native success.
3. Review the two-member held-out extraction protocol before opening any new depth. Keep selected views fixed.
4. Implement/review the bounded real-data driver: recreate only the original three-frame map; require canonical baseline payload equality; query holdouts without insertion; keep unknown coverage and all residuals; prove before/after payload immutability. That driver is **not included** here.

Same-capture supplied camera poses are not trusted true-world calibration. No mesh alignment, support/clearance, localization, route acceptance, or physical guidance follows from these queries or future favorable residuals. No photos, rasters, map arrays or native binaries are in this source packet.

## Reviewed-build candidate, not executed

The interrupted source preparation already contained a double-domain admission check and two extra controls. This revision completes their manifests. It rejects ±1e30 and ±Float32 maximum origins on every axis before upstream coordinate-to-key conversion, and rejects a query envelope crossing native bounds. Rejection never clamps the query or mutates the map. Only the additive ray entry point is hardened here: unchanged baseline insertion/query entry points must continue receiving bounded validated coordinates.

`build_readonly.py` is adapted from the retained successful serial build guard, changing only source/output expansion and the variant label. `BUILD_RUN_PINS.json` preserves all original toolchain and source pins, swaps the adapter translation unit to `readonly_rays.cpp`, and includes all current packet source hashes. The fresh output is this directory's `build-readonly-01`; existing output is refused. Limits remain one CPU, 120 aggregate CPU seconds, 180 wall seconds, 1 GiB observed RSS and address-space backstop, and 50 MiB output. No native calls or controls run during compilation. The original restored library is untouched.

The source manifest excludes `BUILD_RUN_PINS.json` to avoid a circular hash. Root must externally verify both exact hashes before publication and execution. The build manifest is also required byte-identical to the admitted Git commit. No namespace, security-setting change, installation, download, or held-out data read is performed.

After reviewing a successful terminal guard receipt, run `finalize_build_receipt.py --expected-guard-receipt-sha256 <reviewed digest>` to create the compatibility receipt without loading native code. Its source/binary pins and guard measurements must be reviewed before the separately bounded 16+22 controls. Neither authored controls nor AST/shell checks count as native success.
