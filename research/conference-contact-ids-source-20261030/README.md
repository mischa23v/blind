# Prepared additive complete-contact-ID diagnostic — NOT EXECUTED

## Purpose and frozen scope

The completed attempt001 worker recorded all-hit counts but only the first
locator-order witness. Its near-foot first witness cannot establish that every
remaining overlap is floor-like. The next diagnostic therefore records **every
hit original triangle ID**, without deleting/classifying ground or changing
geometry, body/margin parameters, trajectories or VTK intersection calls.

Original aggregate outcome remains **failed**, due to the terminal isolated
import error. Separate stdlib post-run reconciliation recovered honest completed
worker evidence; it did not turn the aggregate into a pass. No native work has
been executed for this additive recorder preparation.

Scope remains all seven exact `clearanceGrid` connector chains, 13,704 authored
increments / 27,408 nominal+margin queries, body 0.45×0.30×1.60 m, separate 0.15 m
horizontal margin, existing **0.002 m** lower-body exclusion and empty immutable
ground-face exemption set. Historical estimated registration is unchanged and
is not camera/body alignment validation. No smoothing, new physics, semantic
ground labels, support, arrival or physical clearance claims.

## Minimal instrumentation and count equality

`oriented_ground_container_debug.py` is a separately named copy of the pinned
all-hit source. Original upstream files are untouched. Its only change inside
`contact_corners` is a callback after a candidate has already been identified
as a hit, before the existing ground-membership branch. Intersection calls,
contained-vertex calls, candidate iteration, first witness, counters and return
values are unchanged. Constructor callback plumbing and explicit source-path
resolution are the only other changes. `KERNEL_ADAPTATION.diff` exposes them.

A stdlib AST control removes that one callback statement and requires exact
AST equality with the original method. Three prepared native controls compare
original and debug results/counters on synthetic floor+upper contact,
margin-only contact and bounded turn+translation cases. These native controls
have **not** run; they are required under the aggregate before a scene rerun.

`EXPECTED_COUNTS.json` comes from the complete pinned saved contact stream:
**108,582 combined hit occurrences**. `freeze_counts.py` rederives every saved
per-event nominal/margin count, not just total counts. A separate SHA256 binds
the ordered per-event candidate-count pairs, totaling **8,710,095** candidates.
The new recorder must reproduce all old per-event hit counts exactly and the
entire ordered candidate-count stream digest; a discrepancy aborts incomplete.
Original first-hit identity must also be the first recorded ID within a query.

`hit_recorder.py` collects only IDs already emitted by the all-hit loop. No
collision computation occurs in it. It requires exact event/query order,
integer original IDs within 0…29,365, no duplicate ID within one query, exact
old counts, and a complete seven-request stream. A failure never becomes clear.

## Fixed bounds before any rerun

- **200,000 IDs total**, checked before each append, not an unbounded callback API.
- **8 MiB logical ID-log bytes**, checked before returning an event record.
- Exact frozen seven bounded count lists are validated before collecting IDs.
- Combined raw contact-log + ID-log logical output stays within 64 MiB.
- The same aggregate **120 CPU / 180 wall seconds / 1 GiB observed RSS /
  64 MiB output / one CPU** bounds apply to all controls and worker combined.
- Existing worker limits remain 55,000 boxes and 30 million candidate triangles.

The prior completed native worker is a timing reference (~62.6 worker wall
seconds), not a promise this instrumented run will fit. No automatic retry,
budget increase, threshold relaxation, easiest-route subset or second policy
arm is authorized. Any limit or count mismatch preserves partial artifacts.

The planned `HIT_IDS.jsonl.gz` has one record per authored increment, separating
nominal-body and margin ID arrays, including empty arrays. Original IDs allow
later source-coordinate and height/normal inspection without another geometry
query. Whole-triangle heights are not contact-point heights; even complete
near-foot IDs would not establish semantic floor or physical support.

## Preparation evidence and root-only admission

Executed source-only checks: six stdlib recorder controls pass (0.175 s),
including method AST equality, all 13,704 synthetic recorder events with the
same count shape, and hard cap/missing/extra/reordered refusal cases. Synthetic
IDs are test data, not original-scene contacts. All Python sources parse.
The original saved count stream is reverified with stdlib only.

Prepared aggregate sequence: three isolated-import regressions, six original
schedule controls, six recorder-source controls, 32 prior kernel controls plus
three new debug equality controls, then the all-seven diagnostic. Root must
publish, obtain independent review and admit the exact source before any native
execution. Fresh output path: `conference-contact-ids-attempt-001`.

```sh
python -I research/conference-contact-ids-source-20261030/run_aggregate_ids.py \
  --admitted-source-commit <exact-reviewed-published-HEAD>
```

This is a proposed future diagnostic, **not yet a run or a physical pass**.
