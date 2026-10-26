# Pose-consistency check — why some views put the floor 3–6 cm off (Koivu, 2026-10-26)

Response to the floor/routing diagnostic at master `7506ad9`. Phone data only; the reference is used once, at the end, as evaluator. No map, route or movement result is produced here.

## 1. Per-frame floor planes (all 294 frames) — `scripts/cause.py`, `per_frame_floor.json`

Each frame's floor is fitted robustly (iterative trimmed least squares, LiDAR-native samples ≤4 m, ±15 cm of the global plane) in the same level frame as `pipeline2_out.npz`.

- 252 frames give a fit. Median tilt 0.63°, median offset −0.37 cm (p5/p95 −1.96 / +3.25 cm).
- 78 frames exceed |offset| > 2.5 cm or tilt > 1.2°. They come in **consecutive runs**: 8–15, 22–28, 36–41, 55–56, **60–69**, 100–112, **116–120**, 128–132, … Frames 60–63: +5.2 to +5.7 cm, 1.7–2.1°. Frames 116–119: −2.3 to −3.6 cm.
- Within-frame residuals stay 2.5–5 mm, so each bad frame's floor is a clean plane in the wrong place.

A depth or intrinsics calibration bias would affect all frames alike; real floor shape would follow location, not time. Combined with the other session's cell [44,171] result (near endpoints from frames 62–64 at +76 mm vs other frames' far endpoints at +5 mm, same cell), this points to **pose error in temporal runs**, i.e. tracking drift episodes in the recorded trajectory.

## 2. Does non-floor geometry predict the floor error? — `scripts/icp_check.py`, `icp_check.json`

Released Open3D (0.20.0, MIT) point-to-plane ICP aligns each test frame to a cloud from temporally distant frames (|Δframe| > 25), using **only points 0.20–2.2 m above the floor** (walls, furniture). The floor is then re-fitted.

| Frame | ICP rotation / translation | Floor offset before → after | Floor tilt before → after |
|---|---|---:|---:|
| 60 | 2.85° / (20.1, 1.3, −4.2) cm | +5.74 → −1.01 cm | 1.77 → 0.76° |
| 61 | 3.08° / (19.9, 4.5, −7.9) cm | +5.44 → −0.01 cm | 1.80 → 0.71° |
| 62 | 1.06° / (11.0, −4.1, −1.6) cm | +5.67 → +2.72 cm | 2.09 → 1.71° |
| 63 | 1.40° / (12.1, −4.4, 1.4) cm | +5.24 → +1.91 cm | 1.68 → 0.92° |
| 118 | 2.80° / (3.7, −13.5, −2.7) cm | −3.55 → +0.01 cm | 0.52 → 1.05° |
| control 250 | 0.37° | −1.68 → −1.65 cm | 0.22 → 0.36° |
| control 30 | 2.02° | −0.90 → −0.22 cm | 0.25 → **2.09°** |
| control 200 | 3.03° | −0.58 → **+3.98 cm** | 0.17 → **1.18°** |

- In all five suspect frames, aligning **walls and furniture alone** moves the floor most of the way back. That is independent evidence of rigid pose error, and the ICP translations suggest 10–20 cm **horizontal** misplacement too, which would smear obstacles into passages.
- **Single-frame ICP is not a usable correction**: on two of three good control frames it introduced 2–3° rotation and up to +4 cm floor offset. Any pose correction needs a joint method with odometry priors and held-out validation, not per-frame alignment.

## 3. How much false blockage do the inconsistent frames cause? — `scripts/gate_check.py`

D1 low-band obstacle cells (supported, not also high), Koivu 5 cm: 574.

| Low-band evidence source | Cells | Reference-real |
|---|---:|---:|
| only from pose-inconsistent frames | **194** | **4 (2 %)** |
| includes consistent frames | 65 | 7 (11 %) |
| no near-range low-band hits (far-only) | 315 | 45 (14 %) |

A third of the false low obstacles come only from the inconsistent runs. But 4 of those cells are real, so dropping those frames' evidence would remove real obstacles. Such cells must become **unresolved**, not free.

## 4. Verdict on the question asked

The main failure is **both**, in a specific order:
1. The routing mask classifies against one global floor plane, and the per-frame offsets are computed after classification and never feed it. This is a real defect (in `pipeline2.py`, which I wrote).
2. The reason a global plane fails here is **pose drift in runs of frames** (3–6 cm vertical, 1.5–3° tilt, likely 10–20 cm horizontal). It is not a units/axes/projection error, not a shared calibration bias, and the evidence does not support real floor shape in the inspected passage.

A local-floor classifier alone would accept a mis-posed frame's floor as "local support at +6 cm" and would leave the horizontal smear. The correction belongs at the pose-consistency layer first.

## 5. Smallest reproducible correction (recommended order)

1. **Gate, don't delete (smallest; no new algorithm).** Mark frames whose own floor plane disagrees with the consensus beyond the measured spread as pose-inconsistent. Their hits remain stored. Cells whose obstacle or support evidence comes **only** from such frames become `unresolved: pose-inconsistent`, never free. Thresholds are frozen from the per-frame distribution on Koivu, then tested on the holdout.
2. **Joint pose refinement with a released tool, validated before use.** Open3D multiway registration (pose graph: odometry edges from the recorded poses + ICP loop edges, global LM optimisation), or RTAB-Map offline reprocessing. Acceptance: held-out-frame depth consistency improves, **control frames do not degrade**, and non-floor surfaces agree better; only then re-fuse.
3. **Then local support**, as the other review proposes: per-patch support height, slope and uncertainty from consistent frames; obstacle heights relative to local support; conflicts and unseen holes stay unresolved; no plane extrapolation.
4. Re-score safety-first (open-floor misses must not rise) on both rooms before any route or movement claim.
