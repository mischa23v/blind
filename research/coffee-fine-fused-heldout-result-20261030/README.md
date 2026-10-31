# Fine fused-map held-out comparison: improvement, but substantial tails and unknown coverage remain

**The fixed 2.5 cm fused map improves observed-ray agreement on the same held-out pixels compared with 5 cm. Some difficult coarse hits also disappear, so the full conditional statistics overstate improvement unless the hit sets are separated. The primary conservative test still scores zero rays.**

No source points, supplied poses, occupancy probabilities, held-out frames, grid or residual definitions changed. The worker first reproduced the exact original 5 cm fused map and both its primary/observation-only held-out evidence, then closed it and built the fine map. All scoring queries remained read-only.

## Full observation-only results

Entry residual means predicted first occupied voxel-box entry minus measured held-out axial depth. Smaller absolute residual is better agreement with those pixels, not independently verified physical accuracy.

| Held-out view | Valid grid rays | Observed hits 5 cm → 2.5 cm | Absolute median | Absolute p95 |
|---|---:|---:|---:|---:|
| 232 | 9,593 | 2,654 → 2,406 | 10.84 → **4.92 cm** | 92.35 → **79.91 cm** |
| 370 | 9,311 | 7,404 → 7,184 | 9.34 → **4.74 cm** | 99.25 → **66.31 cm** |

These are **visibility-unverified observation-only hits** from upstream `ignoreUnknown=true`. Neither a returned hit nor absence of a hit certifies intervening free space. Long-tail disagreement remains substantial.

## Same-pixel and lost/new-hit audit

A separate saved-array audit matched exact pixel indices, verified array hashes, reproduced metric distributions and checked every status/endpoint denominator. It did not load the mapping library or read dataset rasters.

| View | Common hits | Lost coarse hits | New fine hits | Neither resolution hits |
|---|---:|---:|---:|---:|
| 232 | 2,406 | 248 | 0 | 6,939 |
| 370 | 7,174 | 230 | 10 | 1,897 |

### Common pixels only

| View | Absolute median 5 cm → 2.5 cm | Absolute p95 5 cm → 2.5 cm | Improved / equal / worsened pixels |
|---|---:|---:|---:|
| 232 | 10.21 → **4.92 cm** | 88.26 → **79.91 cm** | 1,762 / 179 / 465 |
| 370 | 8.94 → **4.75 cm** | 92.90 → **66.34 cm** | 5,337 / 765 / 1,072 |

The same-pixel improvement therefore remains after removing hit-set selection effects. It is not uniform across pixels.

### Hits that disappeared or appeared

- View 232's **248 lost coarse hits** had absolute residual median **80.92 cm**, p95 **145.38 cm** at 5 cm.
- View 370's **230 lost coarse hits** had median **59.47 cm**, p95 **131.46 cm** at 5 cm.
- View 370's **10 new fine hits** have median **1.57 cm**, p95 **1.82 cm** at 2.5 cm.
- View 232 has no new fine hits; its new-hit distribution is null, not zero error.

Thus some very poor coarse predictions no longer hit an observed fine voxel within the fixed query envelope. This may reflect less voxel overreach, but it could also reflect reduced map coverage. **A disappeared hit is not verified removal of a false obstacle, successful clearance or proof that a real object is absent.** No missing hit is assigned zero residual.

## Primary conservative result and coverage

Both fine-map camera-origin cells remain unknown. The primary counts stay **9,593 + 9,311 = 18,904 origin-unknown rays, with 0 scored residuals**. Primary distributions are null. The original coarse primary records are preserved unchanged; secondary observations do not override them.

Endpoint pixel counts also change with resolution:

| View | Known occupied 5 cm → 2.5 cm | Known not occupied 5 cm → 2.5 cm | Unknown 5 cm → 2.5 cm |
|---|---:|---:|---:|
| 232 | 123,827 → 100,683 | 18,075 → 30,414 | 461,382 → 472,187 |
| 370 | 365,844 → 274,419 | 42,635 → 97,172 | 177,725 → 214,613 |

The full accepted-pixel denominators remain 603,284 and 586,204. Distinct-key coverage and hit/free conflict counts are separately reported in JSON; finer resolution changes the distinct-key denominator. These occupancy categories are not sensor accuracy percentages or route coverage. Unknown is never treated as clear.

## Actual sizing and resources

The fine fused map contains **2,006,545 nodes and 1,733,066 leaves**, within its separately frozen 2.2M enumeration bounds. It completed in **11.07 seconds wall / 11.10 seconds CPU**, peak RSS **378,888 KiB**. The explicit protocol used **1 GiB address space/RSS stop**, 120 CPU seconds, 180 wall seconds, one CPU and 32 MiB per-file limits. That is a separately allocated research envelope; previous 512 MiB protocols and their results/failures are unchanged.

Streaming canonical hashes and one resident map at a time were retained. Exact coarse reconstruction/evidence reproduction and before/after state, probability defaults and canonical payload equality passed. The actual fine size is now measured; no prospective size estimate is presented as a measurement. Resource success on this machine does not establish on-iPhone runtime, thermal behavior or battery cost.

## Interpretation

This is concrete evidence that changing the coarse occupied representation improves same-capture held-out reconstruction consistency without changing the data. It does not isolate or quantify hardware accuracy, and it does not establish a production resolution. Significant tails, reduced observed-hit coverage and unchanged unknown-first rejection remain unresolved.

No full-room navigation, child safety, stair recall, independent reference geometry, online localization or live obstacle-avoidance verdict follows. No new protocol or threshold is selected in this report.

## Evidence

- `RESULT.json`: byte-identical actual worker receipt, including coarse/fine map states and both modes.
- `audit_pairs.py`, `PAIRED_HITSET_AUDIT.json`: completed paired/lost/new-hit saved-array audit.
- `DERIVED_LOCAL_FILES.json`: hashes/sizes of four local derived arrays; no source rasters included.
- Source protocol: `../coffee-fine-fused-heldout-source-20261030/README.md`.
- Prior singleton result: `../coffee-resolution-ablation-v2-result-20261030/README.md`.
