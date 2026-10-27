# Independent review and corrections

The first execution passed56 analytic fixtures but independent source review identified gaps not covered by that count:

1. Beyond/outside selected-segment returns hid nearby competing segment IDs. Conflicts are now collected first without changing the selected segment or returning movement advice.
2. Initial float fixture used exactly representable0.25. Added nonrepresentable large-coordinate and0.1 radius-boundary cases, with explicit mixed float-result/double-policy semantics and no invented epsilon.
3. Float quantization could enlarge a supplied submillimetre segment. Added a supplied-double length check before the unchanged upstream float-domain check.
4. Tiny camera vector squares could underflow. Normalize the finite vector with double `math.hypot` before float conversion; zero/near-vertical remains unavailable.
5. Initial timeout handling killed only the compiler driver and orphaned evidence filenames could be reused. The runner now owns a new process group, signals that group on timeout/interruption, reserves freeze/receipt exclusively and skips any orphaned attempt/freezes/logs. Before executing it records `terminal:false`; a crash leaves explicit unfinished evidence instead of making a false pass or silently reusing the ID. CPU caps remain per-process, output-size enforcement is a post-capture check, and no escaped-child/aggregate-resource guarantee is claimed.

ATTEMPT01 and its source-hash freeze/logs remain historical. Current sources differ intentionally; ATTEMPT02 records the revised source hashes and results. No geometry, app, live callback, physical guidance authority, stage84 evaluator, map or vendored source changed. Synthetic fixtures prove arithmetic and policy examples only, not pose accuracy or real navigation.

Independent follow-up review found no remaining blocker for this scoped offline diagnostic. It verified all18 current frozen source hashes, both log hashes and the freeze hash, and confirmed the recorded62-case pass without rerunning the tests. Failure/timeout handling remains source-reviewed rather than experimentally exercised.
