# Coffee: fixed-map local routes, not a whole-room traverse

The existing supplied corrected Coffee map was tested without any download or map change. **This is the older b0be8628 `coffee_floorfix` split-0.7 candidate, NOT the latest Opus color/v3 candidate, which is not available locally.** Dataset name `coffee_room` does not independently establish a public cafe, customer-access semantics or a verified traversable customer route. Seven phone-only endpoints were frozen before any native query. They span 5.0 x 3.1 m. Every ordered pair was tested with each unchanged profile (42 queries/profile).

| Profile | Accepted sampled-mask routes | Longest accepted path | Largest accepted endpoint displacement |
|---|---:|---:|---:|
| 45 x 30 x 160 cm, zero margin | 16/42 | 2.12248 m | 2.05 m |
| Same body, 5 cm margin each side; 55 x 40 cm footprint | 14/42 | 2.15127 m | 2.05 m |
| Abstract 28 x 30 x 160 cm, zero margin | 18/42 | 2.08849 m | 2.05 m |

Each count includes two trivial 5 cm queries. Only two ordered accepted routes per profile are >=2 m. Every accepted route touches retained low-unresolved cells. These counts do not mean percentage of room area covered or physical passes.

## Why the broad routes failed

All three profiles have exactly the same 24 native-incomplete cross-group queries: endpoints {0,1,5, 6} versus {2,3,4}. Native endpoint association is not the cause: maximum horizontal projection shift is 2.13e-7 m. The full partial native routes and requested/projected positions are retained.

All seven endpoints lie in one raw 4-connected phone-walk component (6, 651 cells). However, centre-clearance diagnostic masks at each unchanged proposal radius (0.150, 0.225 and 0.275 m) separate the two endpoint groups; 8-neighbor connectivity has the same split. This corroborates a narrow-mask-connection limitation, but is not an enumeration of native polygons or a proof that no orientation-aware rectangle path exists.

The maximum retained sampled-grid EDT lower-bound threshold connecting endpoint 0 to 2 is only 0.01464466 m for both 4- and 8-neighbor connectivity. The next distinct threshold, 0.03535534 m, disconnects them. These numbers are conservative grid-centre diagnostics, NOT a measured physical passage width or verified body clearance.

A magenta point-grid connectivity witness in `postrun/COFFEE_FAILURE_LOCALIZATION.png` shows where this thin connection can run; it is NOT an accepted body route. Around its minimum-clearance cells, 158 blocked phone cells carry overlapping evidence: 120 highObstacle, 37 low1, 25 missingSupport, 15 nearDip, 6 highUnknown. Nearby walk cells include 189 retained low-unresolved flags. The plot does not establish which physical objects or doorways those cells represent. No alternative orientation-aware planner, new map threshold or endpoint substitution was tried.

## Evidence and boundaries

- Frozen manifest: `FROZEN.json`, SHA256 `cf52680013ba59c6427f8bbd12d85e15ed09436342be9dfd93e7e35b03a6fa74`.
- Full outcomes: `run-01/result/`; raw query/association failures are retained.
- Independent saved-evidence audit: `independent/REVIEW.md` and `RECOUNT.json` verify all 18 pinned hashes, all 42 ordered pairs/profile, exact accepted endpoints and saved path-length arithmetic.
- Phone-only explanatory localization: `postrun/LOCALIZATION.json`, `DIAGNOSTIC_SCOPE.md`, and PNG.
- Bounded route run: 1.685 CPU s, 1.713 wall s, 57,110,528 bytes peak sampled/waited RSS; success. Resource enforcement is sampled, not cgroup-wide.
- Uses the externally supplied b0be8628 `coffee_floorfix` split-0.7 map. Coffee raw depth reconstruction was NOT rerun here. The 5 cm source mask is not improved to 2.5 cm sensor resolution by the finer native planner grid.
- Planner materializes exactly eight phone flag arrays plus lo,res,R,t metadata; no reference arrays/geometry enter selection or route validation. Full-file hashing is identity checking, not reference-array planning.
- **Zero actor movement episodes, zero physical movements, zero FARO triangle-scored episodes.** Height is declared but route/body checks are sampled and planar. No live safety or whole-room traversability is established.

## Next needed resource, not a completed validation

The official Coffee FARO bundle is exactly 288,148,502 bytes (record 10222321; MD5 d051bb90179d53374c1bb0c6ec4b0745). Its archive alone exceeds currently available storage above the 768 MiB reserve; uncompressed mesh member size is not yet verified. `REFERENCE_RESOURCE_BLOCKER.json` records the exact free-space observation. Triangle scoring additionally needs the validated mesh and `icp_iphone.json`/coordinate contract, followed by a separately frozen simulated movement episode. Saved vertex-column proxy arrays cannot substitute for that mesh. No archive was downloaded and no file was deleted.

## Later isolated reference-column triage (not planning)

After phone-only outcomes and the diagnostic neighborhood were fixed, the maintainer requested a postrun join to existing saved reference-column proxies. Neither map, endpoints nor route outcomes were changed. This is explicitly not a triangle-scored movement test.

This neighborhood surrounds minimum-clearance cells of ONE selected point-grid witness; it is not a census of every bottleneck or possible passage. Of 158 blocked cells in that phone-selected neighborhood, 93 have reference low/body-band geometry, 47 have a reference floor proxy with no saved obstacle-band vertices, and 18 lack a floor proxy. Of 120 highObstacle cells, 92 have saved reference obstacle geometry; 10 have only the floor-without-saved-obstacle proxy, and 18 lack a floor proxy. Thus there is no support for casually labeling the high-obstacle barrier false.

Follow-up candidates are more visible in missing support (20 of 25 cells have floor-without-saved-obstacle proxies) and nearDip (15 of 15). Even these are not established contradictions: the reference floor proxy averages available vertices within +/-6 cm, which can overlap real phone dip heights. The reference body band is 0.30–1.80 m, not the exact 1.60 m body. These are not proven false blockers: missing triangle interiors, sparse reference samples, height bands and registration uncertainty remain. All 6 highUnknown cells lack reference coverage, so the proxy cannot resolve them. The already-declared point witness itself has 5 reference body-band columns among its 32 minimum-clearance cells.

`reference-proxy-diagnostic/RESULT.json` retains each blocked cell's source index, coordinates, overlapping phone flags and saved reference-column values. Its reference arrays were loaded only in this later diagnostic process and never supplied to a planner. Raw Coffee colour/depth frames and occupied/free leaf clouds are absent; the local NPZ contains collapsed flags/statistics and an ungrounded mask, not source leaf/frame evidence. Whether a particular cell is a real object, pose/floor error or coverage gap cannot yet be established. No image-based object/doorway semantics are claimed.
