# Exact seed-radius veto: reviewed execution admission plan

**Prepared, not executed.** Root owns publication/CI. Independent source review of the final manifest must pass before a compiler or new native query is run. No active checkout, upstream Recast, frozen legacy test, route endpoint, margin, or expectation has been changed by this candidate.

## Stage A: dependency-free C++ predicate fixtures

Use the five candidate production files over exact base `2c390d9c5096bba7af6d34c33329a9dc55a375b6` in an isolated source overlay. The new private header is automatically included by the existing `clearance_adapter.cpp` translation unit; no Package.swift membership change is needed. It uses released Recast allocators/structures and no new external dependency.

The data-only `tests/prepare_frozen_fields.py` verifies the unchanged 5.3 MB complete capture, all six full-layout hashes and existing mask hashes. It emits only a lossless input encoding for `tests/seed_radius_veto_tests.cpp`. Captured original areas, post-stock areas, columns, span heights, reciprocal connections, cell sizes and origin words are retained. Native fixture code reruns *stock* erosion and requires every area to equal the captured stock value before applying the candidate. Every resulting bit must equal the frozen mask. No recomputed oracle replaces those masks.

After review/admission, serially compile the authored test with the candidate private include directory and the unchanged `Recast.cpp`, `RecastAlloc.cpp`, `RecastArea.cpp`, and `RecastAssert.cpp` at the repository pin. Example command (paths substituted from the admitted overlay):

```sh
c++ -std=c++14 -O1 -ffp-contract=off -fno-rtti -fno-exceptions \
  -I "$CDETOUR" -I "$CDETOUR/upstream/Recast/Include" \
  tests/seed_radius_veto_tests.cpp \
  "$CDETOUR/upstream/Recast/Source/Recast.cpp" \
  "$CDETOUR/upstream/Recast/Source/RecastAlloc.cpp" \
  "$CDETOUR/upstream/Recast/Source/RecastArea.cpp" \
  "$CDETOUR/upstream/Recast/Source/RecastAssert.cpp" -o "$SCRATCH/veto-tests"
"$SCRATCH/veto-tests" prepared/frozen_fields.txt
```

Admission budget: **10 aggregate CPU seconds, 15 wall seconds, 512 MiB, one process at a time** for local compile/test if root admits it. If infeasible or capped, preserve the partial receipt and move this fixture to the existing free Apple lane under a separately explicit cap; never silently enlarge a local limit. No downloads/install/build system activation in this staging step.

Twenty authored C++ fixture groups: threshold `R²−1/R²/R²+1` (including the chamfer-equality witness); independent seed-list oracle with null/nonzero area preservation, diagonal ties and perimeter; absent-column seed semantics; valid all-zero mask; eight typed unsupported topology/input cases; work-budget refusal before mutation; failure of each of four allocations; six complete captured layouts/masks. There are no passing native results for these fixtures yet.

## Stage B: actual Swift -> C ABI integration

Five authored selectors in `tests/SeedRadiusVetoAppleTests.swift`, to be added to an explicitly reviewed hosted/test target (not silently presumed discovered):

1. `SeedRadiusVetoAppleTests/testExactPolicyRequiresClassifiedStrictAdmissionAndBoundedBudget`
2. `SeedRadiusVetoAppleTests/testStockDefaultHasNoVetoReceiptAndFlatOptInNeverClaimsPhysicalClearance`
3. `SeedRadiusVetoAppleTests/testInsufficientWorkBudgetReturnsTypedRefusalNeverStockRoute`
4. `SeedRadiusVetoAppleTests/testTwoDistinctFloorHeightsRefuseRatherThanFlattenOrChooseOne`
5. `SeedRadiusVetoAppleTests/testAllObstacleClassificationCannotBorrowSlopeSupport`

These run the actual RoomMeshCandidateRuntime serial worker, Native bridge, C build/query and terminal discard. Verify exact test identities as well as count; never substitute source pattern checks or core aggregate counts. Keep default/diagnostics app compile, current hosted/UI inventories and source-identity checks. Existing 285 hosted inventory is unchanged until these five are deliberately integrated; do not report 290 discovery before evidence. Refresh stage85 reverse-layer pins only as a documented new candidate layer, retaining historical pins/receipts.

## Stage C: unchanged same-export route/oracle controls

Reuse the existing **two exact public packed geometries, six profiles, 25 requests, original Float32 values, body margins and collision oracle**. Freeze source identity against:

- `strict-endpoint-probe/PACKED_ROUTING_GEOMETRY.json` SHA256 `0731735bf24f198288efea26d79c8a29929d49b10d3be0637e9e15fb983c63b7`.
- `strict-endpoint-probe/REQUESTS_49A.json` SHA256 `e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51`.
- `native-strict-result-40791907324/RESULT.json` SHA256 `0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893`.
- Complete pre/post compact capture SHA256 `71761f53b3567b6ac5e09d38c95f9a015249062c35ee84ae0cbade1a1f1977e1`.
- Existing six-mask file SHA256 `13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a`.

Keep **50 original controls** (25 legacy + 25 strict) byte/bit identical to their frozen native result: path points, projections, complete/native status, typed endpoint refusals and source receipts. Add a separate 25-row candidate policy using `bn_build_classified_seed_radius`/`.exactFlatLayer(maximumSeedTests:10_000_000)` plus the unchanged strict endpoint query. Do not modify the old constructor to erase the intentional legacy failures. Do not port the scratch imported-mask hook or patch RecastArea into production.

Candidate acceptance is the same earlier EDT experiment: six prior complete/no-contact outcomes retained; two hall-corner profiles become no-contact under the unchanged continuous swept-body oracle; three supplied margin-overlapped starts still refuse strict admission; fourteen other failures remain failures; all 25 initial-contact receipts preserved. Compare all source/body/endpoint values. The complete expected mask counts are `2112→1910`, `354→234`, `1665→1221`, `0→0`, `3445→3257`, `4369→4022`. An unavailable empty mask/build is not a route. Native portability and these route claims are **pending**, not inherited from the old SciPy/scratch-hook success.

Record the new production C ABI receipts and compiled source hashes. The earlier run 40803064242 is supporting feasibility only. Existing legacy hosted contact failures must remain separately visible, not changed to green by replacing their tests or expected contacts.

## Scope after success

No current app/bench caller is switched to this policy by the staged five-file change. Any explicit caller selection must be a separately reviewed wiring change with strict endpoint admission, classified input, freshness/owner checks and unchanged independent live hazards. This corrects a **discrete retained-cell mask** only. It proves neither continuous source-wall clearance nor full-footprint floor support, missing floor recovery, navigation readiness, physical output authority, or safe independent use. Stairs, slopes, stacked or unequal-height layers refuse; no convenient-floor selection and no stock fallback.
