# Original-room overlay run40661837550 — app compile blocked

Exact source `ac56c97861d23888c24f13d2482055f9302d5ea0`. Both default and diagnostics Simulator builds fail at PlaceStore.swift:88: mutating resource values on immutable `directory` URL.

Core **1,434 executed/1skip/0fail**, Memory **58/0fail**. Hosted/UI steps were skipped after the app build failure. The new native original-room provider, overlay, and association tests therefore did not execute. Package aggregate success is not native Apple fixture or physical room-registration acceptance.

Immutable failing-source hash and bounded excerpts retained. No rerun, new workflow, runtime activation or artifact download.
