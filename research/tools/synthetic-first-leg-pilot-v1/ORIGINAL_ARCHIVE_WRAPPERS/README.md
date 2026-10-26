# Five short synthetic first-leg pilots and Apple bridge evidence

This packet supplements the earlier [three continuous assisted laps](../verified-continuous-three-laps-v1/README.md). The earlier61.792m nominal run remains a static assisted result, not a sensor-robustness test.

## Synthetic pilot outcomes

All five predeclared short first-leg episodes reached the original goal region. These are **five development episodes on the same short route**, not five complete laps, independent rooms, calibrated sensor trials or a100episode suite.

| Condition | Ticks | Horizontal travel |
|---|---:|---:|
| Nominal |172|2.775841m|
|3-tick command delay|197|2.839975m|
|2-tick pose delay with±2-tick temporal jitter|370|2.800000m|
|1.15× translation|154|2.783000m|
|Capture withholding at ticks60–89|202|2.775841m|

**Usability issue:** temporal jitter produced193 no-new-pose stop ticks and191 coalesced packets, taking370ticks versus172 nominal. Arrival is not smooth or pleasant guidance. The frozen “no new packet means stop” policy caused these stops; no different retention policy was substituted after scoring. Command delay produced three moving ticks after issued stop before the FIFO drained.

Zero committed contacts alone is not proof: evaluator-world vetoes can prevent contact and would count as failed/assisted stops, not phone obstacle detection. Here no predicted body/underbody contact or support veto occurred. Invalid starts/no-path conditions must remain in future denominators, not be silently excluded.

The proposed20 distinct ordered anchor-pair×5condition matrix remains unexecuted. Independent review is recorded in the included stage73 final receipts. No earlier failed checkpoint is removed or reclassified.
Stage72 preserves the corrected protocol, queue probes and superseded unrun replicate proposal. Stage73 uses unchanged collision/support geometry and preserves every actual/rejected step, queue event, cap and terminal outcome. Synthetic delivered poses do not model raw RGB/LiDAR/IMU errors, spatial drift, dynamic obstacles or human behavior.

## Apple SDK result (separate plaintext evidence)

`research/apple-sdk-result-71/` records verified run40416322676 at sourcecaebdacedd4e19a74fa5899adf016c912caf402d. macOS ARM64 native/Swift replay passes all55 unchanged checks and636 exclusion spans. Fifteen full route comparisons match exactly. iOS Simulator ARM64 native library and Swift executable compiled and linked; **the simulator executable was not launched**. No app project, live ARKit capture or physical device was tested. Explicit `-ffp-contract=off` was the sole behavioral build correction after preserved earlier route-parity failures; no geometry/assertion/coordinate tolerance was relaxed.

Apple evidence is published outside existing CI-trigger paths. It remains candidate-only, with physical authorityfalse and unknown actual-world coverage. Hosted CI timing is not a phone benchmark.

## Limits and provenance

One static recorded room,45×30×160cm body,zero margin,manually assisted tabletop source ROI and evaluator/reference floor support remain. Floor-contact events are unmeasured. Unknown source confidence, finite support probes and sub2mm ambiguity remain. Neither these pilots nor Apple compile/link establishes100journey completion, live navigation or human safety.

Public source: Xuqian Ren et al.,MuSHRoom, https://zenodo.org/records/10230733 and https://zenodo.org/records/10222321,CC BY4.0 https://creativecommons.org/licenses/by/4.0/. Derived geometry, annotations and simulated traces are documented per checkpoint; Recast license included. No private participant data, scans or user attachments.
