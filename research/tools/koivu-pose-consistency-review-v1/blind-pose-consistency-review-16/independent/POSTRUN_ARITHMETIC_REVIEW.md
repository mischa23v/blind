# Post-run arithmetic addendum

The maintainer executed the separately authorized exact-source replay; this reviewer did **not** rerun source projection, depth scans, ICP, or fitting. The subsequent saved-array recount passed in **0.225 seconds**, with **56.9 MB peak RSS**.

- All **252** reproduced frame indices and inlier counts match the external JSON. The largest saved plane-field difference is **6.93×10⁻¹⁴**.
- The frozen gate's **78 flagged /42 no-fit** counts reconcile.
- The **574 original D1** low-supported/not-high cells partition exactly into **194 only-inconsistent, 65 with consistent evidence, 315 without near axial-band hits, and 0 no-fit-only/mixed-no-fit-without-good** cells. Groups are disjoint and exhaustive in this actual output.
- Saved reference-column positives are **4 /7 /45 /0**. Covered counts are **194 /65 /314 /0**: the only uncovered cell belongs to the 315-cell group. This resolves the earlier coverage question for these particular arrays; it does not turn vertex-column negatives into continuous physical-clearance proof.
- All **18 non-depth frozen source/runtime files** were rehashed. The **294 depth-manifest entries** match the frozen depth pins, but depth files were deliberately not reread in this independent check.
- The replay reports **zero zero-depth samples**, so the source's missing positive-depth predicate did not contaminate this specific replay. Its reported axial-versus-Euclidean threshold disagreements are **970,921 at 2 m** and **474,687 at 4 m**. Those two membership counts and the zero-depth count require original samples to independently recompute; they were not marked independently recounted from the saved gate arrays.

**Interpretation remains unchanged:** these are original D1 classifications, not the active split0.7 navigation mask. “No near axial-band hits” is not demonstrated far-only native-occupancy provenance. No evidence was removed or made free. The replay reproduces arithmetic, not the README's stronger causal claim that tracking drift is uniquely established, nor the omitted ICP/control claims.

Evidence: `REPRODUCTION_RECOUNT.json`; source and full earlier review: `INDEPENDENT_REVIEW.md`. Original upstream and frozen reproduction files remain unchanged.
