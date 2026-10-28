# Frozen OctoMap endpoint geometry comparison extension

Prepared 2026-10-28 18:42 UTC, before native occupancy replay or its scores. The existing common-surface-proposal protocol and evaluator remain unchanged and pinned. This extension adds exactly one arm: native occupied obstacle plus native occupied ground reference endpoints from the fixed-grid OctoMap run. No free cells or unknown cells enter this geometry score. Ground labels do not prove supporting floor.

The comparator is byte-identical to the reviewed prior comparator except its repository-root directory resolution. The cloud-only decoder is byte-identical except repository-root resolution and expected point-count lookup from the native endpoint receipt; it retains the same released Open3D reader, exact three-point zero-face/camera fixture, no filtering, and pinned module hashes. Launch pins the completed PLY and native count receipt before scoring.

All numerical rules remain unchanged: original author phone→FARO similarity once, no refitting, 4cm FARO-grid actual-point representative nearest centre with lexicographic tie break, unchanged FARO triangle locator forward unsigned distances, identical 29-held-out-view reference points with reverse nearest-output-point distances. All scheduled points included; no score-driven threshold or sample change. Reference sample hash/count must equal the prior completed comparison; independently check this after execution.

This is an occupancy-filtered and natively segmented geometry proxy, unlike raw sensor cloud and mesh-derived sample outputs. Report density and coverage differences. Do not infer navigation accuracy, false-clear rate, hazard recall, clearance or physical safety from either metric. Missing reference rays remain missing, never free.

Execution belongs to the primary worker only after native fixtures and the frozen 265-grid replay succeed. One CPU, sampled process-tree RSS cap 3GiB, within existing aggregate 1.5GiB download/6GiB disk and 19:08:24 UTC deadline. If insufficient time/resources, defer scoring and keep the frozen protocol; do not reduce sampling or alter metrics. Retain failures.

Invocation: make_launch.py --out <fresh launch.json>, then compare.py --inputs <launch.json> --out <fresh output folder> --expected-freeze <FROZEN.json SHA256>, through existing external resource supervisor and existing VTK Python environment. Prior common-comparison outcomes are not recomputed and are not silently relabelled as same-representation evidence.
