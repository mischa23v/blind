# Coffee: smallest post-route full-body source-contact diagnostic

**Latest source review:** read `FRAME_AND_GROUND_FOLLOW_ADDENDUM.md` first. Current attempt002 paths are frozen in `CURRENT_PATHS_20.json`; the addendum adds explicitly reviewed rigid normalization, geometric annotation and separate existing vertical-follow comparisons. Original raw baseline remains unchanged.

2026-10-29. Source/data inspection only; no VTK/native import, test, build, install or motion execution. Priority is the existing 20 accepted original-mesh paths, not a new support framework. Root must separately admit a serial run.

## Frozen inputs and admission

`HISTORICAL_PATHS_20.json` preserves all 20 historical accepted query point arrays, requested starts/goals, and explicit start/goal association connectors. There are 124 full-chain edges before stationary/turn increments; zero-length edges remain recorded. It is NOT a new successful run. Require current attempt002's exact accepted path arrays and endpoints to match, and root's complete 72-query comparison to succeed, before using this freeze. Keep all rejected/partial original queries in the parent baseline record; do not substitute endpoints. Hash of this freeze: `738f9382ddc1d672abfc19fc45baa66a3d7ffa527d77cfdec89389c05a283972`.

Mesh available: `<caller-workspace>/coffee-recovered-source/textured.obj`, 10,497,144 bytes; fresh SHA256 matches `f10de085426143ad095fefc713b4966d22fdf08beda9ff9ead759019a0a8306a`. 51,965 vertices/87,370 triangles per retained source audit. Preserve original XYZ, face ordering and vertex IDs, identity model-to-source transform. Source-defined candidate Y-up is not physically verified gravity. This is supplied-geometry self-checking, not independent FARO truth or measured motion.

## Reuse source, not a new collision algorithm

All below at repository `mischa23v/blind`, revision `c79fbd33171f78608f9eb2a1484fbc9266e3a695`, under `research/tools/koivu-coffee-room-tests-v1/` (retrieved from local Git objects):

| File | SHA256 |
|---|---|
| `blind-split-candidate-game-03/source/oriented_container.py` | `f6c66faa66a30922b48833194814119c555c62b50ee308042483fbad08dfcda8` |
| `blind-opus-reference-scoring-audit-02/source/reference_band_box.py` | `18fdf528f5eb4c017ed0d94476babed57f94807323798984064679d419831ef1` |
| `blind-koivu-reference-comparison-06/reference_geometry.py` | `266026051a781f122a59187f599688e8c5eb38807984b7e607401e7b4356386d` |
| `blind-split-candidate-game-03/ground-follow-v2/oriented_ground_container.py` | `728860fa18f762f90b13f581e4b3cae474f4d8bf4223854252778802e405ea89` |
| `blind-split-candidate-game-03/ground-follow-v2/ground_support.py` | `095906c4cda9972e46751b511f46d41e2e541e2ebc44ebbb7da6dbe8240acfaf` |

Use `GroundedReferenceContainer.swept_contacts`, inherited from `OrientedReferenceContainer`, with the **existing all-candidate** `contact_corners` implementation. It uses VTK triangle/OBB intersection plus contained-triangle-vertex queries, not a newly written collision core. The base class alone stops at the first hit and can hide later obstacle contacts behind a floor hit. Even the all-hit version's first ID is locator order, NOT earliest physical contact time.

Defaults: width .45 m, depth .30 m, height 1.60 m; separate horizontal margin .15 m on each horizontal half extent; no vertical margin. Forward half extent .15, lateral .225; margin half extents .30/.375. Native radius .225 does not circumscribe the rectangle (corner radius about .2704 m). Preserve both scores and do not use native clearance as rectangular-body evidence.

Sweep OBB encloses linear translation and the explicit yaw interval; its midpoint axes include half projected translation plus rotation padding. It can overcount. Even a result named `actualBody` is conservative enclosure overlap, not proof that the physical rectangle hit. Full solid containment, missing-space coverage and continuous support remain unavailable.

## Floor self-contact: retain, classify unknown, never clear a band

The existing bottom is `min(startY,endY)+.002`, top `max(startY,endY)+1.60`. Keep the declared 2 mm exclusion unchanged and disclose that this thin bottom slice is not queried. Coffee candidate floor is around -1.6301633051396203; original mesh is not flat. Its candidate-plane centroid residual P95 is about 7.50 mm in the retained audit. Thus floor-associated raw contacts are plausible, not a reason to lift the body, flatten geometry or delete low hazards. Do not classify by whole-triangle Y range as if it were the contact point.

**Where existing ground IDs come from:** `GroundSupport.from_candidates` admits only <=5-degree slope-eligible triangles within a fixed patch, shared-original-vertex-ID-edge connected to ALL nine initial support-ray IDs. It does not weld positions, bridge by proximity, or allow a step. Membership is immutable and bound to surface owner, mesh revision and exact transform. It still explicitly lacks semantic-ground labels.

**Coffee incompatibility:** `from_scorer` hardcodes patch Y[-.25,+.25]; inherited support rays use absolute +.15 to -.25. These miss Coffee's source frame. Do not call those helpers unchanged, offset the source, enlarge the band until it passes, or silently invent a new seed/height contract. Orientation audit's 4,247 lowest-bin candidate triangles are NOT a justified exemption set.

**Smallest first-run policy:** use an explicitly empty, immutable `GroundSupport` annotation set, owner/revision/identity-transform bound using the existing dataclass constructor, with receipt `groundClassification=unknown`, `seedComponentComputed=false`. This is deliberately **not** a successful `from_candidates` certificate. No original triangle is exempted. Root review must verify the empty annotation binding and output mapping before execution. Published all-hit traversal then returns complete raw contact counts as `groundContactCount + nonGroundContactCount`; with empty annotations every contact is **unclassified**, not a known obstacle. `groundContactCount=0` means no assigned labels, not no floor contacts.

Preserve native field names in raw receipts; presentation must call nonGround counts `unclassifiedRawContactCount` while labels are unknown. `obstacleConfirmedCount` is unavailable, not zero. Later a separately reviewed Coffee-specific ground annotation may partition the SAME raw contacts into ground-candidate and other; raw totals never disappear. Slope/connectivity alone cannot turn “other” into confirmed obstacles or ground candidate into safe floor. This avoids both floor masking and global low-height clearing.

Existing all-hit output retains complete counts but only the first non-ground witness and up to 16 ground IDs; it does NOT enumerate every contact ID. Preserve those exact IDs/triangles, explicit truncation, and original face-to-cell mapping. Do not advertise complete witness-ID lists or earliest time. Additional all-ID logging, if needed, is a separate reviewed instrumentation-only change to this same traversal.

## Motion contract to freeze before admission

These are authored replay paths, not recorded body heading or gait. Freeze the following proposed stop/turn/translate policy explicitly; `yawProtocolFrozen=false` remains in the input packet until root reviews its generated increments:

1. Start at each requested XYZ; include its connector to the first native path point, every native segment, and the final native-to-requested-goal connector, in full XYZ. Never move vertically to a chosen floor. Keep zero-length connector records and initial/final stationary footprint checks.
2. Define +X as forward at yaw 0, positive yaw toward +Z (existing source convention). Prescribe initial yaw along the first nonzero horizontal leg as an **authored** initial condition, not a measured heading. Before every changed horizontal direction, prescribe an in-place explicit signed yaw interval; choose the shortest interval with a fixed documented +pi tie. A pure vertical/zero-horizontal leg retains prior yaw. No undocumented final orientation demand.
3. Freeze deterministic increments <=.025 m translation and <=1 degree yaw, including turn locations before connectors and native corners; these reuse tested small-increment parameter scales, not a claim of physical timing/calibration. No shortcuts, smoothing or route repair. Separate turns/translations reduces enclosure overcount without altering the stated stop/turn/translate path. A tighter subdivision after seeing contacts would be a separately versioned diagnostic, never silent retry-to-pass.
4. Query nominal body and separate margin for every stationary/turn/translation increment, even after a first raw contact; this is diagnostic evaluation, not a controller executing through obstacles. Never feed contacts back as pose correction or report a movement episode.

## Bounded executable preparation and run proposal

Available interpreter: `<approved-runtime>/python3.12`; filesystem has VTK9.3.1, NumPy2.3.5 and SciPy1.17.0 distributions. Availability is filesystem evidence only; ABI/import/test compatibility is not established here. Source files/tests are in Git, not yet materialized as a runnable collision workspace. The separate W6 Float64 adapter is absent. Prepare minimal loading glue using the existing `run.py` triangle-OBJ parser and explicit VTK Double points/cells, preserving every original vertex/face ID; validate exact Float64 round trip and 87,370-cell correspondence before querying. Do not use a default reader that silently reduces coordinate precision or reorders/welds geometry.

After root's native baseline ends: freeze source/dependency hashes, complete increment schedule, output format and aggregate limits. One serial admission: existing source tests plus explicit empty-label mixed-floor/low-obstacle control, loader identity check, then the frozen 20 paths. Controls include a 1 cm low triangle, contained triangle, crossed wall with clear endpoints, turn-only hit, margin-only hit, and shifted Coffee-like floor; both raw floor and low-hazard counts must survive. Tests exist at `source/test_oriented_container.py` and `ground-follow-v2/test_oriented_ground_container.py`; their contents were inspected, not run. All failures/budget exhaustion are unknown, never clear.

Proposed caps for root review: <=10,000 frozen increments total (reject before VTK if exceeded), existing <=200,000 candidate triangles/query, one thread/one process, <=120 aggregate CPU seconds, <=180 wall seconds, <=1 GiB aggregate memory and <=16 MiB output. Use root's reviewed aggregate guard; do not call Python rlimits a hard process-tree memory bound. No automatic retries, installs, mesh variants, larger budgets or extra routes. If caps are insufficient, retain partial receipts and stop for review.

Outcome: for every path, total evaluated increments, first contacting increment in schedule (not precise time), raw nominal/margin overlap counts, annotation partition/unknown state, preserved witness IDs, conservative-overcount flag, support=unknown, coverage=unknown, physicalAuthority=false. No collision-free/safe path verdict from absence of modeled surface contact.

## Licenses and exact availability limits

- Source mesh provenance is MuSHRoom iPhone Basic Data, Xuqian Ren et al., CC BY4.0; retained acquisition/source receipts in `../SOURCE.md` link https://zenodo.org/records/10230733 and the official TUTvision/MuSHRoom project. No new remote license check performed in this source-only follow-up.
- Local VTK9.3.1 and NumPy2.3.5 installed LICENSE files carry BSD-three-clause-style terms; preserve their full notices and bundled dependency notices. SciPy is required by the existing ground-support import; inspect its exact installed notice during workspace preparation, not infer it from VTK's license.
- The published project-authored Python scorer files have no SPDX/license header, and no repository-root LICENSE was found in the pinned tree. They are existing code in the user's repository, NOT independently licensed CGAL/VTK upstream code. No separate open-source redistribution grant for those wrappers was verified; do not label the wrappers BSD merely because VTK is BSD. No external redistribution or license change is proposed.
- A broad `/tmp` directory listing encountered `Permission denied` for `an unrelated /tmp runtime directory`; no escalation/read attempt followed. All needed mesh/source evidence was available through the supplied workspace and pinned Git. No native collision operation executed.
