# Per-box tiled VTK broad-phase, with original positive-contact fallback

## Measured reason for this cut

Frozen query-profile-16 measured native `FindCellsWithinBounds` at 41.35424 s of 42.41135 s whole instrumented sweep time (97.51%) on 40 fixed body/margin boxes. Zero-copy bounds filtering took 0.32155 s and nested owner checks 0.02067 s. Complete original/instrumented collision outputs matched. This cut therefore targets the measured native bounds bottleneck, not geometry simplification or more vertex changes.

## Semantics

Reuse the already-tested `ground-query-tile-13/find_cells_tiled` for the same transformed closed AABB and original triangle-ID union. Ground membership, affine bounds rejection, VTK exact predicates, conservative motion enclosure, body dimensions, 15 cm margin and tolerance remain unchanged. Invalid owner/cap/query states fail explicitly; never substitute empty candidates.

Sorted tiled IDs may change the order of the first-16 skipped-ground diagnostic preview for negative contact results. That preview is not a contact measurement or control input. All other old collision-result fields must match. If the prepass finds **any** non-ground contact, invoke the original frozen V6 method on the same box and return its full original collision result (with separate optimization-work metadata). This intentionally preserves original first-contact ID, height, near-foot classification, reason and counts. Positive cases may be slower; this is not hidden or called a speed improvement.

## Acceptance checks

Before recorded comparison, authored fixtures must cover negative, contained/positive, closed and tolerance boundaries, rotation/sweeps, margins, owner invalidation/caps, and multiple positive triangles with different native versus sorted first-hit order. Original geometry is not changed. Candidate-ID set equality follows the existing native-bin-union helper and its fixtures; positive fallback identity must be tested directly.

Reuse exactly saved v3 ticks 0,9,15,28,30,45,60,75,90,106, the same 20 half-sweeps and 40 actual-body/margin boxes. Ground is rebuilt with the same declared route-envelope and original seed component; old semantic receipt fields must match except MTime and resource-only cap. Alternate original/new pair order. Require equality of all old result fields except the explicitly disclosed negative skipped-ground-ID preview. Contact flags/counts, candidate count and first-contact semantics must not differ. Report extra prepass/fallback/native tile work honestly. All saved cases are negative contacts; positive semantics rely on separately identified authored fixtures.

## Scope and budget

One existing FARO reference mesh, no route/controller/game episode, no phone-map change, no dependency acquisition or remote writes. Sequential VTK, one CPU affinity, BLAS threads1. Existing watchdog: 600 CPU /900 wall seconds, 3 GiB RSS, 64 MiB outputs, 768 MiB free reserve. Preserve all original profiling, timing, arrivals and failures. One measured equivalence receipt is the stopping condition; do not claim universal equivalence or iPhone runtime performance.

## Primary source and ordering

The pinned [VTK 9.3.1 implementation](https://raw.githubusercontent.com/Kitware/VTK/v9.3.1/Common/DataModel/vtkStaticCellLocator.cxx) visits its bounds-query bins in k/j/i order and deduplicates through `vtkIdList::InsertUniqueId` (lines485–531). The tiled helper returns the same bin union sorted by original ID, not that traversal order. Original first-hit identity is therefore recovered by same-box V6 replay whenever contact exists, rather than assuming order is physically irrelevant.

For the recorded set comparison, an instrumentation-only V6 subclass captures the native ordered candidate list **after** the unchanged original contact method returns. Each candidate set is hashed as sorted little-endian signed int64 IDs and compared to the tiled set hash. Identity capture is timed separately; the primary speed ratio excludes that extra baseline capture, while inclusive timings remain reported. The optimized pass's own metadata work remains included. Historical profile candidate/ground/rejection/exact-test totals must also reconcile.
