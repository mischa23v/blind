# V6 saved-query performance attribution — instrumentation only

Purpose: identify the actual remaining cost in the frozen V6 collision scorer before proposing an optimization. No navigation episode, new route, phone map change, collision-geometry change or physical permit.

## Fixed inputs and comparisons

Reuse exactly the previous ten saved v3 trace ticks: 0, 9, 15, 28, 30, 45, 60, 75, 90, 106. Each tick has the same two continuous half-sweeps and actual-body / 15 cm horizontal-margin query, for 40 box queries. Reconstruct the same midpoint support and fixed v3 ground component, independently comparing every prior semantic ground-receipt field (except process-specific mesh MTime and resource-only candidate cap). The reviewed stage14 tiled setup query may be reused; this is NOT a per-tick optimization.

Run the original V6 scorer and an instrumentation-only copy on the same loaded original FARO mesh and ground component. Alternate original/instrumented order by half-sweep index to expose simple order bias. Compare complete output dictionaries, counters and candidate counts; timers remain outside those dictionaries. No contact-predicate changes are permitted. All these saved recorded cases are negative-contact cases; authored fixtures must separately cover positive/rotated/boundary cases.

## Timing attribution

Report separate wall-time segments for validation/transform and box setup, native `vtkStaticCellLocator.FindCellsWithinBounds`, ID extraction, ground split, zero-copy OBB bounds rejection, exact predicate loop and result assembly. Report owner-check timing/count separately as an explicitly nested diagnostic, never add it to inclusive phase totals twice. Report total baseline/instrumented elapsed time and timer overhead/remainder; this is Linux single-core diagnostic timing, not iPhone latency or a general performance guarantee.

V6 already uses zero-copy VTK point/connectivity arrays and batched NumPy transforms for non-ground filtering. Do not assume scalar `GetCell` extraction remains dominant when all recorded non-ground candidates are rejected before exact testing.

## Stopping and next decision

One complete attribution receipt is the stopping condition. A native-bounds-query optimization is justified only if the measured native phase exceeds half of the whole paired instrumented sweep time (including outer owner/geometry work); otherwise inspect the largest measured phase instead. A later tiled query must preserve the exact original geometry and closed bin-union coverage and either preserve original first-contact ordering or separately disclose nonphysical reporting-order changes. No optimizer or new movement run is part of this profiling cut.

## Resource limits

One original reference mesh, sequential VTK / one CPU affinity / BLAS threads1. Existing watchdog caps: 600 CPU seconds, 900 wall seconds, 3 GiB process-tree RSS, 64 MiB outputs, 768 MiB free reserve. Preserve all logs, inputs and prior results on any failure. No packages, downloads or remote writes.
