# D1 exact-zero ray guard: bounded synthetic result

**PASS within admitted scope; no recorded-data or navigation accuracy claim.** Independent reviewer admitted execution freeze `11e30170172c1bb4e5f80b7967dff97db7a2787a3190715cafa1e5546934e23c`; final result review requested separately.

## Measured result
- New isolated core built from all 26 retained official source files; only six exact-zero ternaries plus `<limits>` differ. Official revision `78ee6403720e0aed87f4720c04c813bb38a3b260`, BSD-3-Clause. Original source and DSO remain unchanged.
- Candidate **28/28 strict exact-list traces matched**, and **4/4 separately observational near-epsilon cases matched**. The latter were not silently promoted into strict admission tests.
- Original control retains **17/32 geometric mismatches**, including original axis:31 copies of cell(0,0,0). Candidate visits31 unique cells(0,0,z),z0–30. This original failure is not deleted or reclassified as a pass.
- Original axis NP probe(0,0,24): baseline unallocated off/on. Candidate C0 allocated weight1, distance0.02000004053m; perpendicular-normal C1 allocated but weight0 (unobserved, not free).
- Separate nonzero-XYZ oblique control retains identical indices and NP off/on values:0.9175153375/0 weight and0.02998125553m C0 distance. Original and candidate clients run in separate processes, each with verified distinct core ELF closure (`run/ELF.json`).
- Adapter rejection checks passed without making native-invalid calls. Physical zero/nonfinite/invalid parameters and empty clipped clearing were rejected by adapter only.

## Resource and integrity receipt
One worker/CPU;77.179718s wall,76.97 conservative sampled CPU seconds;664,125,440B peak sampled summed treeRSS; approximately5.95MB candidate directory. Caps120CPU/150wall/2GiB/64MiB. No cap, retry, network, dependency install, recorded input or spend. All479 frozen inputs rehashed unchanged after run. See `RESOURCE.json`, `POST_RUN_INTEGRITY.json`, `run/{configure,build,original,candidate}.{json,log}`. Exact command arguments and ELF hashes retained.

## Limits and interpretation
The narrow hypothesis is supported: marking exactly inactive axes as positive infinity avoids zero-component traversal stalls while tested nonzero arithmetic and boundary/tie semantics remain unchanged. This is not a measured real-scene mapping improvement, a stock Voxblox binary result, a full upstream suite pass, or phone/safety certification.

D2 invalid-input/lifecycle handling was not implemented. Native invalid/zero-physical-input safety remains unresolved; internal post-terminal advance remains unchanged. Private internal DDA float state was not observed. Finite direct same-cell and zero-length semantics were tested; physical zero-length was adapter-rejected before native normalization. Nonempty clearing and carving-disabled paths were not tested. Existing floor+epsilon ownership, staircase ties and endpoint-inclusive count remain unmodified. Four near-epsilon observations cannot establish arbitrary boundary correctness.

The earlier original gate remains incomplete:9/10 upstream targets passed, layer_utils resource-blocked,13 legacy fixtures passed,1303 N1 assertions passed with leakchecking unavailable,24 NP checks passed then original grazing fixture failed. This new diagnostic does not overwrite that ledger or execute unreached NP/hazard cases. N1 area threshold and unavailable-normal preservation limitations remain. Low-object/drop/overhang support, sign/view stability, unknown-space and swept-route safety still need independently frozen tests before any recorded-scene admission.

No further run is authorized by this result. Recommended next decision: independently review source/trace receipts, then separately scope any continuation of previously unreached NP/hazard checks; do not jump directly to a recorded comparison.
