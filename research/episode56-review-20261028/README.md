# Episode 56: saved-evidence review (2026-10-28)

**Finding:** the delayed-command episode stopped on a predicted **underbody guard** intersection during an in-place turn—not on a committed main-body collision. The precise recorded reference face is **10277130**. This review does not establish that face as a real obstacle or a floor artifact. Other conditions traverse within centimetres of this location at different headings; the evidence does not establish an impassable passage.

## Scope and reproduction

Read-only analysis of the completed frozen recovery-05 results. No physics rerun, VTK import, reference mesh load, download, installation, threshold change, floor relabeling or frozen-file edit. Eight groups of saved-record consistency assertions pass:

```sh
python research/episode56-review-20261028/review.py
```

Python standard library only; about 0.5 seconds in this workspace. It regenerates `EVIDENCE.json` in this review directory. Input hashes, derived guard corners and the five-condition comparison are recorded there. The script verifies final-tick/result agreement and matching pair/cache hashes; it does **not** independently reproduce the reference intersection. The source geometry routine is read, not executed.

## Exact rejected proposal

- Episode 56, pair 11, `command_delay`, seed 72011; 801 tick records, terminal tick 800.
- Current model XYZ: **(-1.050240211579818, -0.005245624160079686, -3.3180180881497807)** m. Current yaw **-2.8552145992668923** rad.
- Command issued at tick 797, applied at 800: forward **0 m**, yaw **+1°**. This is command reaction delay, not delayed image-derived localization.
- Proposed XYZ has identical XZ and Y **-0.0052202266716296075** m: a **25.397 micrometre** support-datum change. Proposed yaw derived from the command is **-2.837761306746949** rad.
- Main-body swept checks: no non-ground reference contact in either half. Underbody first half: no contact; second half: contact.
- `candidateStateCommitted=false`; last committed motion tick 799. Zero committed body contacts; one rejected predicted underbody event. This is not evidence that a person physically struck anything.
- The body is 0.45 × 0.30 × 1.60 m with zero horizontal margin. These are simulation dimensions, not a validated child profile.

## What the query actually checked

Frozen `local_support.py:58-66` builds an underbody OBB using the endpoint nine-probe known-floor observations. Its bottom is the minimum observed floor height minus **20 mm**, and its top is the maximum endpoint foot height plus **2 mm**. It is an additional guard below/around the foot datum, not merely the main-body volume above the floor.

For the contacting second half:

| Quantity | Model metres |
|---|---:|
| Minimum observed support Y | -0.009148656434453496 |
| Maximum observed support Y | -0.0052202266716296075 |
| Guard lower Y | -0.029148656434453496 |
| Guard upper Y | -0.0032202266716296075 |
| Whole contacting triangle minimum Y | -0.005879931180409605 |
| Whole contacting triangle maximum Y | -0.005761934247913474 |

The horizontal rectangle is enclosed over a **0.5° half-turn**, with approximately **1.180 mm** rotational padding on each horizontal half-extent. `oriented_container.py:47-95` explicitly says the conservative enclosure may overcount. `EVIDENCE.json` reconstructs its eight model-coordinate corners using the frozen formula. This reconstructs the query shape; it is not a second collision test.

Frozen `oriented_ground_obb_container.py:92-160` transforms that OBB to reference coordinates, retrieves bounds candidates, skips immutable known-ground face IDs, applies its bounds filter, and tests the remaining triangle with VTK `IntersectWithCell` (then contained vertices when necessary).

The contacting half records **13,294 broad-phase candidates**, of which **13,293 were skipped ground candidates**—not 13,293 contacts. Exactly **one non-ground triangle** received an exact test and contacted: **face 10277130**, reason `boundaryIntersection`. The first half had the same candidate counts, but its sole non-ground candidate was excluded by the bounds filter. Ground contacts are unmeasured.

### Why this is not yet a floor/noise verdict

The face has only **0.118 mm** total Y variation and lies within the surrounding support-height range. That is consistent with a near-floor surface, but neither height nor membership establishes semantic identity. The saved record gives the whole triangle's Y range, **not a contact point**, full triangle vertices, normal, mesh connectivity or corresponding phone image observations. Being excluded from the immutable ground set is a policy fact, not proof of a toy. Conversely, lying near the floor is not permission to erase it.

The evidence supports **sensitivity to orientation, conservative sweep and immutable ground partition**. It does not separate exact swept-body contact from enclosure-only contact, nor prove pose drift, sensor noise, a physical obstacle or a harmless surface. No claim of a safe correction is justified here.

## Same pair, same plan and cache

All five results share the exact pair-plan SHA, cache-result SHA and cache-manifest SHA; the reproduction checks this.

| Episode | Condition | Recorded outcome | Distance | Nearest saved XZ to rejected location |
|---|---|---|---:|---:|
| 55 | nominal | arrival | 5.724 m | 7.74 mm |
| 56 | command delay | predicted underbody rejection | 5.441 m | 0 mm |
| 57 | temporal jitter | arrival | 5.818 m | 9.25 mm |
| 58 | extra translation | arrival | 5.718 m | 12.14 mm |
| 59 | tracking interruption | arrival | 5.724 m | 7.74 mm |

The four arriving conditions' nearest saved headings differ from the rejected heading by about **58–61°**. Near-equal XZ is not an identical full-body configuration or clearance proof. Episode 56 remains at the final XZ across rows **692–800**, spanning **7.2 simulated seconds**, while its recorded heading changes about **107°**. The last increment is rejected. This is a turn/configuration question, not evidence that forward passage at every heading is blocked. Delay is not proven to cause a physical hazard.

## Next diagnostic, not a claimed fix

A separate authorized geometry inspection would need the unchanged original face 10277130 vertices, adjacent faces and immutable ground membership, transformed into the model frame; independently compare its contact against the actual rotating footprint rather than only the enclosure. Associate nearby original RGB/depth observations if deciding sensor/floor identity. Preserve all observations and record both interpretations. Do not relabel the face, widen a threshold, remove the guard or count the rejected tick as an arrival to obtain a better headline result.

This review does not change the frozen 100-schedule verdict, complete additional movement trials, establish live phone sensing or support safety claims for children. Reference-assisted veto and supplied synthetic poses remain the controlling limitations.
