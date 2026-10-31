# One-shot IO phase result

Run https://github.com/mischa23v/blind/actions/runs/40542575045 used harness a2423071aa8804e31b881585d28dca04dc319d1b and explicitly instrumented disposable source e9e18d15fe1fdac1ff1487b3c2a8a2e731607427.

Native build and exactly one original focused test passed. Required phase markers were present (52). Overall workflow failed provenance because Xcode generated an untracked ios/BlindAssist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved. No unexpected app/test source edits were recorded. This identifies THIS run's delta only; earlier unknown dirty-source reports remain unresolved. Generated lockfile contents were not captured and are not declared verified.

Observed import: submission to preparation approximately4.624s, preparation1.310s, previous read0.000101s, write0.000678s, main-publication enqueue to entry0.000353s, wait begin to completion6.108s. Test duration6.151s. These instrumented timings identify where this attempt spent time, not the cause of earlier10s failures and not a latency guarantee. No timeout/QoS change or retry was used. Synchronous diagnostics can perturb timings.

Preserved deterministic ZIP:370238bytes, SHA-256331472227c1e29a48bf034cc8639505058c54c71261b22f7a7e8a3098acf0c8a. It contains the ten original bounded artifact files plus interpretation.json. Original public artifact12751452073 was360240bytes, SHA-2567a0ab2f092593f7a5ea4c6964dd019a87c97b823fdde4d733ce244db2e061895. No binaries, xcresult, private geometry or raw job logs are included. No physical-navigation acceptance follows.
