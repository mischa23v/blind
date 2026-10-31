# Actual Coffee repair result — independently recounted saved evidence

**Second-layer manual-window repair completed, not physical-clearance validation.** Exact native source `3a0b3f1edf4167f781a043017b2169bda69f91ef`. Guard, authored controls and native comparison exited zero. No new native/GEOS queries were run for this recount or figure; frozen planner/filter code is unchanged.

| Actual 0→8 arm | Native path length | Manual-window body-circle + margin contact |
|---|---:|---|
| Original funnel | 6.189526 m | Yes |
| First centered | 7.025880 m | Yes |
| Repaired shortest | 6.967847 m | No |
| Repaired centered | 7.238872 m | No |

Repaired centered distance including exact requested connectors is **7.276987 m**. All 133 saved connector-inclusive segment records contain both window checks. The baseline arms are exactly unchanged; all eight current relevant source hashes match the completed guard inputs; all before/after input hashes agree. The original detour cap remains 10.432712 m. Filter removed 16,178 directed edges, retained 24,934, and checked 20,556 distinct undirected edges. Run resources: 4.125313 CPU seconds, 4.141660 wall seconds, 118,362,112 bytes peak observed aggregate RSS.

**Important: both repaired arms have only 3.85 mm extra residual beyond the declared body-circle + .15 m margin against these manual exclusions.** The repair prevents intersection with those windows; it does not establish robust centering away from them. The clearance ranking still uses native-mesh walls, while manual windows supply a hard separate veto. Windows are not measured tabletop boundaries. Full 3D collision, complete footprint support, missing obstacles and current pose remain unknown; no live guidance or physical authority follows.

## Recoverable evidence

- `PUBLIC_SAFE_RESULT.json`: coordinate-free recount, lengths, saved-check coverage, resources and pins. Its no-coordinate statement applies to that JSON only.
- `PROPOSALS.json.gz`: deterministic, complete raw attempt002 result (one newly repaired pair and preserved first-run baseline arms).
- `BASELINE_PROPOSALS.json.gz`: deterministic, complete raw attempt001 result (all20 canonical pairs), preserved for recovery of the repair's pinned input.
- `RECOVERY_MANIFEST.json`: compressed/uncompressed hashes and verified round trips. Gzip mtime0, no source filename; decompression restores exact original JSON bytes. These gzip records intentionally contain public dataset coordinates, not raw photos or an environment dump.
- `recount.py`: standard-library saved-result recount; no geometry engine queries.
- `coffee-before-after-manual-repair.png` / `plot.py` / `PLOT_RECEIPT.json`: actual original source mesh and saved paths, equal axes, body-circle profile and explicit manual-window limits. Triangle centroid bands are visualization only; blank/gray areas never establish free space or support. Route legend lengths exclude requested vertical connectors, matching saved native path-length fields.

Figure generated within 10 CPU seconds/20 wall seconds/512 MiB address space; final plotting phase1.186 s,120,936 KiB peak RSS. Pixels inspected; corrected an initial footer/axis-label overlap and clearer pre-repair wording. Initial font-cache warnings were resolved by a local writable cache. Final figure has no overlap and prominently retains physical-unknown and3.85mm caveats. Publish only listed evidence files, not `mpl-cache/` or `xdg-cache/`.
