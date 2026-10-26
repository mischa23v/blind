# Independent source and terminal review

A separate reviewer read the Swift harness and driver without compiling or rerunning the data. The numerical scope was accepted: original Float32 bit patterns and U8 confidence, actual shared production admission/projection, fixed original IDs, integer pixel-centre conventions, per-frame K, disjoint rejection buckets, tile reconciliation, zero-admission null envelope, and no world/body/tracking/navigation inputs.

Two driver issues were identified before execution and repaired: acquisition field-audit/manifests now have four fixed independently supplied SHA256 anchors before parsing, rather than only self-consistent dynamic hashes; the final output/reserve check now includes the receipt bytes. Final reviewed source hashes:

- NativeCameraAudit.swift: 0346a5dc37acf4c8bc21e7042eae925ac3b7d534c13ea66575862ee82ae890ac
- run_native_audit.py: 1dfce365da423506b0980d19f3266029129e44240817a14cdec1bcd76c6296cb
- PROTOCOL.md: 87e53ea5bfb8ed496dfe45fdad7d7b8e80fa5d25a32ed6bf7c4225e6bf0d8e5a

After execution the reviewer rehashed all 51 source/data pins and 10 listed artifacts. The exact binary and both dynamic-library paths match. All 16 original frame IDs, timestamps/intrinsics, disjoint rejection totals and 48-tile sums reconcile. Every frame's admission/rejection agrees with the separately implemented saved-array predicate check. No projection/redecode/rerun was performed by the reviewer.

EM1-1093 admits 86,236/98,304 pixels; EM1-0387 admits 34,240/98,304. Five analytic projection probes have zero reported error and nine scalar probes pass per invocation. Maximum camera roundtrip residual is 2.842170943040401e-14 pixel and zero axial depth residual. Native run outputs including receipt are exactly 17,874,112 bytes; all declared resource caps were respected. Receipt SHA256: 19dbfe45a89e7494736fca472f2f45f4239387b5a7affe58b061bf325e5236f2.

The clips depict unmatched scenes/tasks and distances. This is recorded-ray policy admission and numerical projection evidence only, not a device-generation accuracy comparison, physical coverage, low-object detection, clearance, or navigation proof.
