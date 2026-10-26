# Official Open3D sample — local development fixture only

No integration, detector or navigation result is implied by acquiring these files.

- Open3D `SampleRedwoodRGBDImages.zip`: official release `20220301-data`, 3,772,513 bytes, published MD5 `43971c5f690c9cfc52dda8c96a0140ee`. Full local SHA-256 and every extracted file's hash are in the acquisition receipt.
- Open3D tutorial source: release 0.19.0, commit `1e7b17438687a0b0c1e5a7187321ac7044afe275`; original notebook bytes and MIT license are retained in `upstream/`. Source license: https://github.com/isl-org/Open3D/blob/1e7b17438687a0b0c1e5a7187321ac7044afe275/LICENSE .
- Official data hosting repository: https://github.com/isl-org/open3d_downloads , MIT hosting-repository license. Do not infer that all upstream data rights are replaced by this software license.
- Original ICL-NUIM data: explicitly CC BY 3.0 at https://www.doc.ic.ac.uk/~ahanda/VaFRIC/iclnuim.html ; https://creativecommons.org/licenses/by/3.0/ . Cite A. Handa, T. Whelan, J. B. McDonald and A. J. Davison, *A Benchmark for RGB-D Visual Odometry, 3D Reconstruction and SLAM*, ICRA 2014.
- Redwood augmented data: https://redwood-data.org/indoor/dataset.html ; cite Sungjoon Choi, Qian-Yi Zhou and Vladlen Koltun, *Robust Reconstruction of Indoor Scenes*, CVPR 2015. This is synthetic augmented ICL-NUIM data, not real recorded iPhone data. The separate Redwood 2017 Lidar-RGBD public-domain declaration is not transferred to this 2015 subset.

The exact terms on every Redwood-added trajectory/noise/reconstruction asset are not independently established by the source-code MIT license. Keep this sample archive, raw images and reconstruction local; source-only publication may include the acquisition code and hashes, not the raw fixture. Any later asset redistribution requires file-specific licensing/attribution review.

`example_tsdf_pcd.ply` is described upstream as a TSDF reconstruction, but the precise generating frame subset/configuration is not established. It must not be treated as an independently measured reference or exact golden output of the five-frame tutorial without further evidence.

Acquisition preserves archive/source/member bytes. No depth interpolation, pose changes, confidence invention, image generation, fusion, filtering or repair is performed.
