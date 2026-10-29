# Second-layer manual-window Coffee repair — source + authored controls

This is a separate offline experiment requested after the first actual Coffee comparison. **No actual Coffee native rerun has occurred for this variant.** Existing source, all original paths and first result remain unchanged.

## Recounted first result

`BASELINE_PUBLIC_SAFE_RECOUNT.json` independently recounts existing attempt001 without coordinates/images. Source commit `c76d848a87fd0ca7db0065f4505e3bdd192cb3d8`; proposal SHA256 `1ed63feebdbffbc24b783a1d7691b1a0520a118a013dd8589e298a2c00a6ae29`. Six directed proposals among endpoints 0/1/8; fourteen disconnected involving 6/7. For 0→8, shortest grid 6.621808 m, centered 7.025880 m; interior residual-navmesh-wall proxy improved 0→.229962 m. All three original/distance/centered arms still contacted the **manual diagnostic windows**. First guard completed with 8.279165 CPU seconds, 8.302535 wall seconds, 118,046,720 bytes observed peak aggregate RSS. This does not establish body/support clearance.

## New single-pair arm

- Use the same unchanged Coffee mesh, rebuilt Coffee002 native binary, stage55 graph sampler, strict requested/projected endpoint association and existing SciPy selector. No custom search, mesh surgery, exclusion voxelization, build/install or app wiring.
- First reconstruct the original unfiltered 0→8 grid result and require exact geometry/length/cap equality with the pinned first run. Preserve its complete three-arm record under `baselineArmsUnchanged`.
- Use maintained installed GEOS through the independent validator's pinned C API adapter to remove each graph edge whose centerline distance to either predeclared manual window is at most `hypot(.45,.30)/2 + .15 + 1e-8` metres. Both directions share the same symmetric segment predicate. Free each temporary GEOS segment immediately; do not accumulate per-edge objects.
- Check exact requested-to-projected start/goal connectors using that same conservative predicate before searching; endpoints receive no exemption. A blocked connector or disconnected filtered graph remains a reportable refusal, never a substitute endpoint.
- Reuse the existing SciPy selector twice: shortest filtered length first, then its clearance-tier/integral-clearance objective with an allowance calculated to enforce the **same original unfiltered length cap** (`1.5 × original shortest + .5 m`). Filtering cannot silently enlarge the detour budget. No smoothing/funnel after selection.
- Independently call the existing `diagnose_manual_windows` adapter on complete connector-inclusive output. A contact becomes `independentManualVetoAfterRepair`; missing candidate status is retained. Both distance-only filtered and clearance-filtered arms receive diagnostics.

**Manual windows are not measured table boundaries.** This circle encloses the actual rectangle at every yaw with a radial .15 m buffer; it is not proof of the larger corner extent from an axiswise rectangular-margin OBB model. It does not check table height, unknown objects, floor support, slopes, mesh holes, closed-solid containment, fresh sensors or real localization. The original `.45 × .30 × 1.60 m` body and separate `.15 m` margin remain declared; full 3D rectangular body/margin checks remain required. No-intersection means only no intersection with these exact 2D manual exclusions. `physicalAuthority` stays false, full 3D body/support unvalidated, and all live use remains unknown/unapproved.

## Executed small controls

`CONTROL_RESULT.json`: 12 authored GEOS/SciPy controls passed under 10 CPU seconds /20 wall seconds /512 MiB address-space limit; .934 s wall, 52,040 KiB peak RSS. Checks include unchanged input graph, crossing-edge removal, reroute with existing solver, independent final no-intersection, original detour bound, physical unknown, overlong/disconnected refusals, connector veto, body-margin grazing, coincident edge and empty-window refusal. These fixtures are not actual room tests or evidence of source-table coverage.

## Prepared native run, root review/admission only

`SOURCE_PINS.json` binds 31 inputs including unchanged selector, first actual result, original mesh/source, already-built native binary and GEOS bytes. `run_aggregate.py` is the first guard adapted only to require one pair `(0,8)` and report the repair status. Fresh owned output is `coffee-clearance-comparison-attempt-002`; original outputs are untouched. Limits: one CPU,120 CPU seconds /180 wall seconds /1 GiB observed aggregate RSS /16 MiB output. No compile/install command exists. Imported source is pinned, committed bytes checked, fresh bytecode-cache prefix and before/after pins retained. Runtime is not a hermetic shared-library closure.

After independent review and exact-source publication, root alone admits:

```
python research/clearance-first-coffee-repair-source-20261029/run_aggregate.py \
  --admitted-source-commit <exact HEAD>
```

The worker may return disconnected, over-budget-detour, connector-blocked or a candidate with separate manual-nointersection. None becomes full physical acceptance. Conference/other-room work follows this result, not hidden retuning or expansion of this run.

Review clarification: the final GEOS pass is independent of Detour's search, but uses the same manual window geometry and GEOS library as pruning; it is not independent physical evidence. The filter budget counts unique tested segments, not individual distance calls (two per segment for the two frozen windows). Independent source review found no scoped blocker; no native rerun was performed during review.
