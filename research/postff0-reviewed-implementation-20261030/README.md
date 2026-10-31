# Reviewed implementation layers carried over the published compile repair

Base: `ff0f50df695bfa48fd72697858c574fda653dc4e` (tree `8fc522d3d5f15c6d71417f4d160c6a8441a94302`). This packet explicitly composes the previously reviewed NEXT40, J0117 and THIRD45 layers; it does not overwrite the published beacon Boolean repair with their older NavigationModel image.

The current NavigationModel is the frozen combined source plus exactly the reviewed two return corrections: hazard rejection returns `false`, and admission returns the actual existing Feedback sink result. No optional-beacon policy, freshness gate, native deadline or fixture assertion changes. The published Boolean regression control remains unchanged and runs against actual current source.

## Current versus historical identities

The new `published-beacon-repair-carry.patch` reverses only NavigationModel and the current bench manifest to their exact frozen combined identities. The original THIRD, J01 and NEXT patches then reverse unchanged to the failed119 source. In an independent temporary directory, the unchanged original published `beacon-bool-compile-repair.patch` is applied forward and must reproduce the exact ff0 NavigationModel, bench manifest and regression-test hashes recorded by its unchanged published checkpoint; reversing it must recover the failed119 preimages and remove the new control. The main historical chain remains unchanged. Historical restoration is never substituted for actual current behavior checks.

All original reviewed layer manifests remain immutable historical records. `CHECKPOINT_FILES.json` in this directory identifies this current composition and its actual ff0 preimages. The published microfix README/checkpoint, original repair patch and regression file remain byte-identical base files, not silently republished replacements.

## Scope and evidence

- Portable integration: 855 source checks, 400 integrated pins and 375 bench-input pins. These are source/provenance controls, not Apple execution.
- Canonical project and existing 81/82 app linkage, exact 26 selected seated/collision/normal-owner fixtures, 71 classified fixtures, owned ingress teardown, local-reference/photo/voice controls, and the reviewed same-job actual-model lane are retained from the reviewed layers.
- The actual-model lane still selects only the original three SC02 scripts. The source adapter supports six scripts; this does not claim six scripts executed. Model unavailable, failed, skipped or incomplete remains visible and cannot become an observation pass.
- Normal-owner full-anchor copies remain diagnostic-flag plus explicit-enable only, after urgent processing. The separately admitted seated owner has its own capture lifecycle. Neither path establishes physical guidance authority.
- Actual119 remains failed: the default, diagnostics and focused accessibility builds failed on the Boolean callback; hosted UI/unit acceptance did not execute. macOS core was 1499 passed/1 skipped, memory 58 passed, classified 71 passed. No historical failed run is relabelled.
- This new combined source has not been compiled or executed on Apple. The ff0 repair run is separate evidence and cannot establish this later composition's runtime correctness.
- Push jobs retain public-repository guards, standard `xcode-27`, default-off artifact uploads, and no paid runner, cache, service or private capture. No native execution or publication was performed while preparing this packet.
