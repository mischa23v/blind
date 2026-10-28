# Collision oracle Swift type-check repair

Native run 40674598074 at 4182e995 passed both app builds but failed hosted/UI test compilation at SavedRoomRouteCollisionOracle.swift:209. The map/SIMD expression exceeded the compiler type-check budget. Zero route cases and zero journey stages executed.

The same column-major conversion now uses four explicitly typed Float values per column and three explicitly typed rotation columns. Bounds, matrix validation, numerical tolerance, physics shapes/margins, contacts and all test assertions are unchanged. This is a compiler-oriented expression decomposition, not a changed collision model. Native compilation remains pending. The original source is retained beside this note.
