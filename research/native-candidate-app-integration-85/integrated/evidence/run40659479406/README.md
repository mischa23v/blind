# Hotfix source run40659479406 — tests execute, acceptance remains blocked

Exact source `2aded1605b11f8da273e01fe6677a0b3aafc8e73`. Both builds pass and the undefined-entered fixture compilation blocker is repaired. Core1,422/1skip/0fail; Memory58/0fail. Individual new package-case results are not separately exported.

Hosted **181 unique cases:171pass,8fail,2skip**. All ten diagnostic/durable recorder fixtures pass; RecordedRouteStore total21cases/19pass/2fail. Existing ActiveTrip restart snapshot and ClearRetires queued snapshot/clear tests time out. All17 ConnectedJourney and all3 connected bench cases pass.

Scene fence **functionalCompletion=true**, but the unchanged **1.2-second latency assertion fails at3.090s**. Goal phase queue admission0.242s, worker wall1.600s, main handoff0.751s; body worker wall0.454s; fresh worker wall0.00245s. These are instrumented elapsed wall times, not CPU utilization, inferred root cause, device latency or safety claims.

Five model-text test cases fail because replies did not finish (app-owned status), not because this receipt observed a hallucinated response. These failures are preserved, not converted to skips.

UI **18cases:14pass,1fail,3skip**. Practice explicit End passes6.318s(<90), fullcase29.902s. Camera audit reaches after; Ask contrast still fails despite the scoped prompt candidate. Callback cannot identify an element. DescribeFocusAndStopControl is absent from failures but exact per-case pass is not independently exported. Overall accessibility is not accepted.

Both bounded artifacts match GitHub hashes and pass CRC. Unit181identifiers/counts/source verified. Only two allowlisted UI JSONs are published; screenshots/archives stay outside this folder. No rerun/new workflow/runtime activation. Later overlay source is separate.
