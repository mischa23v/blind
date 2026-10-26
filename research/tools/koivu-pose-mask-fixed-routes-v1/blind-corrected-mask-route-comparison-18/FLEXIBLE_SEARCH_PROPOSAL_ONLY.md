# Separate flexible loop construction — proposal only

This is not part of the paired fixed-objective experiment. It has not been
executed. It must not overwrite or relabel the fixed-construction failures.

## Fixed objective and available evidence

Keep the original central phone-space anchor. A candidate must be a closed
cycle with winding +1 or -1 about that anchor, visit all eight angular aisle
regions, and satisfy the unchanged profile's sampled rectangle translations
and turns, including loop closure. An out-and-back or repeated short approach
does not count. The anchor is a phone-map proxy, not a verified semantic table;
encircling it does not alone prove every part of the old irregular blocked
component is enclosed. Report this objective explicitly.

## Reuse path, not a new metric map or planner

1. Use the same supplied candidate mask and pinned Detour engine. Compute the
   existing SciPy EDT only as a proposal/ranking quantity. Unknown cells remain
   blocked under the provided mask policy. No reference geometry is available.
2. Divide candidate centres into eight fixed 45-degree regions around the
   anchor in its original phone-aligned horizontal basis. Use the full available
   map domain, not the old component's global west/north bounding-box extremes.
3. Preserve a small deterministic, spatially diverse set in each region:
   rank clearance first, deterministic source-cell index ties, and nonmaximum
   suppression to prevent all choices collapsing to one pocket. Candidate cap,
   separation and permitted radial span must be fixed before running.
4. Existing Detour proposes paths between centres in adjacent angular regions.
   Reject incomplete, badly associated or sampled-rectangle/turn-invalid legs.
   Carry endpoint headings so junction and closing turns are checked, not just
   the translations. Use an established installed graph routine for choosing
   compatible legs if needed; do not add a new low-level search implementation.
5. Rank fully valid cycles by their **worst sampled model clearance first**,
   then total length. Preserve every candidate/rejection and the finite search
   budget. A bounded construction failure is not a proof no possible loop exists.

The circular EDT proposal is not physical width or exact oriented-body
clearance. Final candidate acceptance still uses the declared rectangle/turn
policy, and actual motion must be evaluated by the independent swept-body
reference scorer. No reference-guided waypoint retries are allowed.

## Three-lap execution boundary

Only a frozen valid cycle can feed the separate actor. Three laps reuse that
same provided map; they do not create new real sensor views. The tick budget
must scale with route length, commanded speed, turning, three laps and a fixed
declared slack, not inherit the short-approach cap. Report each lap, actual
travel, body/margin contacts, support failures, unresolved exposure, arrival,
elapsed time and deadlock separately. Stop on first independently scored contact
or unsupported motion; standing still is not a successful lap.

Before implementation, freeze the concrete candidate cap, diversity spacing,
graph representation, maximum native queries and runtime limit. The current
paired old/new result should guide whether this separate construction is useful,
not tune the mapping or body dimensions.
