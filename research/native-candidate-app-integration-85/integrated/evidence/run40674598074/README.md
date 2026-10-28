# Apple path diagnostic run40674598074 — test compilation blocked

Exact4182e995 source. Both app compile modes pass; Core1434/1skip/0fail, Memory58/0fail. Hosted and UI targets fail compiling SavedRoomRouteCollisionOracle.swift:209 (expression cannot be type-checked in reasonable time). Both result bundles contain zero executed tests.

No Apple export/ModelIO/Recast/SceneKit route case or journey stage ran. This provides no path feasibility or collision verdict and cannot validate report collection. Fix the compiler expression before interpreting geometry. No rerun, new workflow, runtime activation or artifact download.
