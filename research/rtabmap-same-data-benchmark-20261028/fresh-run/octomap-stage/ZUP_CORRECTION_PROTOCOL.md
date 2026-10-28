# Separate world-Z-up corrected mapper and occupancy arm

Frozen before recorded-data execution,2026-10-28 18:50UTC. Root authorized correction after source audit, not after evaluating this arm. The earlier cached-grid occupancy plan remains preserved and **unexecuted on real data**; its native synthetic fixtures passed.

## Defect and input contract

MuSHRoom's bundled Nerfstudio processing documentation distinguishes camera OpenGL axes from world axes: camera+Y up is not world+Y up; the documented processed world is+Z up. Bundled Polycam processing uses row permutation[2,0,1] and orientation_override=none. See independent-review/WORLD_FRAME_SOURCE_AUDIT.md for exact source evidence and limits: the original capture exporter receipt/gravity measurements are unavailable. This correction adopts the documented processed-data contract explicitly, without using FARO or fitting a floor.

The old mapper applied an OpenGL-world-to-RTAB rotation A on the left of P. Its inverse was applied on cloud export, so raw geometry's world roundtrip and previous common point metrics remain valid; this cancellation did **not** validate gravity-sensitive ground classification. The old native ground/obstacle classification may be misoriented under the input contract. Do not reinterpret old ground labels as verified support.

Let P be the unchanged camera-optical-to-dataset-world matrix and O the released CameraModel.opticalRotation. Corrected native nodePose=P*O.inverse(). Native cloud decoder already applies O; export=nodePose*localCloud, and saved opticalPose=nodePose*O=P. There is no left A or output B world rotation. Per-frame calibration, RGB/depth units, native optical axes and all265/29 input identities remain unchanged.

## Replay and fixed controls

Run actual released Rtabmap::process on the same original265 RGB/depth images, poses and per-frame intrinsics. Fixed pose mode only. Rebuild native LocalGridMaker outputs inside that mapper: never rotate old grids to pretend segmentation was repaired. Same complete parameters as prior fixed arm, including Grid/RayTracing=false,0.04m cells,4m max range, normal segmentation45degrees, no ground-height threshold. No threshold relaxation, cloud/floor smoothing or obstacle removal. Inline cloud export correctly supplies native valid indices; original failed usage remains archived.

The second stage opens this corrected mapper database read-only and uses its265 ordered optical poses and newly regenerated local grids. Global native OctoMap changes only Grid/RayTracing=true, with released hit/miss/clamp/occupancy probabilities unchanged. Corrected node pose is againP*O.inverse(); output already in dataset world, no world-axis conversion. Zero stored viewpoint translation required. Unknown remains unrepresented, never free; historical type/refID is not authoritative over occupancy probability. Ground remains native classification, not live verified floor support.

Native pre-data fixtures must pass: asymmetric world point, optical/node roundtrip, released LocalGridMaker horizontal world-Z plane classified as ground and not obstacle; native occupied hit→repeated observedfree, missingevidence/unknown, low/head separation, duplicate-prefix and duplicate-endpoint behavior, historical-type caveat. Raw input hashes/DB/pose hashes, source/binary and complete protocols pinned before execution. Old successful/failed builds and results preserved.

Evaluation uses the separately frozen existing common4cm nearest-reference geometry protocol, descriptive label octomap_zup_regenerated, native occupied+ground measured-endpoint output only. No FARO mapping input, empirical gravity fit or metric tuning. Free/unknown/type counts reported independently. This stage does not certify paths, stairs, toys, children, collisions or safe floor support.

Deadline19:08:24UTC, cumulative35CPUminutes including180s interrupted-build charge; same aggregate1.5GiBdownload/6GiBdisk/3GiBsampledRSS/oneCPU caps.
