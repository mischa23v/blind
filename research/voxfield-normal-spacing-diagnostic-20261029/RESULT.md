# One-pixel N2 normal-spacing diagnostic: repeated export artifacts confirmed

The fixed first three training frames show a strict four-pixel exported-depth pattern: **every unequal adjacent admitted-depth pair occurs at start-coordinate phase0 modulo4, in both image axes**. Phases1,2,3 have zero unequal pairs. This is direct evidence about the exported raster, not a claim about raw iPhone noise or an identified exporter implementation.

Actual unchanged N2 returns exact optical **+Z** for:

| Training frame | Exact +Z / valid normals | Fraction |
|---|---:|---:|
|00001|268118 / 427946|62.6523%|
|00002|270626 / 422413|64.0667%|
|00003|268486 / 425278|63.1319%|

Each exact-axis count equals its equal-depth center/right/down triplet count. Pooled807230/1275637 valid normals (63.2805%) are exact+Z. This exposes a spatial-scale mismatch: numerically valid one-export-pixel normals can describe replicated constant-depth blocks rather than underlying tilted surfaces. Sign is +opticalZ by the existing cross convention, not a toward-camera orientation claim. Frontoparallel real surfaces can legitimately yield +Z; no recorded per-pixel true normals were available, so these fractions are not measured normal error rates.

## Controlled analytic example
Plane .4X+.3Y+Z=2m;64×64 raster, first-record fx/fy, center31.5; same3969 valid interior samples in each arm:

- Unquantized points through actual N2 triplet: mean angular error0.00452776° (includes float/dot angular floor).
- Millimetre-quantized plane through actual N2 compute:7.98767°,61/3969 exact+Z.
- Same quantized plane sampled at4×4 top-left and repeated:31.605°,2304/3969 exact+Z.

This demonstrates a mechanism, not a model of unknown original sensor noise. Synthetic blockphase differs from exported phase; no phase was fitted or provider changed.

## Provenance and limits
MuSHRoom paper v3 §3.1.2 describes raw depth256×192 and RGB1024×768 followed by Nerfstudio crop/alignment/upscaling to994×738: https://arxiv.org/html/2311.02778v3 . Actual three PNG IHDRs are width738,height994,16-bit grayscale. Metadata and immutable raw inputs agree with this orientation. PNG header/hash only was checked here, not a fresh full PNG/raw decode equivalence; raw identities match prior conversion freeze. Exact exporter revision, interpolation, crop offsets and original raw confidence are not established. Fourfold periodic repetition is observed directly; nearest-neighbor export is consistent with it, not uniquely proven.

N2 source unchanged; no stride adjustment, classifier, smoothing, reference/heldout read, reconstruction or score performed. Prior mapping and mixed accuracy results remain unchanged. Next candidate must estimate a released normal method's physically meaningful support while preserving discontinuities/missing support and every admitted point; no gain or90% promise follows from this diagnosis.

## Bounded execution
Single reviewed run: exit0;1.735554952s wall,1.729225s final child+guardCPU,239452160B sampled summedRSS; within10CPU/15wall/256MiB/16MiB. All12 frozenpins unchanged. Sourcefreeze e426c7317ce113bae4e38f59dbcc19f182061f10081dceffb2f834175fc992a3. No active process or automatic next stage.
