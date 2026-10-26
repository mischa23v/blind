# Fixed derivational display protocol

Use only the eight already saved scheduled-ray NPZ artifacts and COMPARISON_RESULTS.json from the completed stage-06 comparison. No mesh load, VTK, raycast, registration fit, depth image decode, new sampling, detector or navigation call. Check the result and all NPZ hashes before and after. Original RGB files are separately copied byte-for-byte after verification against the original selected-extraction receipt; they are not composited into or transformed for the analytical panels.

Exactly frame IDs 1, 5, 9, 13, 17, 21, 25, 29; exactly eight 2×3 analytical panels. Display each saved 249×185 scheduled-sample grid (stride four), not an invented full-resolution depth map. Use nearest-neighbour rendering, no smoothing/interpolation/inpainting or hole filling. Invalid/no-reference pixels remain visibly masked.

Fixed panels and ranges: saved original processed axial depth [.15,8] nominal metres; registered reference axial depth [.15,8]; signed sensor-minus-reference discrepancy [-1,+1]; absolute discrepancy [0,1]; four-way stored availability; stored fixed reference-edge categories. Every continuous panel shows masked and display-clipped counts. These display limits do not filter, refit or change the frozen numerical metrics. Availability and edge enums must be confirmed against the comparison producer and cross-checked against saved counts before drawing.

Labels must state nominal registered units, unavailable original confidence/tracking, and no hazard/physical-accuracy result. Reference surfaces include author-completed/reconstructed geometry; an absent reference intersection is not automatically a sensor failure. Correlated pixels are not independent obstacle events. RGB remains untouched original processed-capture imagery, separate from analytic plots.

Budget: 30 CPU seconds, 45 wall seconds, 256 MiB observed peak RSS. All stage-06 files combined must remain ≤64 MiB, with ≥768 MiB free. A sampled watchdog stops on violation, retains partial output and does not increase limits. No network, install or external publication. Each image, source and input hash is recorded. Display generation is not a rerun of the comparison.
