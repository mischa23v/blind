# Shared native depth observation policy

Base: `86992184020d877c26295db8fc6ec903eb21a9f9`.

The real ARFrame sampler and recorded replay now use the same Core policy for Float intrinsics and scaling, confidence-two depth admission, the closed 0.15–5 m range, stride-two sampling, and the strict horizontal optical-length threshold above 0.25. Native acquisition retains its pixel-buffer locks, row pointers, and SIMD world transform. The separate point-lookup lane is unchanged. No detector, planner, cadence, body dimensions, or return threshold was tuned.

Mapping, containers, detections, sensor projection, localization, body/phone geometry, collision decisions, routes, return and replay are code-owned. An LLM may interpret a request or explain structured results; it cannot author replacement world geometry, trajectories or clearance evidence.

## Recorded result, not journey completion

A verified official ARKitScenes sequence supplies 596 chronological frames over 59.492 seconds. Recorded camera odometry is an input, not localization estimated by this application. The proper `(x, z, -y)` basis is an inferred source convention, not independently measured gravity. No future map, mesh, annotation, teleported pose or fabricated stationary capture enters the driver.

The matched transport produced 536 observations and 60 orientation-unavailable captures. The actual Foundation runtime admitted 315 frames in the uninterrupted variants, or 314 in the separate restart variant. It retained up to 4,096 observed surface cells; these are not certified free-space cells. Calibration never completed, and no return candidate or completed navigation journey was produced. The actual calibration diagnostics reached only eight of the required fifteen consecutive samples: 202 near-count failures, 267 inlier/bin failures, 67 accumulating frames, and 60 unavailable captures. There were 123 movement resets, 18 discarding a positive run. These results establish an unmet calibration prerequisite in this sequence, not a justified threshold change or physical validation.

Two explicitly hypothetical body/mount variants emitted warnings on 471 and 503 captures. The assumed 1.2 m mount is not measured wearer truth, and floor intersections can inflate this warning burden. Alert fraction is not accuracy. No-profile planning remains unavailable. The separate restart variant has no body profile; profile-bearing restart and native mount-slip retirement are not modeled. No unsupported combined variant is claimed.

All four shared-policy traces and summaries match the previous frozen Float-matched cut exactly. Earlier sparse stride-eight results are preserved as history-adapter experiments, not native calibration failures. Four runs of one sequence are not four independent journeys and do not satisfy the 400-journey target.

## Verification and limits

- Four portable Core test methods pass, including original-expression Float/depth/heading boundary comparisons.
- Three Node source contracts pass, including missing/replaced-call negative mutations and nonnegative cadence/retirement ordering checks.
- Eight authored transport assertions pass; these are separate from recorded evidence.
- Native Swift syntax parsing passes. Full Apple SDK build and execution remain pending.
- An Apple-only test bounds portable Float column-sum versus native SIMD multiply error at `2e-6 * max(1, abs(native component))` for its authored cases. It has not run here. Portable arithmetic is not claimed bit-identical to native SIMD/FMA on every platform.

No raw RGB, depth, trajectory or per-frame coordinate derivative is published with this receipt. Actual-device latency/thermals, wearer/body ground truth, connected registered-route acceptance and physical blind-participant acceptance remain open.
