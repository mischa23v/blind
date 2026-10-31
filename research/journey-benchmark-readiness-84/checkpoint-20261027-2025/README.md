# Separate saved-pose diagnostic, 2026-10-27 20:25 UTC

After episode19 finished and before20 started, one bounded serial process queried the unchanged full reference mesh at the exact saved rejected poses for16/17/18. No actor replay, floor refit, cache expansion, threshold change or episode-result change occurred. Runtime was16.27wall seconds/15.97sampledCPU seconds, peak sampledRSS2.11GB, within existing180CPU/240wall/3.5GiB caps.

Episodes16 and18 each have exactly one missing ray, both inside the frozen corridor envelope: XZ(-3.385696148,-1.905184910) and(-3.385174794,-1.908788427). These locations are approximately3.64mm apart. Their rays query the original reference mesh over absolute modelY[-0.25,+0.15]m and return no intersection. This is not a support-cache boundary miss. A mesh hole or query/window/registration limitation is still possible; it is not proof of an actual drop.

Episode17 has all nine hits. One body-corner ray hits original face10030019 atY+0.033955956m; its triangle vertices spanY+0.033311824..+0.037292191m. The entire triangle lies inside the frozen evaluation bounds but is outside the frozen ground IDs. The evidence establishes raised reference geometry/classification conflict, not its identity as carpet, toy or noise.

Episode19, the same pair with synthetic tracking interruption, arrived after6.343836m/625ticks. Pair3 therefore has three support stops, one arrival and one interrupted/unknown nominal run, not universal physical blockage. Through20 scheduled outcomes:15 arrivals,3 support stops,2 interruptions with unknown outcomes. Episode20 then resumed unchanged.

This is evaluator-only diagnosis. The reference-world veto, supplied poses, zero-margin body, unmeasured ground contacts and all prior limits remain. No physical or child-safety claim follows. The included scripts require the frozen evaluator directory and are saved as provenance, not standalone reproducibility bundles.
