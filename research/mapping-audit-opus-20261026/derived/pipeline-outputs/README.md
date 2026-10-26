# Exact pipeline output arrays (for scoring reproduction)

Each `*_pipeline_out.npz` / `*_pipeline2_out.npz` is the array set written by the run whose receipt sits beside it, byte-identical to what the scoring numbers in `../../REFERENCE_SCORING.md`, `../../RESULTS.json` and the receipts were computed from. `SHA256SUMS.txt` covers every file here. The commit that adds them is the matching commit; `git log -- research/mapping-audit-opus-20261026/derived/pipeline-outputs` shows it.

| File | Produced by | Room | Voxel | Notes |
|---|---|---|---|---|
| `koivu_v1_pipeline_out.npz` | `scripts/pipeline.py` | Koivu (development) | 5 cm | arrays behind `REFERENCE_SCORING.md` and `koivu_PIPELINE_RECEIPT.json`; keys: `lo,R,t,state,mean,n,tail,refWalk,support,…,walk,lowUnresolvedFlag,ref_*` |
| `coffee_room_v1_pipeline_out.npz` | `scripts/pipeline.py` | coffee_room (holdout) | 5 cm | same layout |
| `koivu_5cm_v2_pipeline2_out.npz` | `scripts/pipeline2.py … 0.05 tsdf` | Koivu | 5 cm | variants `D1__*`, `D1_noUngrounded__*`, `TSDF_surface__*`, `state`, `ungrounded`, `refWalk`, `ref_*` |
| `coffee_5cm_v2_pipeline2_out.npz` | `scripts/pipeline2.py … 0.05 tsdf` | coffee_room | 5 cm | same |
| `koivu_2p5cm_v2_pipeline2_out.npz` | `scripts/pipeline2.py … 0.025` | Koivu | 2.5 cm | floor band tiled to ±3.75 cm by layer centres (see write-up caveat) |
| `*_fused_clouds.npz` | pipeline2 | | 5 cm | OctoMap occupied/free leaf centres for the all-range and ≤2 m trees (float32) |

Column arrays are indexed `[i, j]` with world x = `(i + lo[0]) * res`, y = `(j + lo[1]) * res` in the level frame (`R`, `t`: phone → level; floor plane at height 0). Reference arrays (`ref_*`) are evaluator-only.

The derived arrays come from the public CC BY 4.0 MuSHRoom data (Xuqian Ren et al.) and contain geometry only.
