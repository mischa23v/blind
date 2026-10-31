# Released Rapier comparator: complete analytic run, two retained failures

Source commit: `2bc9cfbfea94423576d0c2cad81d6e67be164e31`. The fresh attempt002 ran all 18 authored fixtures in two mesh-flag arms and two envelopes: 72 wrapper checks, 108 nested rows, 104 controller calls and four explicitly unsupported turns. It retained two failed assertions and returned nonzero. No expectations, tolerances, geometry or engine settings were relaxed.

Both failures are the same margin-envelope 1 cm down-step, with either raw trimesh or two-sided internal-edge flags. Each requested 25 mm forward and proposed 19.6602 mm forward plus 0.0953 mm upward. The returned normal is 17.5945 degrees from vertical, exceeding the frozen 15-degree climb limit. Released controller source explains the remaining-motion rejection and normal nudge; why that lip cast produced the normal is not yet isolated. The body-envelope down-step passes its original expectation. This is a retained conservative edge-response failure, not evidence that all room geometry is correct or that the step is safe.

All 54 paired probe comparisons have identical movement and grounded values between the two flag arms. This fixture set therefore shows no movement/grounding improvement from internal-edge flags. Exact duplicate merging is still verified separately by imported vertex counts. The first 73 probe rows reproduce attempt001 exactly, including its failure; collect-all changed reporting/completeness, not engine outcomes.

The other 70 wrapper checks satisfy their original authored expectations. Those include plain flat floor, explicit walls from both sides/reversed winding, 1 cm riser and 10 cm step contact, nominal-versus-margin wall distinction, zero-input overlap proposals, ceiling contact, yaw convention, exact duplicate handling, and slope behavior around 15 degrees. The four turn wrappers only verify unsupported-turn reporting. This is not a navigation accuracy percentage.

Two important limits were directly demonstrated: the controller proposes forward movement over the authored unsupported gap while grounded is false, and explicit upward input can climb a slope that horizontal input rejects. Neither proposed movement nor grounded is therefore a substitute for independent support, stairs/drop and obstacle checks. Corrections are logged but never applied.

The supervisor records 1.624457 CPU seconds, 1.631546 wall seconds and 235,008,000 bytes peak observed aggregate RSS. All 97 input hashes remain unchanged and the child process group retired. Both worker and aggregate retain failed status. No room query, replay, arrival, device trial or physical clearance was established.

## Next useful comparison

Proceed to a separately frozen diagnostic sample of the original Coffee/conference poses, without tuning these fixtures first. Reuse immutable full source meshes, frame transforms, dimensions and the preselected 49 schedule rows. Bind every selected pose/heading/translation to its saved source and retain the original VTK body/margin/contact evidence, including unknown support and unsupported rotations. Run both mesh flags and both envelopes at identical poses; compare proposed movement and contact responses, not a fabricated collision-free journey. Do not apply depenetration or turn it into a clearance override. Retain the down-step failure as a known limitation of both arms.

Real-room execution is still blocked on exact materialized mesh/probe hashes, reviewed source-frame mapping, a dedicated guarded launcher, and explicit treatment of missing support/hazard evidence. Those are preparation steps, not a need to obtain an artificial perfect analytic score. This packet itself does not admit a real-room run.

## Reproduction and compact evidence

`assertion-results.jsonl` contains all 72 original checks. `SUMMARY.json` and `SUPERVISOR_RESULT.json` are verbatim. `RESULT_REVIEW.json` contains both exact failing probe rows, independent stdlib rechecks of every geometric expectation, complete raw-file SHA-256/size inventory and paired comparisons. Full raw wrapper/probe logs remain in the attempt directory; they are omitted here to avoid publishing a duplicate 462 KB payload. `review_result.py` reproduces this review from retained logs without importing or executing Rapier. The published source and immutable package hashes reproduce the engine experiment separately.
