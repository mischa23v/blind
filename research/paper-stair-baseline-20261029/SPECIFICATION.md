# Paper-derived stair reference candidate — specification freeze v1

2026-10-29. **Review gate: no implementation until independent review.** Research-only; not official SensoryScape code, not integrated into the app, not navigation/clearance authority. Synthetic logic tests cannot reproduce 111/120 physical trials.

Primary source: Herdt et al., Scientific Reports (2026), DOI https://doi.org/10.1038/s41598-026-73419-5 . Page numbers below are 1-based PDF pages in `coordination/paper-925-review-20261029/publisher.pdf` (SHA256 c8bbe4165a9488579012d4ea368f63c48e041bd690636168801304c95c053942). Full §3 reread. No author-released code located; published XLSX is outcomes only. User explicitly authorized a labeled method reproduction despite this upstream gap.

## P: Published clauses (not implementation guesses)

| ID | Clause | Source |
|---|---|---|
| P01 | Eight mesh raycasts per frame; mapping cycle 60 Hz. Device-relative forward 0°, left -30° yaw, right +30° yaw, Up +20°, Down1 -30°, Down2 -60°, Lower approximately -75°. Floor Detector steeply downward, no numeric angle. Actual world directions depend on camera pitch. | §3.1 p5 |
| P02 | Floor calibration: ARKit floor-classified Floor Detector and downward intercepts; median **for each ray** over rolling 30-frame window. Confidence from buffer variance, formula absent. Initial camera-height manual fallback permitted. | §3.1 p6 |
| P03 | Descending pair Down2/Floor Detector: downward slope away, negative dot with camera-forward segment direction and minimum vertical span 4 cm. Forward/Lower lip segment; Down1/Down2 additional away-slope indicator. | §3.2 p6 |
| P04 | Elevation candidate segment tilt 5–50° from vertical; general case requires at least two independent qualifying ray pairs simultaneously. No listed special-case predicates. | §3.2 pp6–7 |
| P05 | Descending candidate persists four consecutive frames before alert. Fixed 3s inhibition after each alert, implemented as frame-counter reset. | §3.2 p7 |
| P06 | Lower–Forward lower segment; Forward–Up upper segment; compute each angle from vertical. Upper ≤25° => wall/no elevation alert from this branch. Upper ≥65° and lower 10–50° => tripping hazard. Both 10–50° and agreement ≤15° => staircase. Staircase classification travel-direction-independent, including descending stairs. | §3.3 p7 |
| P07 | Stair confidence derived from deviation from nominal 34°; formula absent. | §3.3 p7 |
| P08 | Spoken type/angular offset, three-pulse haptic; ascending/descending channels independently rate-limited; modes descending/ascending/both/none. Thresholds fixed before evaluation; depth threshold mentioned but not numerically specified beyond P03. | §3.4 p7 |

## U: Unresolved author semantics — never silently fill in

1. Directed endpoint order for P03 dot tests; which pair-specific predicates span/tilt/away apply to beyond explicitly described first pair; meaning of “general case” versus exceptions.
2. Angle uses signed or acute undirected vertical angle; world gravity versus device vertical not explicitly defined. No formal coordinate system/transform equations.
3. Floor Detector angle; per-ray medians combined into single floor height; missing samples within 30-frame window; minimum valid samples; variance/confidence formula; floor estimate's actual role in detection thresholds. No extra drop-height threshold supplied.
4. Four-frame/cooldown explicitly in descending section only. Ascending persistence/cooldown unspecified; do not transfer 4/3 automatically. At 60Hz 3s=180frames, but dropped-frame and exact decrement/expiry semantics unspecified.
5. Missing hit, degraded tracking, pose jump, frame gap, invalid timestamp, mismatched coordinate frame, stale mesh, uncertain classification behavior unspecified. No confidence cutoffs or jitter tolerance supplied.
6. Cross-branch wall/descending conflict resolution and rate-limit treatment of direction-independent staircase unspecified. Persistence identity (same pair/type/location) unspecified. No optical occlusion test described.

## E: Explicit experimental adapter choices proposed for review

These choices make a deterministic **partial reference** possible, not a claim to original behavior. Emit evidence and unknowns, not safe/clear/move/turn/step commands.

- Input: monotonic frame index and seconds, coordinate-frame/session ID, normal/limited/unavailable tracking, world camera origin and normalized forward vector, measured gravity direction, typed ray hits with same-frame position and semantic classification. Floor Detector supplied as a hit; **do not generate its angle**. Caller chooses all mesh ray-generation conventions. Unknown/no-hit never means free space.
- Geometry: normalize gravity; acute line tilt `acos(abs(dot(unitSegment, unitGravity)))`; reject nonfinite/zero segment/gravity/forward. This world-gravity/acute convention is an E choice. The endpoint sign for descending must be **required explicit configuration per pair**, not a hidden default. Report pair angle, signed dot, span, and pass/fail. Require two pairs in the general-case implementation; unreported special cases unimplemented. Generalized minimum span and negative-dot checks on all three pairs are an explicit more-restrictive E rule (can increase misses; not a safety guarantee), not P text.
- Ascending branch computes raw classification by P06. No invented confidence score, no ascending temporal alert without explicitly supplied research configuration; alternatively expose raw candidate only. Do not turn wall evidence into clearance. Retain descending and ascending branch evidence separately; do not invent priority.
- Floor calibration exposes per-ray medians/variance/sample counts only. Ring buffer is last 30 **frames**, with absent/non-floor samples occupying their frame but omitted from median; no single combined floor estimate or confidence. Current missing Floor Detector yields explicit incomplete/unknown status, even if diagnostic pair results remain available. Manual fallback not implemented until its consumer meaning is defined.
- Temporal descending component: four consecutive accepted frame indices with candidate true; a false, unknown, gap, tracking failure, frame-ID change or nonmonotonic time resets persistence. No replayed frame counts. Inhibition180 frame indices at nominal60Hz; output elapsed seconds too and flag cadence mismatch, do not pretend variable-FPS behavior is published. Exact boundary: first later frame with index difference ≥180 is eligible. This boundary and reset semantics are E choices. Keep cooldown through unknown/reset within session; session change resets research state and reports unknown for that frame.
- Missing essential validity/gravity/frame/hits => unknown; never “no hazard.” Complete geometry with no rule match => “no candidate in supplied rays,” not negative scene/clearance. Geometric pose jitter beyond finite checks is not guessed: caller must supply a validity flag from a separately validated pose-quality gate; no pose-displacement threshold introduced.
- No AVSpeechSynthesizer, haptics, ARKit session, app target, network, persistence of camera data, navigation commands or device activation in package. Plain value types only.

## Planned synthetic fixtures, not measured detection trials

Analytic ray-hit tuples for ascending single step, same-angle staircase, descending lip, drop, flat floor, sloped ramp, vertical wall; obscured/missing hits, missing floor, invalid tracking/gravity, frame mismatch, pose-jitter validity rejection. Boundary fixtures at4cm,5/50°,10/50°,25/65°,15°; zero segment, NaN/Inf; 3-vs4 frames; unknown/gap reset; 179/180 cooldown boundary; channels don't inherit unspecified ascending constants. Some ramp tuples can satisfy the published stair angle rule: preserve that false-positive counterexample rather than invent a ramp suppressor.

## Native verification plan

Tiny dependency-free Swift package and XCTest source only until root review. After authorization, `swift test --jobs 1` with bounded memory on installed native toolchain; no Docker/install/model/network. Record never-run vs passing. Freeze source and fixture hashes. Python calculations may independently check analytic fixtures, not substitute for compiling Swift. Dataset selection is a separate source/licence/size manifest; no bulk download.

## Independent review resolution — v1.1

Reviewer `inspect_default_branch_merge` checked full §§3–4 on2026-10-29: source clauses match, approved with these explicit E details before code.

- Descending essential rays: Down2, Floor Detector, Forward, Lower, Down1. Ascending essential rays: Lower, Forward, Up. Missing essentials make that branch unknown; other branch diagnostics may survive. Missing current Floor Detector makes overall completeness unknown, never clearance; it does not erase independently available ascending evidence.
- Floor scalar is dot(world hit position, fixed session anti-gravity), relative to the fixed supplied world origin; session anti-gravity is normalized from the first valid frame and retained, not camera-relative. This is E, not assumed worldY. Reset buffers and basis on frame/session change or invalid temporal/pose/gravity input. Current measured gravity still supplies segment tilt. No unreported gravity-noise correction or confidence formula is added.
- Ascending wall-first precedence follows P06: upper≤25 wins even when both angles lie within10–50. No descending cross-branch wall veto is invented.
- Descending persistence accumulates qualifying accepted frames during cooldown (saturated at4). Thus the first eligible frame can emit if persistence is4. After an emitted marker persistence resets0. This E choice is not an author-specified counter implementation. Eligible means frameIndex-lastAlertIndex≥180, independently monotonic elapsed seconds is reported; non60Hz input is explicitly outside temporal equivalence to3s. The caller must not interpret this counter as elapsed-time protection at arbitrary FPS.
- No upward/descending channel scheduling is manufactured for ambiguous staircase direction: ascending branch returns raw type only; descending produces research-only event markers. These are not spoken warnings. This partial implementation deliberately omits unpublished ascending timing.

Gate: independent spec review complete; source may now be drafted for root review. Native compilation/testing and integration still not authorized by this spec.

Second independent reviewer `stage_binary_batch_two` agrees source clauses match. Resolved fixed-session floor basis and renamed generalized span/dot rules as more restrictive, not safety-conservative; these choices may increase missed hazards.

## Independent source-review corrections — v1.2,2026-10-29

- Cadence observation is explicit: first frame, invalid/nonfinite/nonpositive interval, replay, frame gap or session-change output is `unknown`; a valid consecutive accepted interval within an absolute1microsecond of1/60second is `nominal60HzWithinExperimentalTolerance`, otherwise `differentObservedCadence`. The1microsecond tolerance is solely an E diagnostic choice, **not** an author parameter or validated sensor tolerance. This is a per-interval observation, not a whole-window60Hz certification.180frame inhibition remains frame-based; it is not time-normalized. Different cadence does not silently alter the published-reference frame counter.
- Finite raw coordinates do not guarantee finite projected height/mean/variance. Reject nonfinite derived floor projection or statistics: expose `floorIncompleteReason`, empty floor summaries, overall incomplete reason, reset floor history/basis and candidate persistence, and inhibit the research marker for that frame. Available angular branch evidence remains diagnostic only. This is an E invalid-arithmetic guard, not a published hazard rule or confidence formula. Recovery starts a new floor buffer. Reject a nonfinite timestamp difference even when both timestamps were finite; never expose an infinite interval/elapsed diagnostic.
- Added source-only XCTest regressions for nominal/different/unknown cadence, diagnostic tolerance,1Hz180frame counter behavior, finite extreme mean/variance/projection overflow, and recovery. No native execution implied.
