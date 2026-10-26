# How to build the map correctly — and what to do differently

This is a recommendation backed by the measurements in `README.md` / `RESULTS.json`. It is not a frozen protocol. Every threshold below needs to be frozen before reference scoring, not tuned afterwards.

## What went wrong in the process (not just the code)

1. **Custom mapper first, released baseline later.** v1 was a hand-written endpoint union with hand-picked bands. A released fusion engine (OctoMap) plus a released navmesh builder (Recast) should have been run end-to-end on day one, as the comparator any custom logic must beat.
2. **Thresholds chosen before the sensor was measured.** The ±3 cm floor band was declared without measuring floor dispersion. Ten minutes of measurement shows the band is crossed by the floor itself beyond about 1.5 m (p95 5–8 cm).
3. **No picture of the map.** One top-down image of support, obstacle and unknown shows immediately that the floor is red and the aisles exist. Cell counts alone ("13 eligible", "359 eligible") hid that.
4. **Input format not inspected.** The depth PNGs are 4× nearest upscales. Treating every pixel as a separate endpoint multiplied evidence counts by about 16 and made the min/max floor test even more extreme.
5. **v2 changed the fusion but kept the broken floor/support rule.** It is better to change one thing at a time and measure each change, which is what you intended. But the rule being kept was the main defect.
6. **Body geometry stacked bounds.** Rectangle → square → circle → margin → cell round-up. Bounds should be derived once, from the declared body, with the margin from a written error budget.
7. **Long confirmations instead of early attribution.** Both my audit and the other session spent time re-verifying pins before running the one experiment (released fusion plus visualisation) that located the cause. Next time: give a verdict early, then attribute.

## Correct pipeline (offline Koivu and, with live inputs, the app)

```
depth + pose  →  native-resolution samples  →  sensor noise model σ(range, incidence)
              →  probabilistic 3-D occupancy (released engine: OctoMap; TSDF comparator: Open3D)
              →  floor model (robust plane + local elevation per column, with variance)
              →  height-banded column classification with explicit precision tiers
              →  body-aware traversability (single bound, margin from error budget)
              →  navmesh / planner (Recast–Detour; SE(2) check for the rectangle)
              →  frozen map + routes  →  reference scoring  →  100-run game  →  device
```

### 1. Inputs
- Decode to the **native sensor grid**: one sample per LiDAR cell, ray through the block centre. Record range and incidence angle per sample.
- On device, use ARKit `sceneDepth` **confidence** and tracking state. The offline data lacks them, and nothing may fabricate them.

### 2. Measure the error model first (publish it with the map)
- Floor dispersion versus range and incidence (here: p95 1.7 cm under 1.5 m, 5.3 cm at 1.5–2.5 m, 7–8 cm beyond).
- Per-frame vertical/horizontal offsets: here ±1 cm, with bursts to 3.5 cm in frames 60–69 and 116–119.
- Wall thickness and multi-view consistency as a horizontal error estimate.
- These numbers set every threshold below. Nothing is picked by feel.

### 3. Fusion
- Use a released probabilistic engine (OctoMap 1.10 default sensor model, 5 cm) with free-space ray tracing. Positive hits must be correctable by repeated free observations. Single-frame hits must not be permanent.
- Run a TSDF comparator (Open3D v0.19.0 `ScalableTSDFVolume`, 2 cm) with its **weight layer kept as coverage**. A smooth surface or missing triangle is never free space.
- Keep two precision tiers, which can be one engine queried two ways: **near** (beams ≤ R_near, chosen from the error table — here about 2 m) and **all ranges**.

### 4. Floor and support
- Fit the plane to **raw measurements** with a robust estimator, not to voxel centres.
- Also keep a **local elevation per column** (median plus variance from the error model), so slow drift or real slopes don't turn into fake obstacles or drops.
- A column has support if the fused floor is observed there. Support is never decided by "no hit beyond ±3 cm among thousands of samples".

### 5. Height bands with stated resolution

| Band (relative to local floor) | Evidence used | If unobserved |
|---|---|---|
| floor ± half-voxel | support | unsupported → blocked |
| low band (2.5–7.5 cm) | near tier; far tier only as positive evidence | **flagged unresolved** (policy decides block or allow; never silently cleared) |
| body band (7.5 cm – head + margin) | all tiers, any occupied blocks | unknown → blocked |
| overhead/head | all tiers, any occupied blocks | unknown → blocked |
| below floor | near tier for 2.5–7.5 cm; all tiers for ≥ 7.5 cm | flagged |

Also state the blind spot plainly: anything below about 2.5 cm cannot be separated from floor with this data. A belt or near-field sensor is how the live system closes that gap.

### 6. Body and margin
- Planner disc = circumradius of the declared footprint (0.45 × 0.30 → **0.2704 m**). Use it once, with no √2.
- Margin = written error budget (localisation + map registration + controller tracking + latency × speed), each term measured. Report results at the chosen margin and at ±5 cm, to show sensitivity, not to pick the passing one.
- To keep a larger margin in narrow aisles, check the actual **rectangle with heading** (half-width 0.225 m) along the corridor: OMPL SE(2) validity or an evaluator-side swept-rectangle check. Keep the disc for turning in place.
- Recast at `cs = 0.05` so cell rounding doesn't add another 7–10 cm.

### 7. What to measure (instead of "eligible cells")
- Walkable area and the largest connected region at the body radius.
- Full-body start count, and route length distribution between seeded pairs.
- After freezing, against the reference (evaluator only):
  - obstacle recall by height band (low / body / head);
  - false-obstacle rate;
  - aisle-width error;
  - unresolved fraction.
- Retention fixtures: objects rendered into real rays (done here: 4 and 8 cm boxes retained), plus objects at the declared blind-spot size.

### 8. Experiment order (one change at a time, all failures kept)
1. Released baseline end-to-end (OctoMap → Recast) with picture and metrics. *Done here as M2.*
2. Floor/support rule replacement only. *Done here as policy D1.*
3. Body single bound only, at the declared margin. *Done (table in README).*
4. Open3D TSDF comparator on the 265-frame split, with the 29 held-out frames used for depth-error checking. *Not run.*
5. **Freeze** the map, margin, flag policy, 20 route pairs and seeds. Write the v3 protocol.
6. Score the frozen map against FARO (evaluator only). No map edits afterwards; a new map is a new version.
7. Run the 20 × 5 game with the Swift worker and report arrivals, moving collisions, initial overlaps, stops, unavailable routes and execution failures separately.
8. Supervised device trials per AGENTS.md. Live ARKit confidence and the belt replace the offline gaps.

## Caveat on my own policy D1

I chose the 2 m near-range cut from the error table, but I also tried 1.5 m after seeing results. That is a researcher degree of freedom. Policy D1 is therefore a **diagnostic showing the cause**, not a protocol result. It must be re-frozen (or replaced by a pre-registered rule tied to σ(range)) before any score is called a result.
