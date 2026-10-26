# Camera and scale audit provenance gap

The five files under `blind-split-candidate-game-03/room-scale-readonly-audit/` are preserved terminal outputs of ad-hoc Python heredocs. **The executed calculation/plot scripts were not retained as files.** This note records the original audit's reported values and method; it is not a reconstructed executable or a new verification run. No historical source hash is invented.

Input identities already pinned elsewhere in this packet:

- `inputs/koivu_5cm_v2_pipeline2_out.npz`: `a2fc5c13f86bf7033131347fd9b6d61db23ab716d12d668a3d969b9e87dbf48d`.
- `inputs/koivu_5cm_occthres_split0.7.npz`: `b294d92cfd9136d00de510239c2b85a9d68d878dcf7dac1a64b144d8880cb076`.
- Original `transformations.json`: `c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3`.

Reported method: levelled camera positions = camera translation × Rᵀ + t; cell IJ = floor((XY − lo[:2]×0.05)/0.05). Game display coordinates are [X,−Y]. No timestamp or continuous body path was inferred.

Reported checks: spacing 0.05 m; shape 241×250; lo [−116,−121,−4]; domain 12.05×12.50 m. R singular values all 1, determinant 1, maximum orthogonality residual 2.22e−16; tilt 0.050076037397°. Translation approximately [−0.000902622890,−0.000647555310,1.27104227]. Raw pose rotation singular-value range 0.9999999562342176…1.0000000428397993. Original projection source converts UInt16 millimetres with ×0.001; sampled frame 1 median 3346 becomes 3.346 m. Reference similarity singular values are approximately 1.020790844; this transform is absent from the phone route adapter.

Floor-support mask bounds span 11.05×10.80 m, not wall-to-wall dimensions. The target's 5.20×7.70 m bounding box and 11.6675 m² mask area describe a blocked component, not a measured table. Conclusion is limited to **no gross unit/scale/axis defect found in the inspected adapter**, not absolute physical scale calibration. The signed-key bug's causal impact is quantified separately by the fully sourced later diagnostic.

The PNGs were visually checked as numeric maps/charts with no people or personal screenshots. Their existing labels and caveats are retained unchanged. Missing invocation provenance is an explicit publication limitation, not permission to claim a clean rerun.
