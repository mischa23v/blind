---
license: cc-by-4.0
pretty_name: "Everyday Manipulation 3D (raw RGB-D)"
size_categories:
- 1K<n<10K
task_categories:
- robotics
- video-classification
tags:
- egocentric
- robotics
- manipulation
- rgbd
- lidar
- depth
- hand-object-interaction
- embodied-ai
- arkit
- record3d
configs:
- config_name: default
  data_files:
  - split: train
    path: index.csv
---

# Everyday Manipulation 3D (raw RGB-D)

**1,513 clips · 10.28 hours · 279 GiB · 4 participants · 10 manipulation tasks · 42 recording sittings**

Chest-mounted iPhone Pro capture of everyday two-handed manipulation by
[CaryX AI](https://caryx.ai). Clips were recorded with
[Record3D](https://record3d.app/), an iOS app that captures the
iPhone's LiDAR RGB-D stream. Each clip is the app's `.r3d` recording with the
audio track removed; the sensor streams are unmodified: **synchronised RGB,
metric LiDAR depth, per-frame ARKit 6-DoF camera pose, and per-frame camera
intrinsics.**

## Why this exists

An open sample of raw 3D egocentric manipulation data for training and building
models, released under CC BY 4.0, including commercial use with attribution.
For labels, larger volumes, or questions, reach out to
[founders@caryx.ai](mailto:founders@caryx.ai).

## What's in a clip

Each `.r3d` is a ZIP containing:

| member | what it is |
|---|---|
| `metadata` | JSON: `K` (3×3 intrinsics, column-major), `poses` (per-frame `[qx,qy,qz,qw,tx,ty,tz]`), `frameTimestamps`, `perFrameIntrinsicCoeffs`, `initPose`, `cameraType`, `w`/`h`, `dw`/`dh`, `fps` |
| `rgbd/<i>.jpg` | RGB frame |
| `rgbd/<i>.depth` | metric depth, float32 metres, **LZFSE-compressed** |
| `rgbd/<i>.conf` | ARKit per-pixel confidence, uint8 (0=low, 1=med, 2=high), **also LZFSE-compressed** |
| `icon` | a small JPEG thumbnail written by the app |

**Both orientations are present.** 1,027 clips are portrait and 486
are landscape, and the frame dimensions swap accordingly:

| orientation | clips | RGB | depth |
|---|---:|---|---|
| portrait | 1,027 | 1440×1920 | 192×256 |
| landscape | 486 | 1920×1440 | 256×192 |

Every clip's actual `w`/`h`/`dw`/`dh` are in its own `metadata`, and in
`index.csv` as `rgb_w`, `rgb_h`, `depth_w`, `depth_h`, `orientation`. **Read
them per clip.** A loader that assumes one orientation will transpose every
frame of the other.

**`K` is in RGB pixel units, so it cannot be applied to depth pixel coordinates
directly.** Depth shares the camera's optical geometry but is sampled on a much
smaller grid, so before back-projecting you must either map the depth pixel into
RGB pixel space, or scale the intrinsics by the resolution ratio:

```python
# map a depth pixel (px, py) into RGB pixel space, then use K unchanged
u = px / (dw - 1) * w
v = py / (dh - 1) * h
X = (u - cx) / fx * Z;  Y = (v - cy) / fy * Z          # Z = depth_m[py, px]

# equivalently, scale the intrinsics once into depth pixel space
fx_d, cx_d = fx * dw / w, cx * dw / w
fy_d, cy_d = fy * dh / h, cy * dh / h
```

Do not assume `depth[y, x]` corresponds to `rgb[y, x]`.

Reading depth needs LZFSE (`pip install pyliblzfse`).

## Tasks

`sweep` 351 clips (1.27 h) · `fold_laundry` 290 clips (2.62 h) ·
`pick_and_place` 230 clips (0.89 h) · `scoop_grain` 212 clips (1.39 h) ·
`jar_open_close` 139 clips (0.83 h) · `wash_dishes` 107 clips (2.28 h) ·
`plug_charger` 68 clips (0.24 h) · `tie_shoelaces` 63 clips (0.30 h) ·
`pour_liquid` 28 clips (0.25 h) · `wipe_surface` 25 clips (0.21 h)

Recorded by 4 adults, each wearing a chest-mounted iPhone. The
`participant_id` column in `index.csv` groups clips by wearer.

## Devices and capture conditions

| device | clips | median depth conf | frame rates present |
|---|---:|---:|---|
| iPhone 12 Pro | 867 | 87.8% | 15 fps (514), 30 fps (323), 60 fps (13), plus 17 at irregular rates |
| iPhone 17 Pro | 646 | 69.2% | 60 fps (646) |

Clip length: min 3.4 s · median 16.3 s · max 181.9 s.

## Identifiers

| id | example | meaning | stable? |
|---|---|---|---|
| `clip_id` | `EM1-0254` | the clip. Assigned once in capture order | **permanent** |
| `episode_id` | `EM1-D2-E06` | the continuous recording sitting it belongs to (dataset, shoot day, episode within that day) | grouping only |

Split on `episode_id`, `shoot_day`, or `participant_id` rather than on clips.
Clips from one sitting are correlated: they share participants, objects, and
capture conditions.

## Using it

```python
import json, zipfile
import numpy as np, liblzfse          # pip install pyliblzfse
from huggingface_hub import hf_hub_download

p = hf_hub_download("CaryxAI/everyday-manipulation-3d-raw", "clips/D2/EM1-0254.r3d", repo_type="dataset")
z = zipfile.ZipFile(p)
meta = json.loads(z.read("metadata"))

K      = np.array(meta["K"], dtype=np.float32).reshape(3, 3).T   # column-major!
poses  = np.array(meta["poses"], dtype=np.float32)               # (N,7) qx qy qz qw tx ty tz
stamps = np.array(meta["frameTimestamps"], dtype=np.float64)

raw   = liblzfse.decompress(z.read("rgbd/0.depth"))
depth = np.frombuffer(raw, dtype=np.float32).reshape(meta["dh"], meta["dw"])  # metres
conf  = np.frombuffer(liblzfse.decompress(z.read("rgbd/0.conf")), dtype=np.uint8
                      ).reshape(meta["dh"], meta["dw"])
```

`index.csv` carries one row per clip with task, participant, episode, duration,
frame rate, depth confidence, detected objects, and a description. Use it to
select a subset before downloading anything.

## Honest limitations

Read this section before you trust a column.

**The semantic columns are machine-generated and unreviewed.** `task`,
`task_phrase`, `primary_objects`, `secondary_objects`, `environment`,
`hands_visible`, `lighting`, and `description` all come from a vision-language
model and have not been checked by a person. Treat them as a searchable first
pass rather than ground truth. `label_source=vlm` marks every row.

**Use the `fps` column, not the `fps` field inside the bundle.** Record3D stamps
the *configured* rate into `metadata`, and an iPhone 12 Pro will stamp 60 while
actually delivering a hard-capped 30. We resolve the true rate from
`frameTimestamps` and publish it in `index.csv`, so the column is correct even
where the bundle's own stamp is not. If you parse `metadata["fps"]` yourself you
get the stamp. On the iPhone 12 Pro clips the stamp is very often exactly double
the achieved rate (verified on 532 of 867). **Frame rate also varies per clip, so
read it per clip and never assume a corpus-wide constant.**

**Depth confidence is device-relative.** The 12 Pro and 17 Pro report
substantially different high-confidence fractions on visually similar scenes, so
`depth_conf_high` compares clips *within* a device, not across devices. It is
not a scene-quality score.

## Privacy and consent

All 4 participants are project contributors who consented to the
recording and to open release. Capture was in private homes.
Audio is removed from every published clip.

Every clip in which the automated pass detected a visible face, another person,
or a screen or document was then reviewed by a person. 6 clips were withheld
from this release as a result; the rest were cleared and are included.

## Annotations

This drop has no annotations. A densely annotated sample built on these same
clips, keyed by the same `clip_id`, is published separately at
[CaryxAI/everyday-manipulation-3d](https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d).

That sample aims to be the most densely annotated egocentric manipulation data
available. Every frame carries metric depth, 6-DoF camera pose, MANO hand pose,
per-hand object contact, hand and object segmentation, and time-aligned
language, so a model can be tested against any one of those channels or all of
them at once without collecting or labelling anything first. It is packaged as a
single multi-episode [LeRobot v3.0](https://github.com/huggingface/lerobot)
dataset.

Want this corpus annotated, or a larger volume captured to spec? Reach out to
[founders@caryx.ai](mailto:founders@caryx.ai).

## Licence

**CC-BY-4.0.** Commercial use permitted with attribution. Full terms in
`LICENSE`.

## Citation

```bibtex
@misc{em1_2026,
  title        = {Everyday Manipulation 3D (raw RGB-D)},
  author       = {CaryX AI},
  year         = {2026},
  publisher    = {CaryX AI},
  howpublished = {\url{https://caryx.ai}},
  url          = {https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw},
  note         = {Dataset. Available at \url{https://caryx.ai/data}}
}
```

---

**Built by CaryX AI.** We record everyday human manipulation and turn it into
densely annotated, machine readable episodes for physical AI.

**[Browse the annotated episodes in your browser →](https://caryx.ai/data)** ·
[caryx.ai](https://caryx.ai) · Reach out
[founders@caryx.ai](mailto:founders@caryx.ai)
