# Full 265-frame D1+N2 comparison: prepared, not executed

Run authority remains conditional on independent review and root admission of the final freeze. Proposed aggregate cap: **300 CPU seconds, 420 wall seconds, one CPU/worker, 2 GiB sampled RSS, 512 MiB new output**. No install, network, new native core build, GT input or score tuning.

## Immutable input and arms

Use the exact original 265 training rows/530 decoded depth+RGB files from the successful stock Voxblox full-run freeze. All 29 heldout IDs remain excluded. Preparation verified all 530 file hashes against the original receipt (971,982,900 bytes); no depth-to-point conversion or fusion was performed in preparation. Original dimensions, per-frame K, Cgl poses, integer pixels, uint16 millimetres, axial 0 < z < 4 m and RGB association are unchanged. The native optical conversion remains Cgl × diag(1, −1, −1, 1).

All arms share the isolated D1 core and unchanged N2 provider. B is projective; C0/C1 are NP with normal availability off/on. Every arm starts empty and keeps a persistent integrator/map through all 265 frames. No TSDF serialization/resume, injected free-space, semantic floor classification, crop, smoothing, hole fill, mesh repair or downsampling. Historical stock A remains unpatched and therefore confounded with D1: A-to-B is not an isolated normal comparison.

## Memory-safe streaming and identity

Holding all 265 point arrays would exceed the intended memory envelope. Instead:
1. Run shared negative/positive input validators and OpenSSL SHA256 known-vector tests.
2. Stream all 265 frames through complete preflight before constructing any engine. Preserve only metadata, deterministic ledgers and raw hashes; release each frame's arrays.
3. Stream each arm separately. Reload and revalidate one frame, compare its actual buffer SHA256 and deterministic ledger exactly against pass 1, then submit it. Abort on any discrepancy; never skip a frame or pixel. Release frame arrays after each update.
4. Inspect native finite state and nonempty observations after every update. Export each final mesh only with the stock mesh parameters below. A failure/cap quarantines all partial outputs, including completed earlier-arm meshes.

The source-only pose precheck covers all 265 records: largest translation component **4.715816 m**, below the unchanged 16 m numerical-domain limit. Runtime native quaternion/rotation, weights, point/ray/index bounds and all other premises must still pass for every frame. `MERGED_DOMAIN_SCOPE.md` limits extension of the earlier argument to these independently checked records/settings; it does not authorize arbitrary future inputs.

## Parameters versus existing stock full265 baseline

| Setting | Historical stock A | New B | New C0/C1 |
|---|---|---|---|
| Core | Voxblox c8066b… unpatched | Voxfield 78ee640… + D1 | Same D1 core |
| Integrator | Merged projective | Merged projective | Merged non-projective |
| Voxel / block | 0.04 m / 16 voxels | Same | Same |
| Truncation / maximum weight | 0.2 m / 10,000 | Same | Same |
| Carving / allow clear / freespace points | true / false / false | Same | Same |
| Minimum / maximum ray | 0 / 5.055 m | Same | Same |
| Constant weight | false | false | false |
| Point weighting | 1/z² | 1/z² | 1/r², exponent 2 |
| Weight dropoff | true, stock formula | true, fork projective formula | true, epsilon −1 (voxel-size ratio) |
| Sparsity compensation / factor | false / 1 | Same | Same |
| Threads / order / anti-grazing | 1 / mixed / false | Same | Same |
| Merge clear stage | Always invoked in stock source | merge_with_clear=true | merge_with_clear=true |
| Normal availability | N/A | N/A | false / true |
| NP reliable band / normal ratio / curve | N/A | N/A | 2 / 0.1 / false |
| Fast-only defaults, unused by Merged | subsampling 2; collisions 2; clear checks 1; max float time | Same | Same |
| Mesh minimum weight / color / threads | 1e−4 / true / 1 | Same | Same |
| Mesh generation | generateMesh(false,false) | Same | Same |
| Mesh conversion | convertMeshLayerToMesh(...,false), no proximity merge | Same | Same |
| Export | Native ASCII PLY | Same | Same |
| TSDF/ESDF export | Stock also saved layers | Omitted | Omitted |

All three `MeshIntegratorConfig` fields are explicitly matched. Point/domain safeguards differ from the historical thin adapter: proper-SE3 and roundtrip tolerances remain the reviewed prefix's 1e−4 versus stock 1e−5/2e−5; actual residuals are reported, with no pose repair. Source formulas and D1/N2 differences are disclosed rather than presented as binary equivalence.

## Dependencies, output and cost

Reuse existing headers and D1 library read-only. Root approved existing system OpenSSL 3.5.7 (`libcrypto.so.3`, Apache-2.0) for SHA256; exact header/library/version hashes and runtime ELF closure are required. No custom crypto implementation or install.

The full historical stock run took about 65 s including its exports, but that is not a guarantee for these arms. This design adds four raw reads/preflights/hashes (~3.9 GB traffic), 795 integrations/state scans and three meshes. Prefix timings suggest the 300/420 ceiling is plausible, not assured. Map growth and temporary mesh-layer/flattened-mesh coexistence may dominate RSS. The single guarded process must stop at caps; no frame reduction, threshold adjustment or automatic retry.

Only final native PLYs and source/counter/resource receipts are produced. Output admission requires all arms, exact frame order/counts, original pixel counts, finite states, unchanged input/source hashes and complete guard success. Output hashes are frozen for a **separate** unchanged first-hit evaluator admission; this mapper neither reads heldout geometry/GT nor scores itself. No accuracy improvement is claimed from successful fusion or a higher observed-voxel count.
