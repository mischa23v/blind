# Full265 D1+N2 adapter — source preparation only

No build, C++ test, recorded depth/RGB read, or mapper execution performed by author. Parent/root admission and independent review required. Earlier prefix source left unchanged.

## Interface / frozen input
`adapter original_frames.txt existing_new_output_directory expected_sha256.txt`

Original manifest is exact 25-field/265-row training manifest at `coordination/remaining-mapping-baselines/stage-d-full265/run/inputs/frames.txt`, including held-out gaps. Adapter preserves given ID/order rather than fabricating consecutive IDs; duplicate IDs, extra rows, or malformed metadata fail. External driver must cryptographically pin manifest and expected hash file before execution; merely any 265 IDs is not a certified original dataset. Expected hash file has exactly 265 unique `id depthsha rgbsha` rows, lowercase SHA256. First pass must match these external frozen hashes. The same actual loaded depth/RGB buffers are hashed again in each arm.

## Streaming / identity / failure closure
1. Shared prefix negative/positive validators and SHA256 known vectors run before any engine. SHA vectors: empty, abc, 'a' repeated55/56/63/64/65/128/1,000,000; expected values derived offline using Python hashlib on synthetic strings only. Tests have not yet run.
2. Pass1 loads/preflights each frame then destroys all arrays. Retains only immutable metadata, exact deterministic ledger signature (excludes timing), depth/RGB hashes. All265 must pass before first engine construction.
3. Each arm reloads/preflights one frame, compares actual raw hashes and full deterministic ledger to pass1, integrates only after exact match, and destroys arrays. No invalid frame is skipped. B, C0, C1 each start with empty maps; each arm retains one native integrator/map across all265 frames. No TSDF reload or gradient-loss serialization.
4. Per-frame native state scan checks finite distance/weight/gradient norm and nonnegative weight, nonempty observation; reports timing and allocated/observed/unknown/gradient counts. Submission counters are not independent integrated-point counts. Any failure marks all partial logs/meshes diagnostic-only/quarantined; runner must enforce quarantine for crashes/caps too.
5. Final native meshes only, no ESDF or TSDF export. PLY remains diagnostic until the entire guarded process passes. No hazard or geometric accuracy claim from successful construction.

Preflight retains prefix finite properSE3 tolerances, native quaternion/float roundtrip checks, |translation component|<=16m precision domain, full raster original per-frame K, Cgl→optical right multiplication diag(1,-1,-1,1), integer pixels, RGB association, 0<depthmm<4000 mask, sensor ray<=5.055m whole-frame failure, inverse-square weight positivity/bounds, all-normal reason counters/crossmatrix, world/scaled DDA interval/index bounds, nonempty rays. Original full pixels admitted; no angle/normal-validity thinning, calibrated confidence, floor classifier, ground truth input, or clearing. Preflight certifies original point inputs, not every internal native merged representative or world-ray condition after bundling. N2 valid means numerical normal construction only, not reliable surface confidence.

## Native configuration versus frozen stock baseline
Compared source `coordination/remaining-mapping-baselines/stage-d-full265/adapter.cpp`:
- Same .04m voxel,16 per block,.2m truncation,maxweight10000,carving true,minray0,maxray5.055,constantweight false,allowclear false,weightdropoff true,sparsity false,factor1,one thread,mixed order,anti-grazing false.
- `merge_with_clear=true` explicit here, matching the fork default; stock has no such Config field and always invokes its clear stage.
- B uses projective native Voxfield API/D1 core, **not identical binary to stock Voxblox**. C0/C1 use NP range exponent2,dropoff epsilon-1,reliableband2,normal ratio .1,curve assumption false; C0 `normal_available=false`, C1 true. All still receive same retained point set/colors; unavailable normals exactzero. NP-vs-B changes weighting/math, not a pure normals ablation. C1-vs-C0 also changes cached-gradient/grazing/correction behavior.
- Stock native pose roundtrip check2e-5 and properSE3 residual1e-5 versus inherited prefix gates1e-4 here; diagnostics disclose values, no pose repair. Root separately checks all265 pose translation extent against16m.
- Mesh exactly `min_weight=1e-4,use_color=true,integrator_threads=1,generateMesh(false,false),convertMeshLayerToMesh(...,false),outputMeshAsPly`. Added nonempty/finite vertex/index bounds validation. Stock additionally exported TSDF/ESDF; intentionally omitted here.

## Dependencies / budget / limitations
`sha256.h` is a thin wrapper around already present OpenSSL SHA256, not custom cryptography; existing libcrypto read-only reuse was approved by root; version/path/hash and ELF verification are required. No dependency install/download authorized. D1 isolated core/N2 header must be frozen by driver. Native source unchanged.

Proposed hard aggregate budget:300CPU seconds,420wall seconds,one worker,2GiB sampled process-tree RSS,512MiB new output disk. External guard must enforce caps; adapter does not claim to enforce resource ceilings. Four reads/hashes/preflights per frame (pass1 plus3 arms), about3.9GB raw traffic for738×994×5bytes×265×4, adds CPU compared to prefix. 795 map integrations and795 growing-map scans plus3meshes; prefix timings cannot certify full-scene success within cap. Stop/report cap rather than expand. At most one frame's raw/normal/provider temporary arrays resident, not265 clouds; native map growth and final mesh+mesh-layer+flattened mesh coexistence can dominate memory and remain bounded only by guard. No accuracy improvement or90% target promise. Evaluator is separate and unchanged.
