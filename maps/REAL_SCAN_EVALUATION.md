# Real apartment reconstruction fixture

Source: [3DLite, Stanford/TUM](https://graphics.stanford.edu/projects/3dlite/index.html), Jingwei Huang, Angela Dai, Leonidas Guibas and Matthias Niessner (2017). We use the **initial** apartment RGB-D reconstruction, not the completed model. Completion can invent plausible geometry and is unsuitable as evidence that a path exists.

Downloaded file: `artifacts/real-scene/apt-initial.ply`, 69,648,589 bytes. SHA-256: `0eb82b4fc04ed1d8244689b67522904db84fc325f49282aaa3b84dc61b70428f`.

The data and derived preview/grid retain **CC BY-NC-SA 4.0** attribution. They are not covered by any future software license. The handoff archive includes the reproducible script and instructions, not this dataset; run the script to download it separately. No personal school/home scan is uploaded.

Run from the project root:

```sh
uv run --with numpy==2.2.6 --with plyfile==1.1.5 --with matplotlib==3.10.9 python tools/real_scene.py
swift run --package-path BlindCore --scratch-path artifacts/swift-macos RealSceneEvaluation artifacts/real-scene/surface.json
```

On Windows the second command can run inside the same `swift:6.2-noble` Docker image used by verification. Outputs are `scan-preview.png`, `surface.json`, `source.json` and `inspection.json`. The Swift executable decodes the actual derived grid and exercises the app's `NavigationSurface` clearance checks at every observed-floor cell.

The script checks the downloaded hash, finite vertices and triangle indices. It estimates a floor band from this dataset's Z-up coordinates and creates a conservative 10 cm inspection grid. Observed floor, reconstructed obstacles and unknown floor are separate. **A mesh does not include observed free-space rays**, so head/body clearance remains unknown and the core refuses to authorize routes from that evidence alone. No room names, restrooms, exits, stairs or live poses are invented. This is a real geometry import audit, not a completed localization or navigation test.

Recorded result: 1,679,023 vertices, 3,291,072 triangles, 5,733 grid cells, 2,783 cells with observed floor and 1,852 with reconstructed obstacles. Floor and obstacle counts can overlap. The Swift audit passed all 2,783 checks that unknown body clearance must refuse route authorization. Local output: `artifacts/real-scene/core-evaluation.json`.

Use the preview to inspect what is actually present. The initial mesh has reconstruction artifacts and is not ground truth. Sensor lighting, timing, mounting and cliff reliability require recorded sensor data and physical tests described in [the elevation research](../research/ELEVATION_AND_LIGHTING.md).
