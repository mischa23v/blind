# Full-app audit evidence, not a layout repair

The isolated comparison at c683ea3 passed all 15 fixed native cases. The original
full-app audit still has unresolved failures; its surrounding layout/state differs.
This test-only change instruments the same Camera-and-Ask audit rather than changing
production styles or running another broad comparison.

- The default full audit scope and existing disabled-retrace contrast exemption are
  unchanged. Every other finding remains unsuppressed. `continueAfterFailure` stays
  false; a Camera failure can prevent reaching Ask.
- Before auditing each destination, wait at most ten seconds each for its existing
  navigation title and required control, then assert both. There is no sleep,
  retry, scrolling to a passing state, timer change or timeout expansion.
- Keep two named screenshots per reached phase (before and deferred after), runner
  content category and frames/existence/hittability of nine known controls. Do not
  enumerate the full app hierarchy or include model/user data.
- Log the public compact/detailed issue descriptions with bounded lengths alongside
  the original type/optional-element details. Missing native issue elements remain
  unidentified; do not guess which control caused a failure.
- The focused workflow exports only these authored images and bounded evidence
  status. A missing Camera pair or partial Ask pair fails extraction while retaining
  valid available screenshots. A wholly absent Ask phase is explicitly unobserved,
  not a passing audit. The native audit exit status is never normalized to success.

The new readiness assertions expose an absent/wrong destination rather than hiding
it. If XCTest aborts before deferred capture, missing evidence is reported, not
accepted. These are diagnostic source changes; native compilation and the resulting
full-app evidence remain pending until the published workflow executes.

Source validation: five source-contract checks and eleven exporter fixtures pass;
independent source/export/workflow review accepted. No Apple SDK compilation of
this instrumentation has been claimed. Publication preimages verified at commit
`853fe13e9d00880f29b0920b901e02f7007e1d56`: LaunchTests blob
`1ad9fb58f1c943af4a1cdc1604fd5096004eff35`, focused-workflow blob
`a1fd1d2862823054f0e5d150430c251a8509d4ba`.
