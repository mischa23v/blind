# Frozen20×5 recorded-room matrix: all100 schedules accounted

2026-10-28. **90 simulated arrivals,4 completed stops/rejections,5 interrupted/unknown outcomes and1 CPU-limited partial outcome.** There are **94 completed movement episodes, not100 completed trials**. None of the six incomplete outcomes was retried, converted to zero distance or counted as success. No frozen route, geometry, floor classification, threshold, body profile or impairment condition changed during execution.

## Exact outcome split

| Outcome | Count | Schedule indices |
|---|---:|---|
| Goal reached under frozen arrival rule |90|See FINAL_RESULT.json|
| Reference floor-support stop |3|16,17,18|
| Predicted underbody sweep rejected before commit |1|56|
| Producer interrupted, terminal motion outcome unknown |5|8,15,31,45,61|
| Original900CPU-second limit reached, terminal motion outcome unavailable |1|62|

14 of20 directed route pairs arrived under all5 conditions. The20 pairs are ordered connections among5 fixed anchors in **one Koivu room**, not20 independent rooms or users. Nominal, delayed command, temporal pose-delivery jitter, extra translation and synthetic tracking-interruption conditions are developmental impairments. Temporal jitter is not measured spatial localization error; withheld simulated captures are not actual ARKit recovery.

The94 completed episodes record551.244139horizontal metres and56,031ticks. Successful route execution ranged1.909–10.920metres; the goal tolerance is0.35metres with current observation, drained commands and zero applied motion. The exact body is0.45×0.30×1.60m with **zero horizontal margin**. These results do not select a child body profile or establish clearance/error margins.

## What the collision count means

Across94 completed episodes, the existing scorer recorded0 committed non-ground body-contact events and0 margin-contact events; margin is zero, so it is not a separate clearance experiment. There was1 predicted underbody contact rejection before committing movement. Every committed moving tick was independently recounted from saved evidence: two conservative body-sweep half-segments, midpoint coverage, underbody checks and accepted finite9-ray support. This recount checks saved evidence; it does not rerun physics with an independent collision implementation.

**Zero committed contacts is not a phone-sensor safety rate.** The controller uses supplied poses and a FARO/reference-world collision/support veto, which can withhold movement before contact. Classified ground contacts remain exempt and unmeasured. Discrete support hits do not prove continuous support, semantic floor identity or detection of every toy/drop. The phone-derived source mesh and route also retain assisted exclusions and fixed offline alignment. No live phone-only hazard recall, false-clear rate, warning lead time, independent localization, body-heading accuracy, device performance or participant safety was measured. No table lap was completed or claimed.

The three support stops remain unresolved rather than being forced clear. Episode56 rejected a predicted underbody sweep against a reference triangle near the floor; its semantic identity is unestablished, not proof of a real toy or drop. Other conditions of that pair arrived. Episode62 was terminated at900.269sampled aggregate CPU seconds (original limit900),606.998wall seconds, with partial7.8m/1573ticks and no terminal result. That partial motion is not included in completed-distance/contact totals and is not a navigation pass or a fully scored collision failure.

## Integrity and execution limits

The unchanged evaluator freeze is3d17b1b816abd553fde50ea9702e35b4bcd380d10b18375f5535be2a5101b525; matrix27fb3411a7ebd6e5f5001d3849244b3ff989edae4ce58d0c93ae8d3a04f4ec74; cache manifest01fd57f962f2c57ee8e7aae8f60504ec1bc3514d2a01650e3b9374345152c6b6. Final summary reverified59 frozen input entries and81 cache-manifest entries. Highest completed-episode CPU was805.992s; observed peak RSS2,315,169,792bytes. Original per-episode limits remained900CPU/1200wall seconds,3.5GiBRSS,10MiBoutput, serial execution and4GiBtotal stage accounting. These are host measurements, not iPhone benchmarks.

Repeated execution-environment interruptions required lossless continuation roots. Previous producers were inaccessible, not authoritatively proved terminated. Continuations waited through prior deadlines plus60seconds and watched immutable snapshots of prior evidence; no prior mutation was observed. Current active-run lock is absent and99's owned supervisor returned. Incomplete outcomes remain visible. Checkpoint/recovery records retain the limitations and provenance.

## Reproduction and publication boundaries

FINAL_RESULT.json contains every schedule outcome, per-pair results, terminal-receipt/source hashes and aggregate arithmetic. RECOUNT_WITH_BUDGET_100.json separately records saved-trace checks and incomplete outcomes. summarize.py and recount_with_budget.py are read-only reporting scripts, not physics or estimator replacements. To reproduce, supply the full matching recovery/evaluator directory and write to a new result path; never overwrite frozen evidence.

This is a compact review package, **not a complete standalone reproduction bundle**: raw datasets, trace binaries, immutable floor caches and frozen route payloads are not all included here. Source84 archive publication remains separately pending. A checksum manifest without its payload does not make missing inputs available. This packet publishes text/numeric evidence only, no private images or source archive.

## Verdict

The frozen supplied-map/reference-assisted controller can execute many nontrivial routes in this recorded room under declared simulated perturbations. The experiment did not establish phone-only autonomous obstacle avoidance or real blind navigation. Next work must independently estimate current map-relative pose and body orientation, derive fresh support/hazards from actual phone observations, separate those estimates from evaluator truth, and repeat held-out/live controlled acceptance. Keep physical guidance unavailable until those distinct gates are met.
