# More rooms and the missing hazard benchmark

Research date: 2026-10-27. Metadata research only; no new room reconstruction or safety evaluation performed. Existing Coffee and Koivu are not pristine holdouts.

## Main conclusion
More real iPhone rooms are available. However, **none of the room datasets verified here supplies an independently annotated, synchronized iPhone replay benchmark of stair/drop-off warnings, missed hazards and warning distance**. A FARO room mesh can evaluate reconstructed geometry but does not by itself establish timely detection of a newly encountered drop-off. Room names are not evidence of stairs or small objects. Missing support must not become confirmed floor merely because a reconstruction looks plausible.

## Direct evidence about hazard detection

- [2026 single-user iPhone stair study](https://www.nature.com/articles/s41598-026-73419-5): iPhone 17 Pro Max, iOS 26.2; 120 controlled trials by one sighted investigator, eight locations, 11.4–19.1 cm steps. Reported detection 92.5% (95% CI 86.4–96.0), average warning distance 0.70 m. Descending approaches had numerically poorer detection/shorter warnings. No dedicated hazard-free control trials. This demonstrates both feasibility and misses, not guaranteed protection. Public code/raw replay data not verified in this search.
- [2023 Fall Risk Estimation](https://www.jstage.jst.go.jp/article/jrnal/9/4/9_8/_article/-char/en): genuine iPhone 12 Pro research separates walkable, positive obstacle, negative obstacle and occluded cells. Article CC-BY-NC 4.0. Public raw replay/code not verified; do not invent numerical results from its abstract.
- [2026 supervised station-platform study](https://www.fujipress.jp/jrm/rb/robot003800030882/?full=1): two visually impaired adults; treats negative obstacles and no-return/occluded cells as fall risk, and alerts when phone orientation cannot observe ground. Smartwatch alerts often did not prompt stopping; timing was a limitation, while crowds were untested. Exact phone model not identified in accessible full text. This is useful design evidence, not a released iPhone hazard benchmark. The full article's geometry method and alert timing must not be conflated.

## Ranked acquisitions: real rooms

### 1. MuSHRoom — easiest comparable independent geometry evaluation
[Official iPhone assets](https://zenodo.org/records/10230733), [independent FARO assets](https://zenodo.org/records/10222321). iPhone 12 Pro Max; CC-BY 4.0. See `MUSHROOM_SCENES.json` for exact bytes, URLs and official MD5s. Phone source mesh, RGB/depth and poses are provided; mesh-to-camera registration needs explicit verification. FARO assets are edited/cleaned reference geometry, not perfect hazard truth.

Prioritize computer, classroom and olohuone for distinct named environments, subject to image inspection before making furniture/doorway claims. Honka is the cheapest new pipeline check. All eight untested alternatives, source/reference archive sizes in decimal MB:

| Scene | Phone | FARO |
|---|---:|---:|
| honka |170.7|239.6|
| kokko |181.4|310.3|
| computer |216.7|307.7|
| vr_room |244.3|218.8|
| sauna |344.4|499.9|
| activity |362.1|603.8|
| olohuone |396.3|684.9|
| classroom |413.0|331.7|

These support source-only route topology, and separately registered reference geometry comparison. **No verified negative-obstacle episode labels.**

### 2. LiteReality — additional iPhone captures with confidence files
[Official dataset](https://huggingface.co/datasets/zhening/LiteReality_example_scans), [project](https://litereality.github.io/). LiDAR-equipped iPhone via 3D Scanner App plus RoomPlan according to project acquisition instructions; exact phone generation not documented. Dataset metadata says Apache-2.0; no independent laser reference verified.

Concrete captures: Darwin_BedRoom 127.25 MB; Girton_large_study_room 124.46 MB; Girton_Common_Room 144.48 MB; Meeting_Room_CUED_Lab 153.61 MB; Girton_Study_Room 251.12 MB; BoardRoom_CUED 348.86 MB. Exact filenames, sizes and LFS hashes in `LITEREALITY_METADATA.json`.

A bounded 131,072-byte HTTP range read of the Darwin bedroom ZIP central-directory tail verified depth PNG, confidence PNG, RGB JPG, per-frame JSON and RoomPlan USDZ member names. No whole archive downloaded or hashed; member contents not decoded. Confidence fields make this worth investigating for invalid/uncertain measurements. It does **not** establish independent collision or stair-miss scoring. Crucially, the project explicitly excludes small objects from its reconstructed scene pipeline and retrieves replacement CAD assets: use the raw captures for sensor evaluation, not the polished replica as hazard ground truth.

### 3. ScanNet++ — iPhone plus independent laser, larger access burden
[Official project](https://kaldir.vc.in.tum.de/scannetpp/), [official tools](https://github.com/scannetpp/scannetpp). Genuine iPhone 13 Pro plus FARO. Requires application/token and custom terms; do not assume redistribution rights. Subsets are possible; individual scene download sizes not verified here. Select train/validation scenes with reference: some test/NVS data omit laser geometry. No independently labeled drop-off warning episodes verified.

## Calibration supplement, not room navigation
[Close-range ARKit depth supplementary data](https://zenodo.org/records/23577624), 37.0 MB ZIP, author-reported iPhone 17 Pro/iOS 27.0.1: 154 records of 30 frames, depths/confidence/intrinsics/poses, independently measured printed-target geometry. Code MIT, data/photos/docs CC-BY 4.0. A single sampled depth pixel per frame is useful for sensor-error investigation, **not** full-frame small-object recall or stair navigation. Newly released; not independently reproduced here.

## Do not mislabel other datasets
- ARKitScenes: iPad Pro, not genuine iPhone validation.
- [RGB-D stair data](https://data.mendeley.com/datasets/6kffmjt7g2/1): RealSense D435i; labeled stairs useful for algorithm fixtures, not iPhone hardware claims.
- [Bonn stair data](https://www.ais.uni-bonn.de/data/stairs/): 230 RGB/point-cloud frames, 513 MB; page says no ground-truth segmentations. Device not verified as iPhone.
- [StairNet/ExoNet](https://pmc.ncbi.nlm.nih.gov/articles/PMC10870468/): iPhone XS Max RGB, not iPhone LiDAR negative-obstacle validation.

## Proposed bounded next experiment
1. Keep room-navigation and hazard-warning evaluations separate.
2. Acquire a new MuSHRoom source mesh/metadata selectively, using unchanged published route rules and predetermined endpoints; report invalid/no-path outcomes.
3. Obtain or record a dedicated supervised adult-only hazard dataset: independently measured steps/drop-offs, small floor objects, safe floor controls, RGB/depth/confidence/poses/timestamps, phone orientation and alert timestamps. No child exposure to hazards.
4. Score missed hazards and usable warning distance/latency, not just map coverage. Include occlusion, stale frames, tracking loss and contradictory observations. Unknown is not proof of a drop, but must not authorize movement as confirmed clear.
5. Never tune using reference geometry that also judges success; reserve unseen rooms/hazards after protocol freeze.

No new large downloads or parameter tuning were performed for this report. The research does not certify current navigation or suggest that a newer phone eliminates missing-data risks.
