# Independent phone-only compact-map source review

Reviewed 2026-10-26. **No remaining concrete blocker found for the single authorized bounded offline map construction.** This does not approve the proposed 100-run game, route selection, physical navigation, production observation admission or any safety claim. The reviewer inspected source/protocol and the owner's saved 17-fixture log only; no original frames, VTK, geometry experiments or tests were executed by the reviewer.

## Final frozen cut

| Item | SHA-256 |
|---|---|
| `FROZEN.json` | `d69e2c1bd61ebb61d307056e53f5c8b653e06eb9ae8189667fa425500461b350` |
| `MAP_PROTOCOL.md` | `f39aa7fe0cdb194c59ef552e24ed61cb6a32ff4908b583376fd6fc608ab5b774` |
| `map_builder.py` | `8495c38ea6bf8893d5c064510a5cf4e615071ec11676ee168468ea2b14d95ba2` |
| `run_map_bounded.py` | `3c8ffb83336300db56a6ca70aeca87f3d7426bf2a9a70e08a72cc4b74c9634b6` |
| `test_map_builder.py` | `98b2541ea3ac65755857da91aaab926ec2735117bb25378d8407cb28441a9321` |
| `unit-tests.log` | `59f13733a91b2956cda81367f273d759b2ea214fbb5089675e6714b204114be4` |

Frozen selection SHA is `125bdbe6831cb4e58c4ffe16b4c31d65463104d695758f68cf7339c59b8a811c`; extracted depth manifest SHA is `8795ad2625e49336031a6a826e8247b6cbcc8bb3867f7c27a640a89ee049c82c`; original phone pose SHA is `c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3`. The config lists only map/extraction code, protocol, phone selection/manifest and original phone poses. It contains no FARO mesh/alignment input. The manifest pins the 294 original PNGs individually.

## Reviewed behavior

- Original processed depth is converted from integer millimetres into nominal metres. Every nonzero pixel is projected with the source-reviewed half-pixel OpenGL convention and its checked original pose/intrinsics. Nonfinite projected endpoints are rejected before voxel-index conversion. Pixel accounting partitions the original raster into missing, initial-ROI inside and outside endpoints; aligned hit counts must equal initial inside counts. No stride, interpolation, artificial confidence, raw tracking or body extrinsics are introduced.
- Both stages retain positive endpoint occupancy. Per-voxel frame counts increment once per distinct input frame, not once per pixel. Actual minimum/maximum endpoint Y is retained. Repeated free observations cannot erase positive hits. The global provided-map computation is not progressive sensing or SLAM.
- The floor seed is a declared phone +Z assumption, followed by the fixed occupied-height mode and **three total fit-then-trim iterations**. The source checks rank-three designs, finite coefficients, retained counts/spans and maximum tilt; rejected fit points are not reintroduced. The resulting rigid app frame maps the estimated plane to Y=0. It is not measured gravity or a physical floor estimate with a known error bound.
- Surface support requires all four horizontal quadrants and at least two source frames per supporting voxel. The explicit ground band is ±0.03 m. Positive body-height overlap uses strict `maximumY > 0.03 && minimumY < 1.75`; the below-floor contradiction uses strict `minimumY < -0.03 && maximumY > -0.25`. These frozen modelling cutoffs are not claims that hazards outside the classified intervals do not exist. All endpoint voxels remain available.
- Free coverage uses actual minimum depth over a complete 3×3 neighbourhood, without filling zeros, and the frozen inverse projection/index rule `floor(u+0.5)`. All 90 finite samples are required for an unblocked supported cell's declared 1.75 m clearance. Unknown clearance remains null and is explicitly ineligible for Recast and travel. `floorUncertainty` remains null, not zero. Existing `NavigationSurface` requires non-null floor and clearance; `StoredTerrainPolicy` explicitly limits null uncertainty to stored geometry, never physical clearance.
- Seventeen saved analytic fixtures passed, covering projection/pose, all-pixel inclusion, low/overhead endpoint retention, invalid pose, free margin, zero/border/range failure, plane fit/rank, exact band/top/below-floor boundaries, quadrant support, distinct-frame accumulation and one-of-90 missing coverage. These fixtures are not recorded scene or safety trials.

## Resolved execution/provenance findings

The original draft dynamically recorded its own pins and only checked budgets while the child was alive. The final version instead requires the externally supplied exact `FROZEN.json` SHA, verifies its listed files before and after, and reconciles manifest selection entries/order/bytes. Every depth is hash-checked when read and again before completion. The runner uses an exclusive `run-01` directory, performs cleanup on exceptions, and checks terminal waited child CPU/peak RSS, wall time, output and free disk in addition to live samples. There is no overwrite-capable publication rename.

Bounds are 600 child CPU seconds, 900 wall seconds, 2 GiB sampled/waited child RSS, 3 GiB child address space, 64 MiB outputs with a 64 KiB receipt allowance, and 768 MiB free reserve. Samples can miss short-lived peaks; these are not cgroup guarantees. The simple runner accounts for the one computational child, not an arbitrary descendant tree. The reviewed builder does not spawn descendants. A successful directory or intermediate map file alone is not release authority: require the successful terminal runner receipt and matching map hashes. Failures must remain visible, not become a subset fallback.

## Boundaries after construction

Finite sampled free points do not prove continuous body-volume clearance; the 3 cm floor band leaves unresolved small-height ambiguity; confidence, tracking, clock and mount are absent. A map can legitimately contain no usable route. That must not trigger threshold tuning, favorable start replacement or calling a stop a success. Freeze the resulting phone-only map before any route selection. The separate detailed-reference scorer may expose discrepancies but must never change this planner map. Root review of the exact game protocol remains required before any 100-run launch.

This is a completed source-review addendum. Keep it unchanged after handoff; place any run-result review in a separate file.
