# Rapier analytic comparator: failed, partial first run

The first bounded run at source commit `3be40379c861e8a580643f2cdbec69a6164b5a9a` initialized the official Rapier JS 0.21.0 package successfully under Node v24.22.1. It stopped on an unchanged geometric assertion. It was not a permission, initialization or aggregate-resource failure.

The saved 53 wrapper records contain 73 nested rows and 71 controller calls. The 52 preceding wrapper checks completed. The 53rd wrapper failed on `horizontal_margin / down_step_1cm / raw_trimesh`, not on the plain flat-floor fixture. The generic assertion text was `flat/open motion differs from requested translation`. All 18 body-profile fixtures completed both mesh-flag arms; the margin profile completed its first eight fixtures in both arms before the down-step failure. This is not an accuracy percentage or a room-navigation result.

The failed query requested 25 mm forward. Rapier proposed 19.6602 mm forward and 0.0953 mm upward, a 5.3398 mm forward shortfall. Its contact normal was approximately (-0.302279, 0.953219, 0), 17.5945 degrees from vertical, near the down-step lip. The frozen climb threshold is 15 degrees. The nominal body version of this down-step passed both flags; the margin/two-sided version was not reached.

The exact released controller source explains how that returned normal produces the result: `compute_hit_info` marks it as a wall, `handle_slopes` removes the remaining induced climb without upward intent, then adds the 0.0001 m normal nudge. Time-of-impact translation plus that nudge reproduces the saved proposal to Float32 rounding. This identifies the response mechanism, not the sole reason the cast returned that normal. Offset geometry, edge contact, numeric behavior and fixture construction have not yet been isolated. No threshold, body, margin, floor label or tolerance was changed.

Still unrun: 19 wrapper records / 35 nested rows / 33 controller calls, including the alternate margin down-step arm, margin support-gap, overlap, ceiling, turn, diagonal-wall and all margin slope cases. All raw records including the failing fixture are retained. No real-room query, applied movement, support certificate, arrival or physical-safety result exists.

The supervisor reports 1.603479 CPU seconds, 1.623581 wall seconds, 230,473,728 bytes peak observed aggregate RSS and a retired child process group. All 92 input hashes were unchanged. Aggregate and worker status remain failed. Resource metrics and logs are preserved verbatim under `GUARD_RUN/` and `controls/`.

Recommended next diagnostic: retain every original assertion and numeric setting, collect per-fixture assertion failures while continuing independent fixtures, and finish with a failed aggregate if any assertion fails. This addresses fail-fast loss of comparative evidence, not the collision result itself. No rerun or source correction is represented as completed here.

`RESULT_REVIEW.json` records the exact failed row, source-derived calculation and complete unrun inventory. The original frozen source, package provenance and licensing are in `../rapier-analytic-comparator-source-20261030/`.
