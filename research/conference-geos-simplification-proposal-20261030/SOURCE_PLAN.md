# GEOS simplification — separate paired diagnostic source

**Source adapter, 17 authored controls and a separate guarded paired worker prepared, not executed. No GEOS library loaded, native route job or installation. The unchanged conference full-body baseline remains separate.**

Root approved source preparation after the initial plan. `candidate.py` implements the GEOS adapter, exact identity checks, paired records and existing segment-validator calls. `test_candidate.py` contains authored controls with explicitly labelled corridor stubs; no real native corridor evidence is fabricated. `run_pair.py` and the reused `run_aggregate.py` prepare a separately admitted actual diagnostic, with unchanged resource caps and a known-source native callback. Python AST parsing, source hash comparisons and a stdlib-only manifest freeze are preparation, not passing controls. See `SOURCE_PREPARATION.json`, `SELF_REVIEW.md` and `AGGREGATE_PROTOCOL.md`.

## Is this worth investigating?

Yes, as a diagnostic rather than a safety fix. The existing seven centered chains contain 44–127 requested-connector vertices each. Their frozen stop/turn/translate schedules contain **12,049 turn events (each at most one degree) out of 13,704 total events**, with 1,366–2,506 turn events per objective. This is read from the existing `conference-body-source-20261029/ROUTES.json`, not a new simulation or measured movement. The first useful question is whether fewer geometry vertices reduce this authored heading work without invalidating independent checks.

No simplified result has been computed, so there is no claimed reduction yet. Any reduction would remain a route-representation diagnostic, not observed comfort, runtime speed or physical reliability.

## Reuse, not a new search algorithm

Use installed **GEOS 3.13.1**, via `GEOSTopologyPreserveSimplify_r` in its supported reentrant C API. The released implementation removes redundant vertices while preserving geometry topology; topology preservation does **not** establish obstacle avoidance or 3D clearance. Reuse the existing `independent-2d-route-validator-20261029/validator.py` ctypes context/ownership wrapper rather than adding Shapely or implementing Douglas–Peucker ourselves. The required simplifier and coordinate-sequence accessor symbols were confirmed by read-only dynamic-symbol inspection; no functions were called. [Released C API](https://raw.githubusercontent.com/libgeos/geos/3.13.1/capi/geos_c.h.in), [released simplifier contract](https://raw.githubusercontent.com/libgeos/geos/3.13.1/include/geos/simplify/TopologyPreservingSimplifier.h).

The current graph module already contains `compress_collinear`, but it is limited to near-collinear XYZ geometry and does not address a genuinely alternating staircase. It is not substituted for the established simplifier. The current `selector.py` intentionally emits unsmoothed candidates; it stays unchanged.

The existing installed-library license record is LGPL-2.1-or-later, with separate bundled notices. Source review is not an upstream test or CI result. Exact requested GEOS unit-test pages returned tool cache misses, so no unit-source inspection claim is made.

## Fixed candidate declared before results

One candidate, **0.025 m horizontal tolerance**, no tolerance sweep or route-specific retuning. This is half the existing 0.05 m graph spacing, not a permitted safety-margin reduction.

For each of the same seven objectives, pair:

1. The unchanged `clearanceGrid` requested-connector chain.
2. One GEOS-simplified version of that same chain, retained even when rejected/unavailable.

Simplify only the inner graph chain in XZ. Lock the exact requested endpoints, both external requested/projected connector segments, and the first/last original graph edges. The latter avoids changing start/end graph headings merely to obtain a better diagnostic. Do not join the five table objectives into a new ring or drop the reverse VARPU objective.

Require every returned vertex to map to an exact ordered original XZ subsequence, then retain its original full XYZ. Reject the whole candidate for generated coordinates, reversed ordering, moved endpoints or ambiguous repeated XZ with different source associations/heights. No nearest-coordinate matching, new heights, interpolation, floor snapping or endpoint repair. Long segments can nevertheless bypass an interior vertical feature; preserving retained heights is **not** a 3D proof.

The complete reconstructed XZ chain also passes a separate GEOS simplicity check after the locked edges and connectors are reattached. Inner-line topology preservation alone does not cover them. A nonsimple completed chain is retained as rejected and cannot be eligible for the later body diagnostic.

Record both arms, retained indices, full-XYZ lengths, cumulative absolute authored turn (radians/degrees), vertex counts and the same frozen schedule's turn/translation/total event counts. Preserve the original unfiltered-shortest-grid detour cap. A shorter chain does not inherit original edge proxy scores or validation receipts; those belonged to different segments. Candidate totals must always display their `includedRows`; never compare a partial candidate subset to all seven baselines as a reduction. No contact-event percentage is calculated or interpreted as safety improvement.

## Mandatory segment checks — no acceptance shortcut

- **Native corridor:** reuse unchanged `Native.segment` / `bn_segment`, checking **every complete resulting segment in both directions**, including preserved requested connectors. This is the current native raycast/endpoint-height test, not a full-body sweep. An exception, false result, exhausted buffer or unknown is not a pass. No route-search rerun is needed for the candidate operation itself.
- **Independent 2D:** reuse the existing `validate` with full segment-to-polygon and coverage-boundary distances, unchanged body enclosing radius `hypot(.45,.30)/2`, separate `.15 m` margin and `1e-8 m` numerical guard. Checking only retained vertices is insufficient. Do not substitute navmesh-wall distance, Coffee exclusions or screenshots for independent conference obstacles/coverage.
- **Full 3D remains required:** exact rectangular body and separate margin, rotations/translations, original mesh/frame association, support and currentness checks still govern any later acceptance. A topology-preserving line can still cut a corner or intersect an obstacle. Neither less zigzag nor less execution work means safe.
- **No repair after a failed check:** preserve the candidate and rejection. Do not lower tolerance, patch failing portions, swap to the shortest arm, omit an objective or silently return the original as a successful simplified result.

**Current real-scene blocker:** there is no admitted complete independent conference floor/body/head projection and coverage contract. The existing 2D adapter only reports `clear_in_authored_fixture_only` for its authored fixtures. Therefore real conference simplification cannot become an accepted physical route; missing independent evidence stays `unknown`. A positive native corridor check would not remove that blocker.

## Proposed controls and execution boundary

The machine-readable [candidate protocol](CANDIDATE_PROTOCOL.json) fixes the algorithm/tolerance, original hashes, all seven objectives, baseline counts, missing-evidence blocker and proposed controls. Controls should cover a shallow staircase, a sharp choke/corner, endpoint-clear but segment-crossing obstacle, body/margin-only contact, coverage/projection unknown, repeated-XZ height ambiguity, exact connector/edge preservation, GEOS failure and all-objective retention. They are **planned, not executed**.

Next is root's review/publication of this isolated packet, then the exact-commit guarded command in `AGGREGATE_PROTOCOL.md` if admitted. No real-room/native job ran during preparation. Do not add the candidate to `selector.py`, the default app, current native-comparison manifest, or baseline conference full-body schedule. No large dependency, install, build or archive upload is requested. `physicalAuthority=false` and `movementExecuted=false` remain mandatory.
