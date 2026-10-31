# RTAB checkpoint18:11UTC

Official RTAB0.24.2 built from pinned source with verified Debian packages unpacked locally. No raw images,depth archives,reference geometry,dependencies or binaries included. Eight native input/projection fixtures passed. Both full released Rtabmap::process runs accepted265frames and exported graph/grid records. Fixed pose roundtrip assertions passed. Both cloud exports failed: adapter omitted valid indices when calling native voxelize on non-dense organized depth clouds. Upstream explicitly returns empty for that API usage. This is an adapter bug, NOT empty-room geometry or a navigation result. Failed runs preserved. Export-only repair using native valid indices is being compiled; no accuracy measurements yet.

Research build includes bundled TORO (CC BY-NC-SA); no app redistribution approval implied. Native Grid/RayTracing defaultfalse, noOctoMap compiled. Thus no3Dfree-space clearing claim. Full parameter dumps retained.
