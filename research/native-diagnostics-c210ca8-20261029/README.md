# Exact c210ca8 native Apple terminal evidence

Run [40948350087](https://github.com/mischa23v/blind/actions/runs/40948350087), attempt 1, completed **failure** at 2026-10-29T20:55:35Z. App commit: `c210ca822ec4fdc339f808af58bc5b057fd98788`.

- Hosted: 297 cases, 283 passed, 12 failed, 2 skipped. Failures retained by identity: 4 classification ingress; 5 model/conversation; 3 saved-route contact cases.
- Focused optional-policy tests: exact 14/14 passed, source verified. Seated flag-only tests: exact 10/10 passed, source verified. Neither supplies physical authority or activates callers.
- Default simulator build, package steps, classified mesh bench and diagnostics compile succeeded.
- UI: 18 executed, 3 skipped; 2 assertions in the one Camera/Ask accessibility case failed (Dynamic Type unsupported/partially unsupported). Practice start/stop case passed; cancellation elapsed upper bound 5.853190291667033 seconds against 90 seconds.
- Exact UI identity diagnostic failed: both queried identities unavailable. Practice runtime evidence unavailable: selected simulator app container unavailable. These diagnostics do not themselves determine UI outcome.

## Newly observed diagnostics

`diagnostic-markers.json` retains actual bounded CLASSIFICATION_WORKER_CPU, CLASSIFICATION_DIAGNOSTIC_LOCK and ASK_LAYOUT_TRACE lines from the exact completed job; no raw full job log, environment dump, model answers or photos are included.

25 worker records and 25 lock records. Maximum ingress diagnostic-lock wait: 20 microseconds; runtime75 maximum: 226 microseconds. A long ingress sample took 36,041 ms wall versus 64,935 microseconds CPU; its build took 34,775 ms wall versus 64,324 microseconds CPU. Logger lock waits in these records do not account for those stalls. This is not proof of scheduler cause, nor proof all waits were covered. Four ingress tests each exceeded the 10-second callback wait and then caught unavailable.

Ask layout trace: zero records, zero rejected prefixes, zero dropped valid records, scan budget not reached, status unavailable, native format unverified. Do not infer absence of layout issues or successful trace instrumentation.

The current job explicitly logged UnifiedAssetFramework Code 5000: no underlying assets for com.apple.MobileAsset.UAF.FM.Overrides. A typed generationFailed was also observed. This confirms a current asset-catalog error, not an exclusive causal attribution for all five model test failures.

Three route cases retain original contact failures, not relabeled safe stops: original baseline 1, separately preregistered width 2, journey 2 reported invalid/contacting candidates.

Passing prior failure identities in this one run is not proof of a stable fix. No reruns, installs, fixes, simulator edits, or additional spend were initiated. The exact run is terminal; monitoring ended with evidence capture.
