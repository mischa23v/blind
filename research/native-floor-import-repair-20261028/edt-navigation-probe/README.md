# Fixed full-layer EDT navigation diagnostic

## Status and scope

The six full compact-layer captures and exact SciPy EDT masks were generated and independently reviewed. The Apple-host navigation probe is authored and source-reviewed, **not yet compiled or executed**. This is a bounded diagnostic comparison, not a production replacement, a complete pipeline benchmark, or evidence that our pipeline is better than another released system.

The original controls use the pinned released Recast/Detour implementation **through our existing adapter**, on the exact two public Apple sample fixtures captured by the iOS tests. They are not a claim to have benchmarked an unmodified end-to-end upstream application. The candidate changes only scratch erosion output by intersecting original walkable spans with a fixed exact Euclidean grid-seed mask. Endpoint policy, radius, margin, geometry, contour parameters, route extraction, and the independent source-geometry collision oracle remain fixed.

## Already executed evidence

- `capture-result/receipt.json`: one bounded observational C++ run, six profiles, 76,794 spans. All 50 legacy/strict CABI results reproduce the actual Apple strict probe's path/projection/status/association bits.
- `capture-result/FULL_CAPTURE.json`: 5,267,537 bytes, SHA-256 `71761f53b3567b6ac5e09d38c95f9a015249062c35ee84ae0cbade1a1f1977e1`. Retained locally, **excluded from the minimal publication packet**.
- `MASK_RESULT.json` and `MASK_RUN_RECEIPT.json`: one released SciPy 1.17.0 exact EDT mask generation, no navigation run. All retained-span distances were checked against integer seed-coordinate distances. No install or dependency download was needed.
- `EDT_MASK_INPUTS.json`: six fixed masks; SHA-256 `13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a`.

The mask uses `originalKeep AND EDT_squared >= original_R_squared`. It never promotes an absent, null, or originally removed span. Each complete layer is one common y-voxel level with reciprocal adjacency. The full column/span layout is hashed in an explicit little-endian representation. Outside-grid centers are seeds; absent interior column centers are not independently added as seeds. These are planar grid-seed distances, **not distances to continuous source surfaces**, and no half-cell/source-boundary allowance is assumed or applied.

Original/candidate span counts, by profile: `2112/1910`, `354/234`, `1665/1221`, `0/0`, `3445/3257`, `4369/4022`. The original Hallway wide profile legitimately has no retained spans and must not fail the receipt gate merely for that reason.

## Frozen Apple-host procedure

`NATIVE_SOURCE_PINS.json` pins all 58 runtime sources/headers/inputs, including the exact unchanged collision oracle and the prior actual Apple reference. `run_native.py` compiles the pinned original implementation with a scratch-only observation/mask hook. The repository's Recast and adapter sources are not edited.

1. Run 51 authored C++ hook controls. These cover full-layout identity, observation-only behavior, extra removal, zero-extra removal, wrong hashes, promotion refusal, malformed/partial phases, layer mismatch, invalid inputs, and reset. **Authored checks are not passing native tests until the artifact says so.**
2. Execute all 25 original legacy requests and all 25 original strict requests. Compare all modeled reference fields, including Float32 bit patterns and original/connector/route collision receipts, against the retained actual native result.
3. Only if all 50 controls reproduce, execute the same 25 requests with the fixed EDT mask and strict endpoints. The hook's post-build receipt must validate even when the build returns no handle, before any association/path query. No failed-mask fallback is allowed.
4. Declare the fixed candidate goals met only if six existing no-contact corridors remain complete/no-contact, both original corner-contact corridors become complete/no-contact, exactly the three projected-start cases retain typed refusals, the other 14 failed requests remain failed, and every initial source-contact receipt is unchanged. All raw outcomes remain in the report. Rejecting every request cannot pass.

The candidate still uses Detour's existing shortest funnel. It does **not** implement a center-clearance objective. Even a passing fixed-fixture result would not establish complete floor support, live localization, dynamic hazards, continuous source-clearance guarantees, or iOS production readiness. Existing negative contour and strict results remain unchanged.

## Execution and publication boundaries

The workflow file here is a candidate only; the root/CI owner controls any installation into `.github/workflows/`. Its guards permit only the exact public repository, master/recovery branch, standard free `xcode-27`, and installed Xcode 27.0. No paid/private runner, package install, or production activation is allowed. The runner uses serial compilation, a 300-second global deadline with refusal of late spawns, isolated process groups retired on timeout, and bounded text/JSON artifact uploads. A green diagnostic job may still report that the candidate failed its goals.

`MINIMAL_PUBLICATION_MANIFEST.json` is the exact proposed small-file packet; it excludes the large raw compact capture, binaries, caches, and unrelated MuSHRoom work. `PROVENANCE.md` and `PROVENANCE_RECEIPT.json` document only the two hash-pinned public Apple sample models and existing public GitHub test artifacts. No user/home capture, room photo, personal memory, or personal pose is included. The sample models happen to be named Bedroom3/Hallway2; they are not user scans.

No further EDT variants or parameter tuning are authorized by this packet. Broader comparisons with released systems remain necessary and take priority over treating this diagnostic as a winning pipeline.
