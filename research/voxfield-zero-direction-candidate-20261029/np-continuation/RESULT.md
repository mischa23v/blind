# Unchanged full NP suite against isolated D1 core

**27 named checks passed; suite exited0. Receipt caveats below are retained.** Same original `build-gate/np_fixtures.cpp`, no assertion, N1 or mapper change in this continuation. Only linked core changes from original to the separately verified D1 exact-zero-guard build. Original baseline's24passes-then-grazingfailure remains recorded.

The prior grazing check now passes; previously unreached serialization and malformed-normal checks actually ran and passed. Serialization result confirms **gradient is lost in native save/load**, not that persistence was repaired. Mismatched/nonfinite normal checks are adapter preconditions before native calls, not native input-safety evidence. Earlier synthetic B/C0/C1 and N1 plane/hole checks also passed; coverage limitations from FIXTURE_GAP_REVIEW.md remain.

## Resources and reproducibility
Single worker/CPU,8.875419s wall,8.74 conservative sampledCPU seconds,534,171,648B peak sampled summedRSS.30CPU/45wall/2GiB/32MiB caps; no sampled cap hit. Distinct D1 core ELF closure verified before suite.242 continuation-frozen inputs unchanged afterward. No install/network/spend, recorded input, N1 changes or retries.

**Receipt caveats:** The fixture includes original `n1_adapter.h`, but this header was inadvertently omitted from the continuation freeze. Its post-run SHA256 exactly matches the prior original gate's frozen SHA (`1a138c6fb47c692a788b1bd9cd7f768242e3f0e716894a4b18ec3cc2b69a368a`); this is not a contemporaneous continuation precheck. The suite's355,105B serialization file was written in inherited workspace cwd, outside the continuation tree sampled by the disk guard. It was preserved afterward at `run/synthetic_gradient_loss.voxblox`, hash recorded. Combined disk remains below32MiB, but this is a monitoring-scope omission, not a fully enclosed disk receipt. No rerun concealed either issue.

See RESULT.json,RECEIPT_CAVEATS.json,run/fixtures.log,run/ELF.json,RESOURCE.json,POST_RUN_INTEGRITY.json and EXECUTION_FREEZE.json. No native invalid-input/D2 repair, broader hazard safety, all-upstream-pass or real-scene accuracy claim follows. Shared RayCaster fix affects projective and NP: historical unpatched stock Voxblox arm is not a matched corrected control; future engine/normal claims must separate this confound.
