# N2 numerical normal availability: bounded synthetic result

**Provider and narrow coarse synthetic contracts passed. No measured recorded-scene accuracy gain or small-object safety claim.** Independent final source admission freeze `4c5196599531d191d6a041af584270a54bd0f0e040cde287b048051096747efe`; all255pins unchanged after run. Original N1 and D1 core unchanged. Source reviewed before thresholds/run; original unexecuted print-only proposal remains in `pre-review/`.

## Useful findings
- **1382 provider assertions passed** with ASan bounds + UBSan fatal behavior. Leakchecking unavailable because prior environment ptrace incompatibility; explicitly disabled, not claimed tested.
- At actualfx≈810.825 and0.3m, original N1 numerical valid normals0 versus N2 159,201, while **all160,000 identical points/order retained**. Provider4×3 controls give6valid+6border normals at0.3/1/3m. N1area-cutoff excludes the six0.3m interiors; it remains preserved as baseline.
- This availability change is **not a demonstrated geometry gain**: the paired0.3m N1→C1 and N2→C1 native sample grids both report25/25 observed,25/25 within2cm TSDF bin and25/25 within4cm of a mesh vertex. Different gradient availability alone is not proof of better hazard geometry.
- **18 predeclared coarse retention gates passed**:3ranges of plane plus12cm top patch,head plane and lower drop, each acrossB/C0/C1. Every gate's9interior samples observed,|TSDF|≤4cm and nearestmeshvertex≤sqrt(3)×4cm. Depending on geometry those9queries address only4or9unique voxels. These are coarse nonvacuity gates, not triangle-surface accuracy or independent9-point statistical evidence.
- Missing-floor hole:25/25 interior samples unobserved in each arm. A33-sample discrete footprint requires every sample supported and correctly rejects: unsupported27/33 B,27/33 C0,24/33 C1. This is not continuous swept-body safety.
- Actual drop:25/25 lower-surface observations and0/25 near-zero absent-upper-support samples in each arm. Upper locations may be observed free space; they are not support.
- History control actually supplied80,000 unavailable-zero current normals. WarmC1 retained1812gradient voxels; freshC1zero and C0 had0.81mutually observed comparisons differed: maximum warm/fresh1.9315mm, warm/C01.8591mm.27distant unknown queries remained unknown. These differences combine history and method; **no cached-fallback branch witness** or isolated-confidence causality. Positive→opposite→mixedtranslated stress retained480,000point submissions and finite output, not proven normal reliability.

## Critical limitations retained rather than averaged away
**2cm/4cm objects remain unresolved**, not counted as detection successes. Low shapes are sampled top patches, not complete cube sides or toys. All25tight2cm-bin queries on4cm tops fail in every arm despite being observed; nearestmeshvertex within4cm is24/25. The2cm case's25/25near values may share voxels/background proximity and do not resolve the object.

Tighter|TSDF|≤2cm reporting bins (B/C0/C1) on25samples:

| Surface | B | C0 | C1 |
|---|---:|---:|---:|
|0.3m plane|25|25|25|
|1m plane|17|17|25|
|3m plane|22|22|24|
|2cm top (unresolved)|25|25|25|
|4cm top (unresolved)|0|0|0|
|12cm top|9|5|9|
|Head plane|17|17|25|
|Lower drop|25|25|25|

These are fixed diagnostic bin counts, sensitive to voxel-center/threshold conventions; **not hazard detection percentages**, not reconstruction errors at surface coordinates, and not N1-vs-N2 comparisons except the separately paired closeplane. Coarse admission did not overwrite these stricter measurements.

Near-collinear positive-area normals are now numerically valid but can be arbitrarily noise-sensitive. No confidence calibration was invented. Double arithmetic begins after unchangedfloat unprojection; it cannot recover quantized information. Right/bottom silhouettes are provider-only checks, not native integrated border evidence. Meshvertex proximity is not trianglecoverage; no continuousclearance/bodymodel,realstairs,realtoys,dynamicobjects or iPhone performance tested. B/C0 differ beyond normals; C0/C1 bundles correction,gradienthistory andgrazing. All nativearms shareD1; historical unpatchedstock cannot isolate engine effects.

## Execution receipt
Singleworker/CPU,40.794043s wall,40.65 conservative sampledCPU seconds,534,167,552B peak summedRSS, no cap hit. Caps120CPU/150wall/2GiB/64MiB. Dedicatedrun cwd contains outputs; allincludedN1/N2headers frozen. Provider ELF proves sanitizer runtime, native ELF proves only D1 core (`cf37b843a4f9987d0523d85f2bf04b0ce12ee7a6d718c7cf1e642aa36c5e018b`) and not originalcore. No corebuild/install/download/spend/recordedimage or mapper-groundtruth input. Actualcalibration constants only reused from earlier metadata; syntheticgeometry generated analytically. Raw sample lists,denominators,compilerarguments andreceipts retained inrun/ and RESULT.json.

No further native/recorded execution is implied. Remaining priorities are small-object distinguishability, full surface/support coverage, boundary/unknown safety and noise/view-conditioned normal reliability—not a promised90%gain. Original upstream resourceblock, leakchecking limitation, serializationgradientloss and originalfailedbaseline remain preserved.
