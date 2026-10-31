# Proposed bounded serial qualification — NOT RUN

This is new source after a workspace reset. The missing prior candidate's reported 34 mask comparisons / 20 refusals do not establish anything about this version. No results are inherited. No app activation, navigation caller, route query, device/child trial, downloads, installations, API calls or spending are authorized by this plan.

## Source checkpoint before admission

1. Review and checkpoint the new helper, exact copied envelope dependencies, provenance and `tests.cpp` before compiling. Root owns commits/pushes.
2. Independently review dimensions, bounds, pointer lifetime preconditions, original seeds, released reciprocal overlap/climb admission, ownership snapshots, receipt identity, transactional failure and internal budget handling.
3. Verify old disk/flat helper/API/build paths remain byte-identical to the published base. The research helper is a distinct class and receipt, not a replacement policy.
4. Record complete compiler command/version, input SHA-256 hashes and exact source commit. Do not claim source comparison is execution evidence.

## Authored fixtures in tests.cpp

Planned 23 mask comparisons: flat, quantized ramp, ripple, climbable step, above-climb disconnected step, minimum-clearance ceiling center (h equals walkableHeight) and absent-column hole, each at radii 1/2/3; ripple with a null-area center at radii 1/3. Hole columns never become synthetic independent seeds; only surviving original spans adjacent to missing edges and the unchanged exterior perimeter seed the exact transform.

Each comparison independently packs original seed coordinates before unchanged released `rcErodeWalkableArea`; freezes that stock output; evaluates every present column against every seed using integer squared XZ distance `< radius²`; compares every final area byte, original seed byte, preserved cell/span byte and receipt count. It checks the envelope only removes stock-kept areas and a second apply refuses without modifying areas. Radius equality remains retained by the independent predicate (subject to stock exclusion).

Planned 37 refusal cases: 1 apply-before-prepare consumption regression, 13 invalid preparations (multispan, cell scales, finite/ordered bounds, indices, exterior/offset/nonreciprocal topology, climb/ceiling rule violations negative climb, and isolated below-height span), 3 work-limit refusals, and 20 apply mutations (scales, bounds, height/climb, cells, Y/H/connections, owner pointers and receipt fields/address). Every failed apply must preserve the supplied stock areas, consume the transaction and reject retry. Mutation field pointer ownership is restored before fixture destruction.

These are authored synthetic compact fields, not captured rooms, rasterizer integration, floor completeness, bodily clearance, runtime sensor evidence or independent navigation validation. They deliberately do not copy the old flat helper's rejection of nonconstant Y.

## Proposed execution admission

Only after review and separate explicit admission: one serial native compile plus executable under a single aggregate envelope of **60 CPU seconds, 120 wall seconds and 512 MiB memory**. No concurrent compiler jobs. Limit generated output to 10 MiB. Use an existing compiler only, no dependency installation. If the host cannot enforce/observe these limits, stop and report the limitation rather than weaken the envelope. Record peak RSS distinctly from an enforced allocation/address-space ceiling.

Compile from the repository root, using the already published sources:

```sh
R=research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/upstream/Recast
D=research/single-span-heightfield-rebuild-20261029
# Proposed only; do not run at source-checkpoint stage.
c++ -std=c++17 -O1 -g -ffp-contract=off \
  -fsanitize=undefined -fno-sanitize-recover=all -Wall -Wextra \
  -I"$D" -I"$R/Include" \
  "$D/tests.cpp" "$R/Source/Recast.cpp" "$R/Source/RecastAlloc.cpp" \
  "$R/Source/RecastAssert.cpp" "$R/Source/RecastArea.cpp" \
  -o <admitted-scratch>/heightfield-tests
<admitted-scratch>/heightfield-tests
```

The supervisor, not the C++ executable, must enforce aggregate compiler+test time/memory/output limits, terminate the whole process group on a breach, retain stderr and return exact exit status. `timeout` alone is not the full resource contract. No unbounded shell retries. Any failure creates a new source checkpoint and review before rerun; it must not be relabelled as a pass.

## Remaining evidence beyond this first proposal

Allocation-failure injection for every helper allocation, malformed dimensions and span limits, larger authored fields near storage/work caps, sanitizers beyond UBSan, and integration against actual `rcBuildCompactHeightfield` output are separate coverage gaps required before any API adoption, not optional evidence of readiness. No full-room body trajectory, platform build, route or device safety claims follow from this initial authored suite. Existing old-policy test source/results remain distinct and unchanged.
