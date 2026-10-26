# Variant tests, safety-first — Koivu (development) and coffee_room (holdout), 2026-10-26

Purpose stated by the owner: a blind person must move through the room **safely**; a change is acceptable only if it does not make the map less safe. So every variant below is judged first on what it **un-blocks that the reference says is real**, and only then on routes. All variants use identical code on both rooms (`scripts/pipeline2.py`, `scripts/occthres.py`, `scripts/openfloor.py`); thresholds were fixed before the holdout outputs were read, except where marked. Reference = author-registered, cleaned FARO mesh, evaluator only. **Movement episodes: still 0 / 100.**

## Safety metrics

- **miss** = planner-walkable 5 cm column containing reference geometry: low band (≥2.5 cm above floor) or any body/head-band geometry (overhang).
- **edge miss** = a miss within 0.15 m (the declared margin) of a column the map still blocks → the map boundary sits inside the true object's last 5–15 cm; the margin still buffers it.
- **open-floor miss** = a miss farther than 0.15 m from any blocked column → a hazard the map calls free space. This is the class that must not grow.
- The edge/open-floor split was declared after seeing the Koivu threshold results and before reading the coffee_room threshold run; it is therefore a Koivu-tuned refinement that the holdout then tests.

Baseline (D1, 5 cm): Koivu 221 edge / **4 open-floor** (one 2×2 blob of 145–148 cm-high geometry at (−0.6, 2.8) m that the phone never saw; plausibly an object present only at FARO time); coffee_room 101 edge / **0 open-floor**.

## Results

| Variant | Room | walkable cols | real floor still blocked | edge misses | open-floor misses | 2–6 m rectangle routes (full 0.15 m margin) | verdict |
|---|---|---:|---:|---:|---:|---:|---|
| **D1 baseline** (OctoMap 0.5, 5 cm) | Koivu | 10,695 | 1,791 / 10,805 (17 %) | 221 | 4 | 0 | reference |
| | coffee | 6,250 | 1,695 / 7,821 (22 %) | 101 | 0 | 0 | reference |
| Ungrounded-blob removal | Koivu | 11,373 | 1,314 | 419 | 4 | 0 | **rejected**: 208 of 816 freed columns hold real geometry (seat edges, table undersides) |
| | coffee | 6,584 | 1,441 | 180 | 0 | 0 | same pattern (83 / 450) |
| TSDF surface as occupancy (Open3D 0.20 Uniform, 2.5 cm, trunc 8 cm) | Koivu | 13,197 | 792 | 1,285 | **124** | 8 | **rejected**: erases thin/low objects 4–30 cm |
| | coffee | 7,619 | 718 | 454 | **29** | 140 | **rejected** (a 54 cm-high object vanishes) — the unsafe-but-navigable case |
| OctoMap threshold 0.6 | Koivu | 11,059 | 1,570 | 275 | 4 | 0 | no new open-floor miss; no routes |
| | coffee | 6,462 | 1,504 | 118 | 0 | 0 | |
| OctoMap threshold 0.7 | Koivu | 11,434 | 1,356 | 355 | 4 | **82** (2.6 m median) | no new open-floor miss |
| | coffee | 6,663 | 1,338 | 155 | 0 | **0** | passes safety, **no routes on holdout** |
| OctoMap threshold 0.8 | Koivu | 12,067 | 943 | 519 | **7** | 250 (3.8 m median) | **rejected**: 3 new open-floor misses (110–137 cm overhangs) |
| | coffee | 6,921 | 1,136 | 202 | 0 | 0 | |
| **Split: support at 0.5, obstacles at 0.7** | Koivu | 11,501 | 1,287 | 359 | 4 | **97** (2.7 m median, max 3.4) | no new open-floor miss |
| | coffee | 6,794 | 1,218 | 157 | 0 | **21** (2.25 m median, max 2.65) | **first variant that passes safety and yields routes on both rooms** |
| Split: support 0.5, obstacles 0.8 | Koivu | 12,421 | 772 | 556 | **7** | 239 | rejected (open-floor misses) |
| | coffee | 7,281 | 819 | 210 | 0 | 45 | |
| 2.5 cm voxels, floor band tiled ±3.75 cm | Koivu | 50,041 (31 m²) | 4,326 / 45,271 (9.6 %) | 1,789 | **7** | 15 | **rejected**: widened floor blind spot (forbidden), new open-floor misses |
| 2.5 cm voxels, strict floor band ±1.25 cm | Koivu | 37,263 (23 m²) | 15,284 / 45,271 (34 %) | 1,079 | 0 | 0 | safe but floor noise (σ 0.7–1 cm) blocks a third of the real floor |
| **REFERENCE-ONLY** (evaluator geometry) | Koivu | 10,805 | — | — | — | **387** | what a correct map would allow |
| | coffee | 7,821 | — | — | — | **537** | |

Edge misses rise with every permissive change: that is the halo shrinking toward the true surface, inside the margin. Open-floor misses are the safety line; only threshold 0.8 (Koivu), the ±3.75 cm floor band and TSDF cross it.

Where the remaining false blockage sits (reference-walkable, phone-blocked), 5 cm, threshold 0.5 → 0.8:
- Koivu: body-band occupancy only 760 → 241 (of which within 7.5 cm of real geometry 569 → 275); low band only 389 → 189; **no floor support 167 → 392** (raising the threshold also deletes floor evidence); near-range dips 115 → 2.
- coffee_room: body-band only 862 → 408; low band 166 → 71; **no support 194 → 529**; deep/dip 157 → 24.

## Reading

1. **One variant recovers routes on both rooms without crossing the safety line: floor support at the default OctoMap threshold 0.5, low/body obstacle occupancy at 0.7.** Open-floor misses stay at the baseline (Koivu 4, coffee 0); edge misses rise (221→359, 101→157), i.e. the obstacle boundary moves inward by about one voxel; routes 97 (Koivu) and 21 (coffee), but short — median 2.7 / 2.25 m, max 3.4 / 2.65 m against the 2–6 m requirement and 387 / 537 reference routes. The uniform threshold fails on the holdout because it also deletes floor support (coffee no-support 194→529); the split rule does not.
2. **Finer voxels are not a fix by themselves.** At 2.5 cm the floor band's placement decides everything: tile it wide and the blind spot widens (forbidden, and misses appear); tile it tight and floor noise blocks a third of the floor.
3. **TSDF must not be the occupancy evidence**, in either room. It may serve as a *surface-position* refinement for voxels OctoMap already calls occupied, never to clear them.
4. **The ungrounded-blob idea is wrong**: floating small blobs are often real furniture parts.
5. The scattered false obstacles (≥20 cm from any real geometry: Koivu 194, coffee 224 at 0.5) shrink to 13 / 30 at 0.8 — they are low-evidence voxels, which is what the threshold removes. Applying the higher threshold only to obstacle bands keeps the floor; that is the split rule above.
6. **Caveats on the split rule.** It is an upstream OctoMap parameter, not a new algorithm, but the value 0.7 was chosen on Koivu and the holdout saw it once; the open-floor metric itself was refined after Koivu's threshold results. It is a *candidate* for a frozen v3 map, to be fixed in writing (threshold, bands, margin, flag policy) before the 20 route pairs are selected, then scored once more on a third room if one is downloaded. Routes it yields are still half the length the rooms allow; the remaining gap is the ~5 cm halo plus false low-band blocks (Koivu 189, coffee 71 columns at 0.8).

## Still open

- The 4 baseline open-floor misses on Koivu (145–148 cm geometry the phone never observed): object moved between captures, or a phone blind spot? Needs the RGB frames at that location (not done here).
- No frozen v3 map, no 20 route pairs, no movement episodes, no device evidence.

Arrays and receipts for every row: `derived/pipeline-outputs/` (`*_v2_pipeline2_out.npz`, `*_occthres_*.npz`, `*_occthres*.log`, receipts; checksums in `SHA256SUMS.txt`).
