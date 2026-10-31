# Actual saved Coffee path diagnostic

Unchanged real 0→8 path, six original XYZ vertices, five segments. At zero-based segment 4, the centerline intersects the predeclared north manual diagnostic exclusion for **0.7166625376272356 m**. GEOS distance is 0; the preserved body's enclosing radius .2704163456597992 m plus separate .15 m margin therefore contacts that exclusion. No other segment/window pair contacts at the .42041634565979924 m threshold plus 1e-8 guard.

This is a real saved polyline checked against explicitly manual diagnostic windows, **not measured table contact or proof of physical clearance**. Full floor/body/head coverage/current localization remains unknown. No geometry, original query, path, profile or scene was changed; no detour generated or native/3D engine run. Original 20 accepted paths stay unchanged. `RESULT.json` contains all segment distances, exact replay points, provenance and unknown physical status; `INPUT_FREEZE.json` binds the two published input sources.

Actual diagnostic passed in 0.0073 wall seconds with source hashes unchanged. One bounded Python process, 10 CPU seconds / 20 wall / 512 MiB. Attempt 001 was a pre-geometry input-preparation path failure retained separately; attempt 002 used identical checker source with corrected preparation root.
