"""Reproduce a real scan inspection. Not a depth-camera or lighting simulation.
Run: uv run --with numpy==2.2.6 --with plyfile==1.1.5 --with matplotlib==3.10.9 python tools/real_scene.py
"""
import hashlib
import json
from pathlib import Path
import urllib.request

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
import numpy as np
from plyfile import PlyData

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "real-scene"
URL = "https://graphics.stanford.edu/projects/3dlite/data/apt/apt-initial.ply"
SHA = "0eb82b4fc04ed1d8244689b67522904db84fc325f49282aaa3b84dc61b70428f"
OUT.mkdir(parents=True, exist_ok=True)
path = OUT / "apt-initial.ply"
if not path.exists():
    # Verify before promoting a partial download into the reusable fixture.
    temporary = OUT / "apt-initial.download"
    urllib.request.urlretrieve(URL, temporary)
    if hashlib.sha256(temporary.read_bytes()).hexdigest() != SHA:
        raise ValueError("Scan checksum mismatch")
    temporary.replace(path)
if hashlib.sha256(path.read_bytes()).hexdigest() != SHA:
    raise ValueError("Scan checksum mismatch")
p = PlyData.read(path, known_list_len={"face": {"vertex_indices": 3}})
v = p["vertex"]
xyz = np.column_stack([v[a] for a in "xyz"])
faces = p["face"]["vertex_indices"]
assert np.isfinite(xyz).all()
assert faces.min() >= 0 and faces.max() < len(xyz)
colors = np.column_stack([v[a] for a in ("red", "green", "blue")]) / 255.0

# Dataset-specific Z-up convention, inspected from this initial reconstruction.
# This is a reproducible approximate floor fit, not ground truth or a live pose.
low = xyz[(xyz[:, 2] >= 0) & (xyz[:, 2] < 0.2), 2]
hist, bins = np.histogram(low, bins=np.arange(0, 0.201, 0.02))
peak = int(np.argmax(hist))
floor = float(np.median(low[(low >= bins[peak]) & (low < bins[peak+1])]))
resolution = 0.1
origin = np.floor(xyz[:, :2].min(axis=0) / resolution) * resolution
width, depth = (np.floor((xyz[:, :2].max(axis=0)-origin) / resolution).astype(int)+1).tolist()
indices = np.floor((xyz[:, :2]-origin) / resolution).astype(int)
flat = indices[:, 1] * width + indices[:, 0]
support_mask = np.abs(xyz[:, 2]-floor) < 0.04
body_mask = (xyz[:, 2] > floor+0.09) & (xyz[:, 2] < floor+1.95)
support_count = np.bincount(flat[support_mask], minlength=width*depth)
body_count = np.bincount(flat[body_mask], minlength=width*depth)
supported = support_count >= 8
blocked = body_count > 0  # no removal of isolated obstacle points for this inspection
cells = [{"floor": floor if supported[i] else None, "clearance": None,
          "blocked": bool(blocked[i])} for i in range(width*depth)]
# A surface mesh has no free-space rays. Do NOT turn absence of a mesh vertex into clearance.
surface = {"level": "scan", "origin": {"x": float(origin[0]), "y": 0, "z": float(origin[1])},
           "resolution": resolution, "width": width, "depth": depth, "cells": cells}
(OUT / "surface.json").write_text(json.dumps(surface, separators=(",", ":")), encoding="utf-8")
source = {"title": "3DLite apartment initial RGB-D reconstruction", "url": URL,
          "sourcePage": "https://graphics.stanford.edu/projects/3dlite/index.html",
          "authors": ["Jingwei Huang", "Angela Dai", "Leonidas Guibas", "Matthias Niessner"],
          "license": "CC BY-NC-SA 4.0", "licenseURL": "https://creativecommons.org/licenses/by-nc-sa/4.0/",
          "sha256": SHA, "bytes": path.stat().st_size}
(OUT / "source.json").write_text(json.dumps(source, indent=2), encoding="utf-8")
report = {"source": source, "vertices": len(xyz), "triangles": len(faces),
          "boundsXYZ": [xyz.min(axis=0).tolist(), xyz.max(axis=0).tolist()],
          "estimatedFloorZ": floor, "gridResolutionMetres": resolution,
          "cells": len(cells), "observedFloorCells": int(supported.sum()),
          "obstacleCells": int(blocked.sum()), "unknownFloorCells": int((~supported).sum()),
          "verifiedFreeSpaceCells": 0, "liveSensorTest": False,
          "limitations": ["Real reconstructed geometry; no stair ground-truth labels.",
                          "No recorded camera pose, sunlight, darkness, sensor noise or timing replay.",
                          "Floor fit and occupancy bands are approximate offline analysis.",
                          "No free-space ray evidence: all clearance values remain unknown."]}
(OUT / "inspection.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

fig = plt.figure(figsize=(14, 7), layout="constrained")
ax = fig.add_subplot(1, 2, 1, projection="3d")
visible = np.flatnonzero(xyz[:, 2] < 2.15)[::8]
ax.scatter(*xyz[visible].T, c=colors[visible], s=0.5, rasterized=True)
ax.set(xlabel="X (m)", ylabel="Y (m)", zlabel="Height Z (m)", title="Real apartment scan — ceiling hidden for inspection")
ax.set_box_aspect((6.2, 9, 2.5)); ax.view_init(elev=48, azim=-65)
grid = np.zeros(width*depth, dtype=np.uint8)
grid[supported] = 1; grid[blocked] = 2
ax2 = fig.add_subplot(1, 2, 2)
ax2.imshow(grid.reshape(depth, width), origin="lower", interpolation="nearest",
           extent=(origin[0], origin[0]+width*resolution, origin[1], origin[1]+depth*resolution),
           cmap=ListedColormap(["#b8c1c8", "#59ad91", "#9c4654"]), vmin=0, vmax=2)
ax2.set(xlabel="X (m)", ylabel="Y (m)", title="10 cm inspection grid — NOT a navigable route map")
from matplotlib.patches import Patch
ax2.legend(handles=[Patch(color="#b8c1c8", label="Unknown floor"),
                    Patch(color="#59ad91", label="Observed floor; clearance unknown"),
                    Patch(color="#9c4654", label="Reconstructed obstacle")], loc="upper right", fontsize=8)
fig.suptitle("3DLite / Stanford & TUM • Initial reconstruction, not scene completion", fontsize=15)
fig.text(0.02, -0.015, "Huang, Dai, Guibas & Niessner (2017). Data and this derived preview: CC BY-NC-SA 4.0. No invented room labels.", fontsize=9)
fig.savefig(OUT / "scan-preview.png", dpi=150, bbox_inches="tight")
print(json.dumps(report, indent=2))
