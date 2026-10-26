# Real iPhone room geometry — primary-source options, 2026-10-26

## User acceptance scope: navigation first, including real furnished iPhone rooms

Authored rooms/houses remain useful controlled tests, but do not replace the user's explicit requirement for real furnished room geometry captured by an **iPhone**. Keep distinct labels for: authored known-map routing; synthetic sensing in a real iPhone-reconstructed room; recorded iPhone RGB-D replay; progressive unknown-space navigation; actual native localization; and supervised device use. Success is A→B reached with zero collision/health loss. Safe standing still, a returned path or a failed/invalid start is not success.

## Recommended bounded first option: MuSHRoom

The original WACV 2024 paper identifies **iPhone 12 Pro Max with Polycam**, across ten furnished indoor scenes, alongside separate Faro reference geometry. The phone reconstruction is not the reference laser mesh. [Original paper](https://openaccess.thecvf.com/content/WACV2024/papers/Ren_MuSHRoom_Multi-Sensor_Hybrid_Room_Dataset_for_Joint_3D_Reconstruction_and_WACV_2024_paper.pdf), [official repository](https://github.com/TUTvision/MuSHRoom).

Public Zenodo API metadata was read without downloading any archive or accepting account terms. Both records report `access_right: open`, `license.id: cc-by-4.0`. DataCite independently confirms the license. [iPhone record](https://zenodo.org/records/10230733), [iPhone file/license API](https://zenodo.org/api/records/10230733), [reference file/license API](https://zenodo.org/api/records/10222321), [DataCite metadata](https://api.datacite.org/dois/10.5281/zenodo.10230733), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

| Exact published file | Compressed bytes | Published MD5 |
|---|---:|---|
| `koivu_iphone.tar.gz` | 146,575,749 | `a359dba714e7829be11747ce5dee141c` |
| `honka_iphone.tar.gz` | 170,700,232 | `f1ef5f46cd19ad0219f68d74758acf17` |
| `honka_mesh_pd.tar.gz` | 239,649,902 | `75091793bf13919cb61e346300e3f828` |

Koivu is the smallest iPhone-only archive among the ten listed bundles. Honka is the smallest paired iPhone/reference combination among those listed: **410,350,134 compressed bytes**. These are not extracted-size, memory, geometry-quality or localization guarantees.

### Content and coordinate constraints

The iPhone bundles list long/short RGB images, depth, Polycam poses, globally optimized COLMAP poses and a Polycam mesh. The official README warns that **the Polycam mesh is not aligned with those poses and is for visualization**. Reference bundles contain `gt_mesh.ply`, `gt_pd.ply` and alignment matrices; `icp_iphone` maps coordinates associated with `transformations_colmap.json` into the Faro reference frame. [Official repository](https://github.com/TUTvision/MuSHRoom), [reference metadata](https://api.datacite.org/dois/10.5281/zenodo.10222321).

The author-linked parser preserves metric pose scale by default, scales stored depth by **0.001 to metres**, treats depth as optical-axis rather than Euclidean ray distance, and handles additional applied transforms/scales/orientation metadata. Audit the actual selected archive instead of assuming the current renderer's axis transform is correct. Never normalize the room to a unit box. [Parser source](https://github.com/maturk/dn-splatter/blob/main/dn_splatter/data/mushroom_dataparser.py).

This is processed research data, not unmodified raw ARKit replay. Completed COLMAP optimization is not causal online localization. Manufactured confidence masks are not original ARKit confidence. A mesh is not proof of watertightness, complete obstacles, supported floor or head clearance.

### Optional bounded acquisition plan — not executed

The latest local disk check showed only about **1.2 GB free**. Recheck immediately before acquisition; retain a conservative free-space reserve. Proposed initial limits are a 160-MiB compressed-transfer cap and 256-MiB selective-extraction cap, subject to enough room to preserve at least 768 MiB free. If the actual preflight cannot satisfy those caps plus reserve, do not start; request a smaller authorized target or additional storage.

1. Acquire only the exact `koivu_iphone.tar.gz` file from its public official record. The [author-linked downloader](https://github.com/maturk/dn-splatter/blob/main/dn_splatter/data/download_scripts/mushroom_download.py) identifies the source, but its unrestricted default extraction must not be run.
2. Verify published MD5 as a provenance/integrity comparison and record local SHA-256. MD5 is not a security authenticity guarantee.
3. Inspect archive member names, declared sizes and types before extraction. Reject traversal, absolute paths, links, special files and members over bounds. Do not assume decompressed size from compressed size.
4. Initially select the mesh, required material dependencies and minimal pose metadata within the cap. A truncated/incomplete asset is not a passing scene.
5. Audit actual units/gravity, bounds, holes, floor/body/head clearance and a fixed whole-body start. Preserve invalid starts rather than silently relocating them.
6. Existing CPU VTK can then produce **synthetic sensor views in an iPhone-reconstructed room**. That is useful real-geometry testing, not recorded-phone replay.
7. A later separately bounded recorded RGB-D test must extract a small frame subset and prove pose/depth alignment. A later reference-mesh comparison may use Honka's pair, avoiding the large point cloud if unnecessary. Do not attempt full paired extraction under present disk limits.

Keep complete truth geometry and future-optimized poses outside progressive planner inputs. Saved-map geometry supports prior route planning, never current clearance. New chair/closed door/person tests must reach the engine through actual current synthetic/recorded camera observations, not hidden-truth injection.

**Attribution:** credit MuSHRoom and Xuqian Ren, Wenjia Wang, Dingding Cai, Tuuli Tuominen, Juho Kannala and Esa Rahtu; link the original publication, exact Zenodo record/version and CC BY 4.0; identify conversions/modifications.

## Other sources screened

- **ARKitScenes:** Apple's README explicitly says iPad Pro. Existing ARKit47333462 is real Apple-LiDAR proxy evidence, **not proven iPhone capture**. [Apple source](https://github.com/apple-aiml-research/ARKitScenes).
- **ScanNet++:** iPhone 13 Pro RGB-D plus independently captured laser mesh. Account/application approval/token and noncommercial research terms apply. Strong later held-out option, not the simplest present acquisition. [Original paper](https://openaccess.thecvf.com/content/ICCV2023/papers/Yeshwanth_ScanNet_A_High-Fidelity_Dataset_of_3D_Indoor_Scenes_ICCV_2023_paper.pdf), [official documentation](https://scannetpp.mlsg.cit.tum.de/scannetpp/documentation), [terms](https://scannetpp.mlsg.cit.tum.de/scannetpp/static/scannetpp-terms-of-use.pdf).
- **MultiScan:** mixed iPhone 12 Pro and iPad Pro 2020 capture, requiring scene-specific device confirmation. Official dataset access is gated; CC BY-NC 4.0. Do not label an arbitrary MultiScan scene iPhone. [Official dataset](https://huggingface.co/datasets/3dlg-hcvc/MultiScan).
- **RoomPlan:** useful parametric room information, not complete collision geometry; recognized objects may be bounding boxes. [Apple documentation](https://developer.apple.com/documentation/roomplan/captured-object-attributes).

## Evidence status

PRIMARY-source research and metadata verification only. **No dataset archive downloaded, account created, terms accepted, scene extracted, start validated, localization run or real-iPhone-room navigation episode completed in this research task.** This document belongs in the first-priority navigation acceptance scope without changing the status of existing authored or iPad-based results.
