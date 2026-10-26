# Preregistered production depth-admission audit — fixed recorded inputs

Authorized scope: the unchanged production `NativeDepthObservationPolicy.acceptedDepth(Float, confidence)` on the same genuine iPhone recording, frames **0–7 only**. This tests deterministic scalar admission, not obstacle detection, avoidance, floor/body clearance, tracking, localization or navigation.

## Inputs and execution

- Exact clip `EM1-0387.r3d`, SHA-256 `aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4`, pinned dataset revision `a285cd1249fe9762085713a1c796ab68b1810ac2`.
- Use only previously audited decoded Float32 little-endian metre arrays and original UInt8 confidence arrays. Verify their hashes against the field-audit receipt before and after execution. Load Float using its original 32-bit bit pattern; no uint16-mm quantization or confidence replacement.
- Invoke the real shared production function, not a Python reimplementation. Verify its exact source and built module against the prior verified production cut. The harness may add counting and byte transport only.
- Follow actual native sampler row/column traversal: start at zero, stride by the shared `pixelStride` (2) in each dimension. Each 256×192 frame has 12,288 attempted pixels; all eight have 98,304. The other pixels are unsampled, not rejected by policy.
- No poses, intrinsics, tracking state, floor seed, body profile, mesh, labels or goals enter this runner. Original timestamps remain provenance only and do not manufacture a timing/latency test.

## Counts and reason ownership

The actual `acceptedDepth` return decides admission. Count rejected values in disjoint explanatory order matching source guard precedence:

1. Confidence is not 2: separately report original0, original1 and other values.
2. Confidence2 but nonfinite depth.
3. Confidence2 finite depth below the unchanged lower bound.
4. Confidence2 finite depth above the unchanged upper bound.

Every attempted pixel must reconcile to admitted plus these rejected categories. Any unexplained mismatch with the production return aborts the audit. Accepted returned Double must exactly equal conversion of the original Float. Independently recount from unchanged source arrays only as a cross-check, never substitute those calculations for executing production code.

Record per-frame and aggregate counts, full/attempted/unsampled counts, source/binary/input hashes, compiler/runtime and any failures. Do not interpret low-confidence rejection as an obstacle miss, missing floor, hardware failure or safety success. This close tabletop clip is an input-format/component example, not a held-out navigation benchmark.

## Stop condition

Complete when the eight-frame actual production admission result and provenance are verified or an exact blocker is recorded. No threshold tuning, new perception/planner features, projection, route generation or navigation run. A separate protocol with independent obstacle/coverage labels and body/extrinsic/collision evidence is required before miss/clearance claims.
