# Actual Stage C003: fixed-fixture route result

**Completed successfully—not a plan. Eight candidate requests completed without modeled body or safety-margin contacts; 17 remained refused/unsuccessful. No app activation or physical navigation authority.**

[Actual Apple run 40895152519](https://github.com/mischa23v/blind/actions/runs/40895152519), source `9a3aeee70c235c33954760388770809478ca9f79`, job 123522115667: success; launcher exit 0. The exact public log envelope, actual artifact envelope and independent terminal review are preserved alongside this report.

| Declared gate | Actual result |
|---|---:|
| Native commands completed |31|
| Read-only observer groups reported passed |15|
| Original controls reproduced |50: 25 legacy + 25 strict|
| Candidate requests / declared per-request criteria met |25 / 25|
| Existing complete no-contact corridors retained |6|
| Previously contacting corners now complete without modeled contacts |2|
| Required typed endpoint refusals retained |3|
| Other original failures preserved |14|

All candidate initial-contact classifications were unchanged and all full layouts validated. All eight completed candidates have no modeled body/margin contact, including the checked initial state. **25 criteria met does not mean 25 successful paths:** retaining the 17 failures/refusals was required. No failed/refused request is counted as successful movement.

## Distances actually represented

Lengths below come from the unchanged route/contact evaluation. “With connectors” includes supplied-endpoint connector segments and is not distance a person walked.

| Fixture label / declared profile | Requests | Detour 3D length | With connectors 3D |
|---|---:|---:|---:|
| bedroom-around-bed / nominal and width 28 addendum |2|1.700000m each|1.750000m each|
| hall-long / nominal and width 28 addendum |2|5.800001m each|**5.850000m each**|
| hall-corner / nominal |1|1.471361m|1.521361m|
| hall-corner / width 28 addendum |1|1.358268m|1.408268m|
| open-door approach and supported-model return / journey-width 28 |2|0.650692m each|0.700692m each|

These are **fixture labels**, not semantic achievements: `bedroom-around-bed` does not establish a full loop around a bed; no full bed/table loop was tested. Several requests duplicate geometry/endpoints under different declared body profiles; eight requests are not eight independent rooms or routes. The width 28 profile retains its predeclared assumed depth 20 / height 120; it is not a newly measured user body or a replacement for the nominal baseline. No 100 movement trials, human walking distance or live-phone session is represented.

## What the correction changed

The opt-in production C++ helper adds a bounded exact integer seed-radius **exclusion after stock Recast erosion**, in a restricted flat single-layer domain. It never promotes a cell. The original seed definition and strict-less-than/equality policy, body dimensions and safety margins, radius/grid/slope/climb settings, input geometry, requests, endpoint rules and independent collision oracle remain unchanged. Unsupported topology or insufficient work budget refuses instead of silently using a stock route.

The six retained completed paths match the legacy/strict canonical Float32 path digests. The two fixed corners have different digests and no modeled contact under the same oracle. This is evidence of the tested discrete-mask correction—not proof of continuous physical clearance, complete footprint support, a general 3D distance transform, center-seeking routes or safe operation in an unseen room. The original missing-floor/short-aisle refusals are not repaired by this result.

## Terminal evidence and limits

- Source manifest:`ec2e36696ccd214f5c56b9dc3764607679f95410d56b597f1358c7925f8dae34`.
- Launcher manifest:`c98e2907ff7683ef6a89cf3c8b5d7034ca66638bd9713e33bb98f18399beea8d`.
- Exact log envelope SHA256:`cfae06b474540a7e0bed91c09ced9f6ad47add1eda4e49da03354aae3d5da4cc`.
- Exact actual artifact envelope SHA256:`542601d651b822cea2ddc3a104e85e72173107de27a6db9231f8d48a2172a8c5`.
- Independent terminal review SHA256:`7683e17554407277b897f1c026c9e3138d6ee16e19ffc53e11c410541e2a56e8`.

The two envelope files parse identically; their exact bytes differ in JSON member ordering and terminal newline formatting. Source/tool pins passed before and after. Terminal resource observation completed: 26.151641 aggregate CPU seconds, 30.852132 wall seconds, 454,361,088bytes observed peak RSS, 71,971,338bytes peak owned output. No recorded breach of the unchanged 120 CPU-second / 300 wall-second / 2 GiB observed-RSS / 128 MiB output limits. These are sampled guard observations at the documented terminal boundary, not a hard kernel sandbox or complete workflow cost.

The runner checked raw observer/layout/path data privately. The independent terminal review validates the coordinate-free exported flags, counts, body/input identities and digests; it does not independently regenerate withheld path arrays. The 15 observer labels are launcher-validated reports. No new raw geometry, path/trajectory coordinates, masks, binaries, native logs or admission tokens are distributed here. Digests identify paths but do not reconstruct them.

## Earlier attempts remain failed

- **001**, run 40880717881: launcher exit 1, 0 native commands completed; no route/fixture success. Source review later identified an incompatible command-label grammar. The private first exception was not recovered, so that source defect is not presented as a recovered runtime exception.
- **002**, run 40887430580: launcher exit 1, 29 native commands completed, 15 observer groups reported; route matrix never executed. Exported refusal occurred at the Swift-probe compile site with return −9; final resource observations/postchecks were unavailable. Its specific private root cause and cap compliance remain unproven.
- **003** is a separately reviewed/admitted successful attempt, not a retroactive success for 001/002. Candidate engine, oracle, controls, body/margins and acceptance criteria were not relaxed.

This preserves the actual standalone Stage C production-C++/oracle result. It does **not** claim Stage B app Swift/C ABI acceptance, enable the optional policy in the app, activate a live session, certify toy/obstacle detection or authorize physical guidance.
