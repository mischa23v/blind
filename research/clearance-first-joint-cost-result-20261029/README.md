# Actual Coffee joint-cost result — source-bound saved-result review

**The new ranking gives the manual exclusions more room, at a modest route-length
cost. This is not a passed physical journey or proof of exact table/chair centering.**

| Actual 0→8 arm | Grid path length | Smallest residual beyond body circle + .15 m, against manual windows |
|---|---:|---:|
| Previous repaired-centered | 7.238872 m | 3.847740 mm |
| New joint-ranked | 7.502607 m | 129.583630 mm |
| Repaired shortest, unchanged | 6.967847 m | 3.847740 mm |

The joint path adds **0.263735 m / 3.64%** and raises that manual-window residual
by **125.735891 mm**. Its connector-inclusive length is **7.540722 m**. All
**143 connector-inclusive saved segments × 2 windows = 286 checks** are present
and report no contact. The north-window minimum improves from .003848 to .129584 m;
the south-window minimum improves from .379584 to .479584 m.

**There is a tradeoff:** the independently resampled native-wall **p10 proxy**
decreases from .254962 to .154962 m. Its sampled minimum stays .121720 m. Native
wall distance is a separate, already-eroded-navmesh-boundary proxy, not measured
physical-object clearance. These channels are not combined into a safety score.

## What was preserved and verified

- Exact native source: `1882514d76452b15107bb61ca192533052dd64ed`;
  manifest `5f8e77402668621827362c2f6acba1b4fdc2165b3712b1521961b74cffe189c6`.
- Both original baseline arms and both previous repaired arms are exactly
  retained. Shortest-repair geometry and complete saved manual diagnostics are
  unchanged. Requested/projected endpoints and all five associations are equal.
- Body .45 × .30 × 1.60 m and separate .15 m margin are unchanged. The same
  conservative radial circle is .4204163457 m. The **native-grid** length cap
  remains 10.4327119677 m; requested connector length was not charged to this cap
  before or after, but complete connector geometry is checked and reported.
- All 40 current input hashes match the guard; before/after hashes agree.
  Proposal hash/size match the terminal inventory. Guard, 35 authored controls
  and comparison exited zero; both process groups retired.
- Actual run: **5.776540 CPU s, 5.790637 wall s, 121,171,968 bytes** peak observed
  aggregate RSS. These measurements cover the completed guard, not physical
  accuracy or a whole user journey.

Before that run, the fixed five-second `git show` preflight timeout stopped a lazy
blob fetch **before an attempt directory or native execution**. Root cached the
already remote-verified source bytes as local Git objects, then ran the unchanged
guard. That failure is retained in `coordination/joint-preflight-001/RESULT.json`
and its coordinate-free facts/hash in `PUBLIC_SAFE_RESULT.json`. No timeout,
test, policy, profile or source pin was loosened or ignored.

## Limits and next evidence

Manual windows are not measured table boundaries. The source mesh still cannot
establish objects absent from it. No complete 3D body/turn/overhang collision,
whole-footprint support, current sensor coverage, localization, or live guidance
authority is established. The ranking does not establish equal physical
distances from a table and chair. This is one fixed Coffee pair, not conference-room
acceptance, all-room robustness, a full loop or a successful blind-user journey.

Next comparisons should retain these parameters and failures, use measured
obstacle/support evidence, and test the conference room and other frozen cases
without tuning to this route.

## Files and reproduction

`PUBLIC_SAFE_RESULT.json` is a text-only, coordinate-free recount. `recount.py`
reads saved result/guard records and checks their consistency; it does not query
GEOS, native navigation or a mapper. `plot.py` / `coffee-joint-cost-comparison.png`
/ `PLOT_RECEIPT.json` show saved paths over the original public source mesh with
equal metre axes and explicit caveats. Projected gray/blank mesh regions do not
establish free space or support. No archives were created or uploaded.

From the same workspace, without rerunning native planning:

```sh
python -B research/clearance-first-joint-cost-result-20261029/recount.py
env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
  PYTHONDONTWRITEBYTECODE=1 timeout 20s bash -c \
  'ulimit -t 10; ulimit -v 524288; python research/clearance-first-joint-cost-result-20261029/plot.py'
```

Publish only this folder's `README.md`, `PUBLIC_SAFE_RESULT.json`, `recount.py`,
`plot.py`, `PLOT_RECEIPT.json`, `coffee-joint-cost-comparison.png` and the separately
reviewed `INDEPENDENT_REVIEW.md`. Do not infer permission for body/source archives
from this text-and-figure result publication.
