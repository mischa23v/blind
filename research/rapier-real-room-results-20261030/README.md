# Fixed real-room Rapier diagnostic — completed, not movement

The unchanged official Rapier 0.21.0 comparator completed all **16 groups, 408
selected rows, 328 controller calls and 80 unsupported turns**. The 49 original
selected poses and two Coffee saved-state poses were not replaced. Every query
reset the body to its original pose; **no returned proposal was applied**. These
are not journeys, arrivals, measured accuracy or usable clearance results.

The two failed analytic 1 cm down-step checks remain failed. This diagnostic
neither changes their thresholds nor adopts the controller for navigation.

## What changed—and did not

- **Mesh flags did not help these probes:** all 164 raw/internal-edge paired
  movement proposals are exactly equal, as are grounded flags and event counts.
- **Every one of 328 calls reports `computedGrounded=true`.** That includes
  preserved VTK overlaps. Grounded is demonstrably not an independent support,
  obstacle-clearance or stair-safety verdict.
- **Zero input can yield a nonzero proposal.** Maximum magnitudes: Coffee body
  2.372 mm; Coffee margin 85.711 mm; Conference body 14.693 mm; Conference margin
  52.992 mm. They were recorded, never applied. A planner cannot count these as
  free progress or automatically relocate a person by them.
- Exact XYZ versus horizontal-projected intent differs in 76 of 164 paired
  proposals; maximum difference 86.271 mm. Forty pairs differ in collision-event
  counts. This is a deliberately different input, not an improved map.

## Per-scene and envelope behavior

Raw-mesh arm below; internal-edge arm is identical. “Unchanged” means vector
error at most **1 micrometre**, a descriptive reporting tolerance only. The
table classifies the actual requested vector as nonzero only when its norm is
above **10 nanometres (1e-8 m)**. This separates two tiny residual horizontal
inputs from meaningful intent; it is not a physical or safety threshold. Exact
zero/nonzero counts are also retained in JSON. The inputs include authored
almost-vertical increments: they are not all
forward walking. “Changed” can mean collision limiting, redirection or an
initial overlap/depenetration proposal; it does not by itself establish why.

| Scene / envelope | Intent | Inputs >10 nm | Unchanged / changed | Inputs ≤10 nm with proposal >1 µm | Calls with collision events |
|---|---|---:|---:|---:|---:|
| Coffee body | XYZ | 3 | 1 / 2 | 2 of 3 | 2 |
| Coffee body | horizontal | 3 | 2 / 1 | 2 of 3 | 0 |
| Coffee margin | XYZ | 3 | 2 / 1 | 3 of 3 | 1 |
| Coffee margin | horizontal | 3 | 1 / 2 | 3 of 3 | 0 |
| Conference body | XYZ | 21 | 15 / 6 | 8 of 14 | 6 |
| Conference body | horizontal | 19 | 13 / 6 | 8 of 16 | 2 |
| Conference margin | XYZ | 21 | 8 / 13 | 12 of 14 | 13 |
| Conference margin | horizontal | 19 | 7 / 12 | 14 of 16 | 4 |

Under an exact nonzero test, Conference horizontal has 21 rather than 19 inputs:
two are ≤10 nm residual vectors. The earlier exact-zero classification was
mathematically consistent but ambiguous for interpreting intended movement.
The table now states both its input and output reporting tolerances. A 1 mm
output tolerance will give different unchanged counts from the 1 µm used here.

Each Coffee group also preserves three unsupported turns, each Conference group
seven. KCC does not check their rotations; original VTK swept-turn evidence
remains attached to the raw records.

## Original VTK versus controller disagreement

These are **different queries**, so disagreement is not automatically a bug in
either library. VTK uses a conservative enclosing sweep and omits the lower
2 mm. Rapier uses the full cuboid and an additional 2 mm controller offset,
returns proposals from its initial pose, and exposes no source triangle ID in
these collision events. Coffee also converts original Double vertices to
Float32; Conference uses the exact earlier Float32 bytes. No image, semantic
floor or independent physical support check was added.

For raw/exact XYZ:

| Scene / envelope | Calls with direct VTK overlap | VTK overlap but unchanged proposal | VTK no overlap but changed proposal |
|---|---:|---:|---:|
| Coffee body | 0 | 0 | 4 |
| Coffee margin | 3 | 1 | 1 |
| Conference body | 5 | 1 | 10 |
| Conference margin | 29 | 4 | 0 |

Coffee's saved-state zero-input probe has no new direct static VTK query and is
excluded from that table's comparisons. Historical accepted and rejected C
records remain preserved, not substituted for a new query.

All five Conference body overlaps have a first-witness near-foot label in the
original VTK evidence; 15 of 29 Conference margin overlaps do. This does **not**
mean every overlap is floor or every witness is noise. Whole-triangle height
ranges are not actual contact-point heights, and later witnesses may differ.

Important unchanged-proposal disagreements are not all near the floor:

- `coffee:0_to_8:630`, margin: 16.667 mm requested X translation retained;
  original first VTK triangle spans 0.637–0.679 m above the start foot.
- `conference:varpu_130_to_160:961`, margin: diagonal requested translation
  retained; original first VTK triangle spans 1.331–1.426 m above the start foot.
- `conference:table_20_to_92:2861`, margin: nearly vertical 0.201 mm intent
  retained; original first triangle spans 0.839–0.936 m above the start foot.

They require inspection of original overlap geometry and starting pose, not
relabeling as safe. Existing overlaps may persist while motion moves tangentially
or away, and a conservative swept enclosure can overcount. The saved results
alone do not isolate these explanations. **Do not suppress VTK contacts because
the controller returned the requested displacement.**

## Reproduction and evidence

`RESULTS.json` records all 16 aggregates, pair differences and exact raw input
hashes. `COMPACT_PROBES.jsonl` retains per-query requested/proposed vectors,
grounded state, event counts and direct VTK overlap summaries without duplicating
the approximately 2 MB raw evidence. Original raw records remain locally intact;
compact records do not replace them for geometric diagnosis.

From the existing workspace, run stdlib only:

`python -I -B research/rapier-real-room-results-20261030/summarize.py <fresh-summary-directory>`

This parses the completed files; it never imports or reruns Rapier. Comparison
source, full coordinate binding, licences and the exact pinned execution command
remain in `../rapier-real-room-source-20261030/`. Public MuSHRoom data only; no
private child/home scans used or published.

**Next useful question:** explain the selected high and low VTK disagreements
with their original triangle geometry and accepted support policy, then evaluate
any change separately. Replacing the collision checker or applying these
proposals wholesale is not justified. No route was followed and no physical
clearance, live localization, coverage, floor support or arrival was established.
