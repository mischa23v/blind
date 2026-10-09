# Upward steps, downward drops and room replay

Run date: 2026-10-03. **Not ready for child walking trials.** This evaluation executes the project's actual Swift `HazardDetector` and C++ `GroundMonitor`. No LLM participates in hazard decisions. A rise is an obstacle requiring immediate attention; a drop is a drop requiring immediate attention. Neither waits for another sensor to agree. Missing trustworthy ground evidence must not be described as a clear path.

## Known synthetic targets

| Experiment | Correct specific warning | Any stop warning | Uncertainty stops |
| --- | ---: | ---: | ---: |
| Phone core, downward steps | 15/21 | 21/21 | 6/21 |
| Phone core, upward steps | 10/21 | 21/21 | 11/21 |
| Belt ground logic, downward changes | 8/21 | 8/21 | 0/21 |
| Belt ground logic, upward changes | 8/21 | 8/21 | 0/21 |

Phone cases use step heights 4, 8, 10, 12, 18, 25 and 40 cm at distances 0.7, 1.2 and 1.8 m, with ideal level-floor calibration and noise-free, high-confidence geometry. The 4 and 8 cm steps lose sufficient floor support and stop as unknown, rather than receiving a specific label. Upward steps at 1.8 m are outside the current 1.6 m obstacle classification horizon. There is no claim that 21/21 stops means perfect detection. A separate unchanged level-floor control remains observing; two missing-ground cases stop as uncertain. Three synthetic room objects receive their expected two obstacle and one overhead warnings.

Belt cases isolate one fresh ground channel while the other still reports the level floor. A fixed 1 m mounting height, downward angles of 30, 45 and 60 degrees, and the same seven heights produce 21 cases per direction. Slant range is calculated geometrically; no noise, sunlight, body motion or other belt sensor is simulated. The current 250 mm slant-range threshold misses every 4–12 cm step in this sweep and the 18 cm step at 60 degrees. Those 13/21 misses in each direction are failures, not harmless changes. Reducing a constant threshold without measuring noise and belt attitude would not establish reliable detection. Belt attitude compensation and measured small-step performance remain blockers.

The test suite also exercises first-frame phone warnings, immediate single-channel belt rise/drop, simultaneous rise and drop, other-channel faults, stale/duplicate readings, release persistence and warning priority. Passing those implementation checks does not resolve the broader coverage failures above.

## Real staircase recordings

Downloaded a fixed, evenly spaced 12-frame subset of the [RGB-D stair dataset, version 1](https://data.mendeley.com/datasets/6kffmjt7g2/1), DOI `10.17632/6kffmjt7g2.1`, by Chen Wang, Zhongcai Pei, Shuang Qiu, Yachun Wang and Zhiyong Tang. Data license: **CC BY 4.0**. All 36 files (RGB, point cloud and extrinsics for each frame) match publisher sizes and SHA-256 hashes. The download manifest retains source URLs, attribution and hashes. The associated model repository's license is different; no model weights or source were imported.

Indices were fixed before scoring: `0, 14, 28, 42, 56, 70, 84, 98, 112, 126, 140, 153`. RGB inspection includes ascending and descending stairs and very dark views. Frame 112 is an oblique landing and excluded from direction scoring. Labels are manual visual expectations, not publisher-provided hazard ground truth.

Camera height relative to the floor is unavailable, and the inferred gravity-vector convention in the extrinsics has not been independently verified. Therefore the replay runs three **assumed** heights (0.9, 1.2 and 1.5 m) with ideal prior calibration. These are calibration sensitivity diagnostics, **not a valid real-world accuracy benchmark**. The conditional results include upward stairs misclassified as drops: 7/18 upward runs say obstacle, 10 say drop and one says uncertain. The 15 downward runs say drop. Multiple height assumptions on one frame are not independent samples. Every run stops, but that must not be reported as 100% accurate stair recognition.

Dark RGB images do not establish night-time sensor performance. No physical morning/night, sunlight, alert latency or human response measurements have been performed.

## Real room geometry

The initial [3DLite apartment reconstruction](https://graphics.stanford.edu/projects/3dlite/index.html) contains 3,291,072 real reconstructed triangles. Dataset attribution and **CC BY-NC-SA 4.0** terms are retained in [the import record](../maps/REAL_SCAN_EVALUATION.md). It is not the completed mesh that fills missing geometry.

Six virtual camera poses were selected from the inspection grid before running the detector: four directed toward furniture/walls/partitions and two floor controls. First-hit rays use a 64×48 image, 70×70 degree field of view, 50-degree downward pitch and 1.2 m camera height. These are favorable synthetic sensor settings, not a measured iPhone camera model. Returned points use ideal confidence. Missing mesh surfaces stay missing. Expectations are manual and are retained even if the detector disagrees.

The generated `artifacts/stairs/score.html` and `score.json` contain the exact room results and all individual synthetic, belt and conditional real-stair results. They separate category matches, unknown stops and ordinary observing states. This is a virtual sensor replay through a real room, not a physical room trial or localization test. Distances are nearest classified sample distances, not measured distances to a first stair edge.

Observed results: **4/4 obstacle views produced an obstacle warning; 0/2 floor controls produced the expected observing state. Both controls stopped as uncertain.** Thus only 4/6 original room labels matched. These control mismatches remain failures against the predeclared expectations; they reveal a coverage/usability issue to investigate, not proof that the represented floors are dangerous. The six poses are a tiny manually selected set, not a representative room accuracy estimate. Three obstacle warnings occurred at sample distances around 0.30–0.34 m; this does not establish enough time for a person to react.

## Reproduce

From the repository root with Python/uv, Node, Docker and network access for public datasets:

```sh
uv run python tools/download-stairs.py
uv run --with numpy --with plyfile python tools/make-sensor-replay.py
uv run --with numpy==2.2.6 --with plyfile==1.1.5 --with matplotlib==3.10.9 python tools/real_scene.py
uv run --with trimesh --with embreex --with rtree --with plyfile --with numpy python tools/make-room-replay.py
```

Build and run the actual core sequentially. On Windows, the following volume path matches this workspace; change it for another location. The shell inside Docker handles output redirection, preserving UTF-8 JSON.

```sh
docker run --rm -v C:/blind:/workspace -w /workspace swift:6.2-noble swift build --package-path BlindCore --product SensorReplay
docker run --rm -v C:/blind:/workspace -w /workspace swift:6.2-noble sh -c 'BlindCore/.build/debug/SensorReplay artifacts/stairs/replay-input.json > artifacts/stairs/replay-results.json'
docker run --rm -v C:/blind:/workspace -w /workspace swift:6.2-noble sh -c 'BlindCore/.build/debug/SensorReplay artifacts/real-scene/room-replay-input.json > artifacts/real-scene/room-replay-results.json'
docker run --rm -v C:/blind:/workspace -w /workspace swift:6.2-noble sh -c 'clang++ -std=c++11 -Wall -Wextra -Werror firmware/test/elevation_score.cpp -o /tmp/elevation-score && /tmp/elevation-score > artifacts/stairs/belt-elevation-score.csv'
uv run python tools/score-sensor-replay.py
uv run --with numpy --with matplotlib python tools/render-replay-preview.py
```

On the Mac, use `swift run --package-path BlindCore --scratch-path artifacts/swift-macos SensorReplay <input>` and redirect to the corresponding result path, and compile the same C++ source with `clang++`. Dataset download scripts are included in the handoff; raw/derived dataset files are excluded to keep their licenses and data separate from the app source. The written findings remain in the archive.

Physical next steps and the warning-distance budget are in [elevation and lighting research](ELEVATION_AND_LIGHTING.md). The unresolved calibration, small-step coverage, sensor mounting and response-distance issues prevent a credible overall reliability score.

## Follow-up: gaps and sample density, 2026-10-03

Inspecting the baseline floor controls found insufficient floor samples in five central cells at 1.1–1.9 m for `central-floor`, and one central cell at 0.3–0.5 m for `central-floor-south`. The latter had two accepted floor samples where the detector requires three. Cell dimensions are 19×20 cm; this describes analysis bins, **not the dimensions of a physical hole**. An absent mesh surface cannot establish real floor absence or presence.

Reran the same mesh and six poses with **128×96 virtual rays instead of 64×48**, leaving the detector unchanged. All four obstacle views still produced obstacle warnings. `central-floor-south` now produced observing; `central-floor` remained uncertain. Thus the floor controls improved from 0/2 to 1/2 matching expectations in this particular replay. This exploratory follow-up was chosen after inspecting failures, not held-out validation. The original scores remain unchanged. More virtual rays do not establish independent real depth measurements or iPhone performance. Following this experiment, the live sampler was changed to every second row/column, retaining confidence checks; its latency and actual effectiveness need device testing. No prediction-based clearance has been added.

Reproduce the follow-up, after the baseline dependencies/build above:

```sh
uv run --with trimesh --with embreex --with rtree --with plyfile --with numpy python tools/make-room-replay.py --width 128 --height 96 --prefix room-dense
docker run --rm -v C:/blind:/workspace -w /workspace swift:6.2-noble sh -c 'BlindCore/.build/debug/SensorReplay artifacts/real-scene/room-dense-replay-input.json > artifacts/real-scene/room-dense-replay-results.json'
uv run python tools/score-sensor-replay.py
```
