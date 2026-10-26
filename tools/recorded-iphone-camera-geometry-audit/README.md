# Real recorded iPhone camera-relative geometry audit (stage 03)

This is a bounded component audit of the **same eight frames** (0–7) of CaryxAI `EM1-0387.r3d`, after the original-field/codec and production scalar-admission audits. It uses the existing `NativeDepthObservationPolicy.projection`, `acceptedDepth(Float, confidence:)`, and `DepthProjection.cameraPoint`. No detector, world pose, tracking state, gravity, body/mount transform, floor, goal or navigation state is supplied or constructed.

The preregistered protocol and convention/independent-reference requirements are in the separate `blind-raw-iphone-geometry-proposal-03` directory. Its original protocol hash is `c464922f1fa4799d83f9eef5da6fb0158a62df134777ff7218181aa6f196cfaf`. Historical proposal status text is retained; execution status is determined only by the subsequent receipt, not by this README.

## Existing local prerequisites

No install is performed. The driver requires an explicitly selected `WORKSPACE` and `SHARED`, the original first-eight decoded rasters and metadata with pinned receipts, the already-built/pinned native policy and Core support libraries/modules, the existing Swift 6.4.1 toolchain, and existing NumPy/Pillow/Matplotlib. Source/data/dependency hashes are checked before and after; actual loader paths are checked. The public source packet does not ship private frames, binaries, modules or the local toolchain. A clean-machine build is not claimed by supplying this audit wrapper.

```sh
# Select local roots containing the pinned prerequisites, not arbitrary new captures.
export WORKSPACE=/your/approved/workspace
export SHARED=/your/approved/shared
source "$SHARED/swift-toolchain/env.sh"
python "$WORKSPACE/blind-raw-iphone-geometry-audit-03/run_geometry_audit.py"
```

The driver refuses an existing `run` or `run.partial`; failures are retained. Do not delete a failed run to silently retry. Any changed source or protocol requires a distinct recorded source cut. The budget is 24 MiB new output, at least 768 MiB free reserve, 60 CPU seconds / 90 wall seconds, and 512 MiB sampled process-tree RSS; sampled RSS is not an allocator-level hard guarantee. It uses no network, GPU, scene renderer or new packages.

## Interpretation and inspection

- Original Float32 metre depth, UInt8 confidence, per-frame Float32-representable intrinsics, dimensions and original relative timestamps are preserved. No uint16-mm quantization, interpolation, hole filling, identity/normal tracking substitution or global-K reuse across frames.
- Numeric goldens and inverse residuals test **arithmetic conventions**, not measured sensor accuracy.
- Intrinsic-derived first-to-last-pixel-centre angular spans are not an independently measured hardware FoV. The admitted-ray envelope is not fully observed/free space.
- Per-image 8×6 tiles describe recorded pixels, not near-feet/head/body coverage. Low-confidence depth is not discarded from the original-array diagnostics but does not become an admitted native point.
- Each point scatter stays in its own camera coordinates. No inter-frame fusion/registration is performed. Camera Y up is not gravity up.
- The untouched original frame-0 JPEG is clearly separate from analytical depth/confidence/admission plots. Plot depth limits are display-only 0.15–1.25 m; unchanged native admission remains 0.15–5 m, confidence exactly 2.

Raw JPEG, point CSVs, analytical PNGs and binaries remain local; only source, aggregate numerical receipts and asset hashes are eligible for the publication packet. No actual hazard miss rate, physical clearance, collision-free walking, phone-only feasibility verdict or final phone-plus-belt hardware sufficiency can be inferred. Independent measured scene/visibility labels, body/extrinsics and timing truth are required for those later tests.
