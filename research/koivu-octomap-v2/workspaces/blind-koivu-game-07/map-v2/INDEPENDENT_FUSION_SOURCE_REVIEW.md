# Independent recorded-map-v2 source review

**No remaining concrete blocker found for the already-authorized single bounded offline map construction.** This is not permission to launch navigation games or claim physical clearance. Read-only review of source, protocols, saved fixture log and file hashes; no recorded data decoding, native calls, rebuilds or tests executed by this reviewer. All existing frozen files remain unchanged.

## Exact reviewed cut

| Item | SHA-256 |
|---|---|
| `FROZEN.json` | `c2980ab5da6c841fe86b08542439ddb745b5f85c394efccf99f816d5371cc817` |
| `fusion_driver.py` | `1a1603872013b5e61e56f685d496c931b5791fe9f275cd1b96984444d6ebe44d` |
| `run_fusion_bounded.py` | `ea92946ca7c5f832768dafe2f32a6cfcbf95a0d810abfe7e38d7dc0e94188011` |
| `surface_import.py` | `40c4a3b046c73096fd6e1f651ea1b2e982dc662f6a189e100cabbaea3d06a44e` |
| `FUSION_PROTOCOL.md` | `6380b326887957cff5998aedcb70c99f196f65fdc2a9bf3041bcce2065d6e283` |
| `IMPORT_PROTOCOL_PROPOSAL.json` | `4fe79a0805b619024f6df31e9a333b3f83f487be372f13b93f834cf252e95c2d` |
| `all-fixture-tests.log` | `9667a5f3a641c27715be61149ae8dc3d0a2afe655a431f411c5721d55ce1db1b` |

All **69 entries** in `FROZEN.json` were independently rehashed and match, including original v1 map artifacts, the original depth manifest, reviewed native build04/source/receipt, upstream sources/license and local import tests. Original frame hashes are transitively pinned through that unchanged manifest and checked before each decode and at completion by the driver. There is no FARO geometry/alignment, controller, route-selection or result-feedback input in the builder.

## Driver / association checks

The driver preserves the 294-frame order, original per-frame pose/intrinsics, all 215,670,168 nonzero pixels, original ROI, Float64 projection and exact saved v1 app transform. Per-raw-voxel hit totals must equal v1 exactly; missing/outside changes fail. Float32 endpoint and camera-origin conversion deviations are measured. Native defaults are queried and checked rather than inferred.

Each original Float64 endpoint is matched to its exact saved raw voxel. The same Float32 point array supplies native key conversion and insertion. A raw voxel's centre-derived key is included only after an actual member has that key; all differing member keys are retained as distinct pairs. A complete-association check plus original hit-count reconciliation prevents an omitted boundary key from silently reopening a voxel. The native engine retains its own occupied-key-set equivalence and actual-first-ray semantics. Recorded association does not assume Float64 and Float32 voxel boundaries are interchangeable.

The four saved association fixtures include an endpoint at `0.05 - 1e-10` that crosses a native Float32 key boundary while the raw Float64 voxel remains unchanged; both actual native keys are retained. These are small adapter fixtures, not physical-obstacle tests.

## Import / unknown handling

A raw positive obstacle ceases blocking only when **all** actual associated keys are complete, known, non-occupied by upstream classification and carry both positive hit-scan and free-scan evidence. Any occupied associated key blocks; unknown/incomplete/no-evidence associations remain unresolved and block. Native probabilities are retained for inspection, not re-thresholded in Python. Below-floor contradictions and missing original support still block.

Original floor/ground/support logic is reused from the exact pinned v1 source, not refitted or widened. Ground voxels later marked native-free are explicitly exported as conflicts, but the controlled v2 model retains the old floor prior. That prior is not current support or stair/drop safety; the 3 cm band and bounded below-floor rule remain unresolved limitations.

The driver recomputes the original 90 projected samples for **every newly eligible cell** using all original frames; absent v1 coverage rows are not promoted. Each sample additionally requires a native known, non-occupied node with positive free-scan evidence. One missing sample leaves clearance unknown. The output schema retains nullable floor/clearance and `floorUncertainty=null`; unknown clearance remains ineligible for travel.

The saved combined log reports **21 fixtures passing in 0.014 seconds**, including the four association fixtures and 17 classification/coverage cases. The import tests cover multiple native keys, missing/incomplete association, unknown and occupied priority, required hit/free evidence, unchanged raw support/contradictions, ground conflict reporting, missing sample coverage, malformed input and explicit lack of physical authority. These counts do not add recorded environments or navigation trials.

## Execution/provenance fixes and bounds

The final import protocol now names the exact reviewed native revision/binary and agrees with the code's `hitScans > 0` condition. The runner now includes its own CPU/RSS with the one computational child, plus terminal waited child usage and parent peak; the reviewed driver/native engine spawns no descendant process. Summing separate peak RSS values is conservative rather than an exact simultaneous peak. The legacy receipt key `waitedChildCPUSeconds` now contains the combined parent-plus-child CPU value; do not misdescribe it as child-only.

The single run is bounded by 600 CPU / 900 wall seconds, 2 GiB observed parent-plus-child RSS, 3 GiB child address space, 64 MiB output with receipt allowance, and 768 MiB disk reserve. Exclusive output creation, expected frozen-config SHA, before/after source checks, per-frame hashes, terminal output/free checks and cleanup preserve failures. These are sampled/terminal checks, not a cgroup or a universal arbitrary-descendant supervisor. The reviewed dependency path is serial.

## Result boundary

A successful construction would establish only an offline occupancy-model artifact. Default OctoMap weights are not calibrated sensor confidence; source tracking, time, mount and measured gravity remain absent. Finite samples and voxel cells do not prove continuous body-volume clearance or tiny-object/drop preservation. A useful fixed map must precede separately frozen phone-map-only routes and the independently reviewed game protocol. No favorable subset, outcome-driven parameter change, hidden reference input or standing-still success is authorized here.

This review is complete. Keep it unchanged after handoff; put subsequent result review in a separate addendum.
