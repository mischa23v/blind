# Primary-source coordinate and registration review

The fresh comparison's transform direction is supported by upstream code, not selected by whichever direction gives a lower residual.

- [MuSHRoom evaluate_mesh.py at 3f36dbfe24c783f85e320a613096eee5216839eb](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/evaluate_mesh.py): the iPhone branch loads `icp_iphone.json`'s `gt_transformation`, and subsequently applies it to the predicted mesh before comparison with the unchanged FARO mesh. Verified Git blob `bd8cb80a2dbd1ab2d21f2d8b65ddb8c793d03ce3`.
- [The original MuSHRoom within-sequence iPhone converter](https://github.com/TUTvision/MuSHRoom/blob/3f36dbfe24c783f85e320a613096eee5216839eb/iphone_tools/1_nerfstudio_to_sdfstudio_within.py) reads `transformations.json`, converts its camera convention, and records a reversible normalization as `worldtogt` for its own SDF pipeline. Our Open3D worker does not apply that SDF normalization; it stays in the supplied original phone frame.
- [DN-Splatter's pinned data parser](https://github.com/maturk/dn-splatter/blob/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/data/mushroom_dataparser.py) loads the same registration and applies its inverse to FARO points, corroborating the forward phone-to-FARO direction.

The evaluator uses `registration × original camera-to-phone` for rays into the unchanged FARO mesh. It applies the inverse of that combined transform to each hit and takes negative camera Z, yielding **phone-frame axial metres**, not FARO Euclidean ray length. The registration includes a fixed author scale of 1.0207908442387768; it is not fitted in this run and must not be applied a second time to the reported axial depths. Independent algebra checks cover all 29 camera poses and three asymmetric rays each.

## Reproduction qualification

The pinned DN-Splatter iPhone point-cloud loader reads `transformations_colmap.json`, whereas this established project baseline explicitly binds the original `transformations.json` Polycam poses. Therefore this is **the same historical, author-configured Open3D integration reproduced on fixed original poses**, not an unchanged execution of the current DN-Splatter data-loader pipeline or its complete reconstruction/evaluation workflow. The pose-file selection belongs in the adapter-difference list alongside image loading and output serialization. No pose file was changed to improve these results.

## Pixel and evaluation scope

Actual comparison rays use integer pixel coordinates, consistent with the Open3D backprojection used by this baseline. The inherited helper also runs a half-pixel convention fixture, but that fixture does not change the actual rays. Earlier half-pixel reference scores are a different sampling protocol and should not be treated as identical reruns.

The source establishes transform direction, not registration accuracy. Author registration uncertainty and the measured-versus-completed FARO face mask remain unavailable. This comparison cannot label physical hazards, prove floor support or establish navigation safety.

The bounded independent recount (`recount.py`, `REVIEW.json`) verifies every frozen input hash, 58 saved query arrays, all 29 held-out depth hashes, disjoint 265/29 frame sets, all per-frame and pooled numerical summaries, and camera/registration algebra. It does not repeat the expensive mesh raycasts or fusion. Neither the input freeze nor saved files are externally immutable; the child evaluator did not receive an expected launch hash for the freeze itself. These limitations are retained explicitly.
