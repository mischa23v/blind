# Package 75 and ingress 83 — verified fresh host results

Both artifacts identify commit `fb879d235f38a3f0121b69b023e8ee14c0ded61c` in `mischa23v/blind`.

| Evidence | Run | Artifact | Bytes | SHA-256 |
|---|---|---|---:|---|
| Package 75 | [40545204675](https://github.com/mischa23v/blind/actions/runs/40545204675) | 12753230836 | 15,857 | `fcf07f9f12a8a37568d2cba8dfd9f56128861b5f057fd495813157be4d3cccd2` |
| Ingress 83 | [40545204872](https://github.com/mischa23v/blind/actions/runs/40545204872) | 12752721727 | 11,621 | `ec37cb1168eb9058840c2471e1c61735a26e0cbb97127b6539a075a809514351` |

Both original ZIP sizes and SHA-256 match expectations; all ZIP members passed CRC verification. All 24 extracted original JSONs parse. Original ZIPs are retained under `archives/`; extract them to inspect the unchanged evidence members. `recovery-receipt.json` records verification.

## Package 75

Independently counted retained result dictionaries: **55 legacy + 32 runtime + 5 failure-commit boundary checks = 92 host checks**, all true. SUMMARY agrees. The old 87 remain, with five additional checks that current lifecycle failures survive revision advances and later events, while late failures after generation/session/ABA resets do not contaminate fresh delivery. Host module/package, imported public client, and fixtures execute successfully. Host run log prints 55 and 32; the five new outcomes are explicitly retained in `RUNTIME_RESULT.json.failureCommitChecks`, not printed in that log summary.

Simulator package/client compile and link only. `iOSSimulatorExecuted=false`, `appProjectBuilt=false`, `ARKitExecuted=false`, `physicalAuthority=false`, `publicExclusionUpdatesImplemented=false`.

## Ingress 83

Actual exit-0 host fixture receipt and RESULT both report **55 stage83 real-runtime synthetic checks passed**, explicitly with **no ARKit execution or privacy-purge proof**. This means host tests against the real package runtime, not device or ARKit runtime testing. Individual check lines are not retained, so 55 is corroborated producer output rather than an independently enumerable result dictionary.

Successful simulator compilation includes actual `ARKitMeshAdapter.swift` and `ARKitIngress.swift` with the snapshot/ingress modules and package linkage. These receipts are compile/link evidence only, not execution.

## Limits

Both runs use native SwiftPM; `defaultSwiftBuildBackendPassed=false`. Do not claim default-backend success. Ingress explicitly reports `appActivation=false`, `simulatorExecution=false`, `deviceExecution=false`, `copyLatencyMeasured=false`, `physicalAuthority=false`. There is no live capture, device-copy latency bound, physical navigation safety, clearance, or privacy-purge proof. Resource accounting is stage-end only, not a live quota or RAM cap.

This recovery verified and inspected evidence; it did not independently rerun tests, install software, or execute new tests. This checkpoint now preserves those original public artifacts.
