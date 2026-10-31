# Targeted table-representation issue: original source lacks broad mid-height faces in two diagnostic regions

## Finding

The first plot's centroid filter and draw ordering are **not sufficient to explain the missing broad mid-height surfaces** in the two checked neighborhoods. The full unchanged original OBJ—not the plotted subset—contains zero triangles satisfying BOTH:

1. triangle XZ bounding box overlaps the declared diagnostic window; and
2. any part of its vertex-Y range intersects candidatefloor+0.45…1.10.

This conservative bbox/range test would retain a large tabletop triangle spanning a window even if its centroid lay elsewhere. It found0of875 XZ-overlapping triangles in the south window and0of1,019 in the north window. Faces at floor/low patches and ceiling remain; the windows are not empty of all geometry. Low overlapping triangles reach0.212m(south) and0.305m(north) above the candidate floor. We do not label these patches measured table legs based on height alone.

Windows chosen from the first source plot's small-patch neighborhoods, before this test:
- south: X[−0.8,0.9],Z[−1.8,−0.7]
- north: X[−0.8,0.9],Z[1.4,2.5]

These are **debug regions**, not measured physical tabletop boundaries. Heights rely on the unchanged historical candidateY-up/floor convention; no new scale/gravity calibration was performed.

## Correspondence confidence

The actual dataset photographs show large light-colored oval tables. The original MTL names the recovered original texture; source OBJ UV coordinates permit an approximate textured mesh projection without inventing camera registration. That projection shows the surrounding red/orange and blue-green sofa geometry and small low patches in those regions, but no broad tabletop surfaces. This supports a specific source-representation concern rather than a pure grayscale visualization artifact.

Semantic association is plausible from surrounding source-textured furniture layout, **not metrically verified camera-to-mesh correspondence**. Mean-UV samples are a debug coloring, not an accurate photorealistic renderer; atlas inspection and the original photograph cannot by themselves establish exact source tabletop footprints, height or collision points. No photo transform, tabletop coordinates or replacement geometry was invented.

## Consequence for current path claims

Current longest accepted0→8 crosses the north diagnostic window for0.716663 source metres, segment4 from approximatelyXZ(0.285494,1.4) to(0.9,1.768765). It does not cross the south window. This is a saved-polyline/window arithmetic check, not a new route query or body collision result.

Therefore **missing source tabletop geometry could allow apparently clear native paths**. This does not yet prove that the selected path physically intersects an actual table; that requires source correspondence and an observed table envelope. Recast reproducing20 accepted paths is an integration result, not evidence that all obstacles were captured. Swept-body checks against this same incomplete mesh can also miss an absent tabletop.

Keep the inside-room route and source-triangle collision work, but explicitly retain this missing-representation issue. Next evidence should establish the table geometry from independently registered source depth/held-out observations or an appropriate registered reference mesh, preserving reference-processing/coverage uncertainty. Do not paint guessed tabletop obstacles into the planner or delete them to improve outcomes. More generic scene galleries are unnecessary; any images are now for this concrete path/representation issue.

## Execution and artifacts

`table_issue.py` checked all87,370triangles and produced `TABLE_REPRESENTATION_RESULT.json` plus `coffee-table-representation-debug.png`, which was inspected. Inputs are hash-bound and unchanged;15.76seconds,305,976KiB peakRSS under30second/512MiB limits. Original MTL uses `map_Kd textured_0_qHRMGgqy.jpg`; texture8192×2272. Matplotlib emitted a nonfatal slow-auto-legend warning; the figure completed. `TABLE_WINDOW_FOLLOWUP.json` retains additional low-height/window-intersection arithmetic. No native route, reconstruction or collision run; no altered geometry; internal images not staged for Git.
