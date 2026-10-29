# N3 reconstruction dependency scope — source-only audit

## Decision
Retain the existing B and C0 reconstruction controls; the N2-to-N3 normal-value/support change provides no native mapping dependency that warrants rerunning them. Run only C1 if independently authorized and all stage admission/identity checks pass. This is a source dependency conclusion, **not an executed N3 B/C0 equivalence experiment** and not a claim that B equals C0.

The conclusion is conditional on unchanged points, order, colors, poses, configuration, initial map, native core/dependencies, and submission sequence. Whole-frame preflight failure must block the stage, never silently remove points or frames. N3 changes normal reason counts, zero-vs-unit availability and direction; these must not become point filters. Provider cost/ledgers can change even when native geometry dependencies do not.

## Exact inspected sources
Paths below are relative to `zero-direction-candidate/source/voxblox/`. The retained source derives from official Voxfield revision `78ee6403720e0aed87f4720c04c813bb38a3b260` (BSD-3-Clause). D1 is a **local exact-zero RayCaster adaptation**, not an upstream release; it changes no normal dependency.

### B: MergedTsdfIntegrator projective
- `include/voxblox/integrator/tsdf_integrator.h:236–238`: public merged integration API accepts pose, points, colors and freespace flag; there is no normal array argument.
- `src/integrator/tsdf_integrator.cc:304–331`: entry, index getter, bundling and integrateRays depend only on those inputs/configuration.
- Same file `442–493`: merged dispatch/storage path carries no normal input.
- Retained `full265-c1-recovery/adapter.cpp:127,130`: B constructs `MergedTsdfIntegrator(pcfg(),...)` and invokes `integratePointCloud(f.pose,f.points,f.colors,false)`. Normal output is not passed to B.

### C0: MergedNpTsdfIntegrator with normal_available=false
This is not literally an API that never accesses the normals array: its shape and indexability are still required.
- `include/voxblox/integrator/np_tsdf_integrator.h:68`: default false; `268–271` still accepts normals.
- `src/integrator/np_tsdf_integrator.cc:435–457`: CHECK_EQ point/normal sizes at441; index getter and bundleRays use points only.
- `478–503`: bundle eligibility/indexing uses points/poses only, not provider reason/availability.
- `568–603`: merged normal initialized zero at580, normal element reference bound at585; point weight/mean/color at588–595 independent of it. All actual merged-normal arithmetic is gated by `config_.normal_available` at596–602.
- `611–617`: C0 transforms the unchanged zero merged normal and creates RayCaster from origin/merged point only. Anti-grazing at621–627 uses voxel indices, not normals.
- `278–364`: base distance at286; normal-dependent correction/rejection at298–334 is guarded by `normal_available`; gradient update at355–360 also guarded. With false, neither normal direction, zero availability, cached gradient nor reliable-normal threshold affects voxel distance/weight/color updates. Other non-normal SDF/weight gates still apply.
- Retained adapter `117,127`: `ncfg(on)` explicitly sets flag; mode1 C0 passes false, mode2 C1 true. Call at130 passes same-sized normal vector.

Therefore finite zero/unit normal values and provider-valid/invalid labels do not affect **C0 native mapping** in this merged configuration, provided every point stays submitted. Do not generalize this to absent/mis-sized arrays, malformed inputs, another integrator implementation, changed preflight policy, or changed config.

### Why C1 must be evaluated
With flag true, merged-normal accumulation at596–602, reliable-band correction/rejection at298–334 and gradient update at355–360 all depend on normals. N3's wider stencil and altered unavailable support can thus change geometry and integration coverage. Zero current normal does not universally disable normal correction: a cached gradient can still be used in the enabled branch. No direction/gain/safety conclusion follows from the provider diagnostics alone.

## Read-only source/header pins
SHA-256 below was computed from retained files during this audit. Equality column compares bytes against the official retained source snapshot, not a network checkout. No raw images/depth, mapping execution, builds, or runtime state were read/run here.

| Relative core file | SHA-256 | Equals official snapshot |
|---|---|---|
| `src/integrator/tsdf_integrator.cc` | `6d7635ad202d4974fca0037e20f215743ddfca60a73e7cef1e0cd9e79b44c4bf` | True |
| `src/integrator/np_tsdf_integrator.cc` | `fcb30118aca5e9d550a87127f6ac991e66683625b6d1ee3ac7111d2a70358624` | True |
| `src/integrator/integrator_utils.cc` | `bbe6e21b3ecc8c8abdc86739f0215f7c3ed1da729f3aca9853b30afe17b2866d` | False |
| `include/voxblox/integrator/tsdf_integrator.h` | `99ce9183307334c018f2f2fa0d3b32c898748a308aa32055e0a20577723298ec` | True |
| `include/voxblox/integrator/np_tsdf_integrator.h` | `e71b4727d14884bd9b5bffd2bc7b2090f0030e0121fc1b8e69080db8ca2d01bd` | True |
| `include/voxblox/integrator/integrator_utils.h` | `5318bc25f11fbd0840e0166c0e8d879ba9dacc99f89740181bdec7b7ba72985d` | True |

Additional adapter/provider pins (preparation snapshot; final execution freeze must independently pin them):

- `full265-c1-recovery/adapter.cpp`: `34a5b3ba231ffaf5fec2970bec561daa8170a5013a3bfc32445bf4d6bdd92929`
- `n2-normal-candidate/n2_adapter.h`: `5c773bdc05c65783fdfa4b06d980366913e4a82270c341b42e2029acec12d84b`
- `n3-native-spacing/n3_adapter.h`: `147697d39515f997625e242e16595a614bfa12a3c1c4a8ecefce1674437e5bbe`
