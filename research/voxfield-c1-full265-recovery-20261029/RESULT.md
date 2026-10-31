# Fresh C1 recovery: PASS for fusion, not accuracy

The separately authorized **C1-only, empty-map recovery completed all 265 original training frames**. It did not resume the terminated map or load a TSDF. The original three-arm batch remains RESOURCE_BLOCKED with its original global quarantine unchanged.

## Measured completion

- 164,771,607 original points submitted, with the same per-frame K, poses, full pixel order, depth/RGB hashes and admission as the historical stock run.
- All 265 initial preflight records passed before engine construction. Every C1 reload matched the frozen raw SHA256 and deterministic ledger; original pixel counts matched afterward.
- Nine unique SHA256 vectors plus two repeated checks and 36 input-domain selftests passed. Every native update had zero nonfinite/negative-weight state violations.
- Final native mesh: **1,346,553 vertices / 1,346,553 indices** (448,851 triangles), **96,197,461 bytes**.
- Mesh SHA256: `a4bcce0129592ac3b8320c8262f1280a95b365ddf5246c0e1f36c3deb9665fe7`.
- Final state: 1,167 blocks; 4,780,032 allocated voxels; 2,700,114 observed; 2,079,918 unknown allocated; 1,648,209 nonzero gradients. These counts are **not accuracy or safety metrics**.
- The first 245 completed recovery state-counter records exactly match the original terminated C1 prefix on frame/submission/block/observation/gradient/invalid counts. This supports reproducibility of those counters, not full map byte identity. No native run process remains alive.

## Resource and identity

**138.293384 s wall**, **138.149731 s reaped-child plus guard CPU**, **692,645,888 bytes peak summed RSS**, within the new 180 CPU / 210 wall / one CPU / 2 GiB / 256 MiB caps. The sampled CPU peak was 137.368477 s; final accounting includes integrity checks. Unlike the killed original tree, this successful run reaped its descendants normally.

All **960 frozen pins remained unchanged**, including the original failed-batch receipt. The selection-only source diff changed the arm loop and labels, not kernel, configurations, normal provider, inputs, preflight, mesh extraction or scoring. D1/N2 and OpenSSL identities/ELF closure remained fixed.

Admitted recovery freeze: `1133e6f57cbc47b056bc8154fc35a865408a5ed4287760fcbbc707d237c8d3f2`. Exact mesh/output hashes are in `run/FUSION_OUTPUT_FREEZE.json`; counts in `run/ORIGINAL_COUNT_MATCH.json`; resource, integrity and counter comparison receipts are retained.

## Admission boundary

The local recovery guard admits this C1 artifact **for subsequent independent review only**. It does not release B/C0, overwrite the original batch's failed admission or authorize scoring. Root must bind independently reviewed completed B/C0 artifacts and this fresh C1 output in a separate recovered admission. The scorer has been told to wait.

No reference/GT entered fusion, and no accuracy was evaluated here. Higher surface or gradient counts do not prove improved reconstruction. Small-object distinguishability, floor/drop support, uncertainty, pose drift, dynamic maps, continuous clearance and collision-free route tails remain unresolved. Original synthetic failures, resource termination, unavailable leak checking and native serialization gradient loss remain in the audit trail.
