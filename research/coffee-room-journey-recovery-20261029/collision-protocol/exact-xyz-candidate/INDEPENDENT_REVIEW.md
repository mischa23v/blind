# Independent exact-XYZ candidate review — 2026-10-29

Reviewed as an isolated diagnostic candidate, not an approved navigation/default policy. No NumPy/SciPy/VTK import, native control or comparison was executed by this reviewer. Only source inspection, AST/hash checks and bounded standard-library edge arithmetic were performed.

## Concrete finding

The authored `from_scorer` copied `hashlib.sha256` from upstream without importing `hashlib`. This would fail the two candidate bound-owner/contact tests and real ground construction. Author was asked to add only the missing import and refresh the candidate source freeze. Final disposition and hashes are recorded below after that correction; no original file needs to change.

## Invariants and mode isolation

Reviewed the full candidate adapter and worker diff against the immutable originals. The adapter creates exact coordinate-equivalence keys via NumPy unique on finite float64 XYZ, then delegates slope, patch eligibility, original face selection, shared-edge connectivity and all-nine-seed requirements to the unchanged upstream method. It does not mutate mesh arrays, add faces, interpolate points or use distance tolerance. A 1e-12 separation remains distinct; +0/-0 compare equal as floating coordinate values, not bitwise payload identities. No source NaNs or non-double inputs are accepted.

The copied `from_scorer` changes only the `vertex_coordinates=points` call argument; normals use original coordinates in the existing frame. The same slope <=5°, fixed patch, nine seeds, immutable original triangle-ID list, owner/mesh revision and transform binding remain. No boundary-edge orientation/manifoldness or semantic-floor classifier is added. Exact-key adjacency intentionally joins all faces sharing an undirected canonical edge, including ambiguous coincident sheets if present.

The worker is a separate filename and class import, with original SOURCE_PINS verified as well as CANDIDATE_PINS and explicit `exact-xyz-shared-edge-v1` argument. Mode identity is emitted in every log row and receipt. Its geometry, original XYZ/face IDs, raw A and A/B count invariance, .45 x .30 x 1.60 m body, .15 m margin, fixed events and existing C vertical-follow logic remain unchanged. Existing original controls are still imported directly; ten candidate controls are added, not substituted. Fifty-seven prepared tests are not fifty-seven passing tests.

## Component growth and ambiguity inspection

`review_edges_stdlib.py` reconstructs the source adjacency using only standard-library original OBJ/previous probes/frozen route data; it never calls native locators or collision code. Limits: 10 CPU seconds, 20-second external timeout, 512 MiB address space. Actual 1.383 CPU / 1.383 wall seconds and 82,817,024 bytes maximum RSS. Mesh hash is unchanged `f10de085426143ad095fefc713b4966d22fdf08beda9ff9ead759019a0a8306a`.

Across all twenty path seed components: **80–346 newly joined cross-original-index edges per path; zero canonical edges with more than two incident faces; zero exact duplicate triangles.** Largest selected component has 3,492 faces. `EDGE_AMBIGUITY_REVIEW.json` retains per-path counts. The four start-0 records select the remaining eligible seed component for inspection; they do not admit the ineligible ninth seed. Source diagnosis's 193→958 (6→0) and 216→3,492 (8→0) growth is real and substantial, not assumed harmless.

These checks find no non-manifold-edge or duplicate-triangle signature within the relevant components. They do not prove surface semantic identity, exclude intersecting triangles that do not share complete edges, or disambiguate two different sheets touching along an exact edge. That remaining uncertainty is acceptable only for this explicitly labelled comparison, never physical ground/clearance acceptance.

## Interpretation retained

Eight source-index seam failures are candidates to become ground-available; four start-0 failures must retain 5.7154° versus 5° rejection. Start-6 elevated body/contact witnesses remain actual source-geometry candidates; start-8 near-floor margin witnesses may be relabelled only if genuinely in the candidate component. Neither possibility is a measured result yet. Do not enlarge thresholds or erase witnesses to get a pass.

The original twenty native proposals and prior receipts remain immutable. Missing tabletops and the user's visual rejection of the longest route still override any practical clearance claim; same-mesh no-hit cannot repair missing geometry. Nine rays are not full-footprint support. No native accuracy, real journey success, physical collision or app activation follows from this review.

## Final source disposition

Missing import is corrected and independently verified. Candidate manifest SHA256 `e8c54ff7e7b767847a8eeee98e12d18f7b75d84920c622a6295ab6a2d2393911`; corrected adapter SHA256 `4f3d966f2316fa385f5ce3c67f73334a9412e00011cac6ae4847a22db5ce518b`. No remaining candidate-core source blocker identified for a separately admitted bounded diagnostic run. The new aggregate adapter still needs root/independent guard review; source review is not execution acceptance.
