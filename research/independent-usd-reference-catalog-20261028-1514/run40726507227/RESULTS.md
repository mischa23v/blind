# Actual same-export OpenUSD comparison — 2026-10-28, 16:50 UTC

## Result

**The first native rejection is a source-plane-versus-exported-solid validation mismatch. The same-file reference does not show a units, up-axis or source-feature transform error in these two fixtures.** This is narrower than proving every production-imported vertex or physical room measurement correct.

Official OpenUSD 26.5 read both exact retained USDZs. The native manifest binds these files to the Model I/O inventory of `SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleSameExportForOpenUSDComparison`, source commit `c4ffa28c07d0a17b513d123de3bec2fd8be93eec`, [native run 40726507227](https://github.com/mischa23v/blind/actions/runs/40726507227), artifact `12834885760`.

| Observed property | Hallway2 | Bedroom3 |
| --- | ---: | ---: |
| Authored meters per unit | 1.0 | 1.0 |
| Authored up axis | Y | Y |
| Meshes / vertices / triangular faces | 13 / 660 / 334 | 11 / 472 / 236 |
| Unmatched or missing original features | 0 | 0 |
| World transforms exactly matching original Float32 source | 13 / 13 | 11 / 11 |
| Source-anchor pairs with exactly preserved distance | 78 / 78 | 55 / 55 |
| First failed wall: native versus OpenUSD world-matrix difference | 0 | 0 |
| First failed wall: max world-bounds difference | 0.000000405142465 m | 0.000000283244759 m |
| OpenUSD wrapper elapsed time / peak RSS | 0.283 s / 100,808 KiB | 0.201 s / 100,328 KiB |

The meter values are explicitly authored; no centimeter fallback or guessed conversion was used. The Y-up convention is also explicitly authored. No scale fitting, recentering, axis rotation, normalization, topology repair or mesh merging was performed. Gf matrices are row-major/row-vector; native arrays are column-major/column-vector. The report accounts for this representation difference rather than treating arrays as identically applied matrices.

## What differs from the original RoomPlan surfaces

The original architectural source features are planar: their dimensions have zero depth. The exported file nevertheless contains solids and in-plane extensions:

- Walls and doors have approximately **0.16 m** local depth, usually from Z = 0 toward Z = -0.16 m.
- The window and both floors have approximately **0.08 m** local depth.
- Several walls extend approximately **0.16 m** beyond an original local X endpoint.
- **Both floors extend approximately 0.16 m beyond the original polygon min/max on all four in-plane sides**, as well as having slab thickness. This comparison uses original polygon corners, not only rectangular dimensions.
- Bedroom3's chair, table and bed retain local bounds exactly equal to half the original Float32 dimensions, and retain their original transforms.

Example: Bedroom3 Wall0 has source half-width `1.7720868587493896 m`, while the exported maximum local X is `1.9320868253707886 m`. Its local depth extends to approximately `-0.160002 m`. The original zero-depth source box cannot contain that geometry. The mechanism generating lateral extensions has not been inferred beyond observing their presence in Apple's exported asset.

The first native rejected vertices lie about 0.16 m off the source plane, versus unchanged numeric allowances of about 0.0000923 m (Hallway2) and 0.0001286 m (Bedroom3). Independent OpenUSD sees the same exported solid, so this is not resolved by swapping the vertex parser or guessing a unit scale.

**A thickness-only change is insufficient.** Blindly widening source bounds or epsilon would also accept generated floor area beyond the original polygon. Visual/export solids and measured planar support need a deliberate semantic contract before any routing resumes. This task changed no acceptance predicate, production adapter, path algorithm or physical-guidance gate.

## Scope and independent review

An independent reviewer directly reopened both SHA-verified original USDZs with official OpenUSD, separately from the reporting wrapper, and recomputed all 24 world transforms and vertex bounds using `XformCache`, `Gf.Matrix4d.Transform` and `Gf.Range3d`. Every mesh agreed with the retained reports. The reviewer separately confirmed all source Float32 transform matches, furniture dimensions, floor-polygon expansion and the two first-wall native bound deltas. See `INDEPENDENT_REVIEW.json`.

What this establishes:

- The **24 reference-imported features preserve their original source anchors and orientations**, and their anchor spacing does not drift.
- The two retained native first-wall witnesses agree with a separate OpenUSD read of **the identical files** to arithmetic precision.
- The source-bound predicate is being applied to exporter-provided thickness/extensions that are absent from the original planar representation.

What it does not establish:

- Full native per-vertex parity for every feature: the native numerical geometry witness stops at the first failed wall in each fixture.
- Byte identity with the production adapter's earlier export, which is separately generated and deleted. These are diagnostic-export pairs only.
- Real-world survey accuracy, measured wall thickness, complete room coverage, live localization, dynamic clearance or safe navigation.
- A fix for every visual issue the user reported, or permission to enable paths. Geometry-first investigation remains appropriate.

## Evidence and reproducibility

- `INPUT_MANIFEST.json`: hashes/byte counts/local paths of all seven verified native inputs, including collector receipt.
- `Hallway2-openusd-reference.json`, `Bedroom3-openusd-reference.json`: actual official-reader outputs, all feature matrices and local/world bounds, original source features, and unchanged native witness.
- `COMPARISON.json`: reproducible scalar/anchor/bounds comparisons from those outputs; generated by `../summarize_comparison.py`.
- `SHA256SUMS.txt`: output hashes.
- `../inspect_public_usdz.py`: reviewed exact-byte wrapper; verifies native source/manifest/inventory/hash chain, then calls official upstream import/transform/bounds APIs.

Exact USDZ SHA-256:

- Hallway2: `0c47630270348ded24ce0a4fe6a18f5defce5d445d8c7e109c932b56d812d232` (57,294 bytes).
- Bedroom3: `f808de2e0283b8b2aaea07ecc16e694222877c1452dd7203a321d84186345a67` (46,080 bytes).
- Native same-export manifest: `f37807c60966174724e4f3758c0b1b9d57e887e596377925de6a9aaebbc8bdf2`.

All comparisons used unchanged original public Apple fixture data. No private room, photo, family data, new reconstruction or invented mesh was admitted.
