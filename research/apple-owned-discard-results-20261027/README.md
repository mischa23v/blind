# Terminal discard — verified fresh host results

Source commit: `eb0fc673a72d1c9003cbceb5ef0f68c60e4f5563`, repository `mischa23v/blind`.

| Evidence | Run | Artifact | ZIP bytes | SHA-256 |
|---|---|---|---:|---|
| Package 75 | [40560344601](https://github.com/mischa23v/blind/actions/runs/40560344601) | 12759301586 | 16,263 | `a2b80c8b09c4431fc9af9ba483b9a01bf8efc0991ce2abfb645fc4adb731548f` |
| Ingress 83 | [40560344668](https://github.com/mischa23v/blind/actions/runs/40560344668) | 12757484819 | 11,634 | `3e9de0b28bd7b0f4a1d09a011901b9072206d9bab6667321486966fb4b32fc20` |

Exact expected sizes and SHA-256 hashes verified. Every ZIP member passed CRC verification; all original JSONs parse. ZIPs, unchanged extracted evidence under `sources/<artifact-id>/`, and recovery receipt are retained locally.

## Counts and execution evidence

**Package: 111 host checks**, independently counted in retained result dictionaries: 55 legacy + 32 runtime + 5 failure-commit + 19 discard checks. All values are true and SUMMARY agrees. Host fixture process and public imported client exited 0. The fixture log's older summary prints only 55 and 32; the additional 5 and 19 are explicit JSON outcomes, not invented from that log.

The 19 discard outcomes include acknowledgement waiting for admitted native jobs, actual retained Replay release before acknowledgement, admitted-query completion, pending-caller acknowledgement, immediate fencing, rejection of new offers, reset interleavings, and terminal-owner non-revival. Public client output explicitly says: `PUBLIC DISCARD API PASS: acknowledged terminal owner release; not system erasure`.

**Ingress: 83 real-runtime synthetic host checks**, reported consistently by RESULT and the actual exit-0 host-run log. No per-check records are retained here, so this is corroborated producer output, not an independently enumerable result dictionary. Its output explicitly disclaims ARKit execution and privacy-purge proof.

## Precise ownership and purge limits

These are fixture-level evidence for owned Swift Replay release and runtime/ingress work-slot drain/terminal fencing. They are **not independent proof of native C allocation destruction, allocator zeroization, system-wide memory erasure, ARKit-owned buffer purge, complete privacy purge, or release of every external copy**. A retained-owner witness and acknowledgement do not establish those broader properties.

Successful simulator compilation includes actual `ARKitMeshAdapter.swift` and `ARKitIngress.swift`; it remains compile/link-only. No live capture, app activation, simulator/device execution, device-copy latency, physical navigation safety or clearance is established. Ingress explicitly reports appActivation/simulatorExecution/deviceExecution/copyLatencyMeasured/physicalAuthority=false; package reports ARKitExecuted/iOSSimulatorExecuted/appProjectBuilt/physicalAuthority=false. Public exclusion updates remain unimplemented. Both use native SwiftPM with defaultSwiftBuildBackendPassed=false.

Recovery inspected producer evidence and verified bytes; it did not rerun tests, install software, or write externally.
