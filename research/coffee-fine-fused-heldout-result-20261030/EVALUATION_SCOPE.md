# Evaluation-use clarification

Added 2026-10-30. The published README, numerical results, frozen source protocols and existing pins remain unchanged.

Frames **232 and 370 were withheld from map construction**: the compared maps were built only from the fixed original frames **290, 357 and 391**. However, frames 232 and 370 and their results had already been inspected during the preceding diagnosis. They are therefore **development evaluation views**, not an untouched final model-selection holdout.

The fixed fine-versus-coarse experiment is an **iterative development comparison**. Exact coarse reproduction and common-pixel/lost-hit accounting make that comparison informative, but do not undo prior exposure to these evaluation views. The result is not independent safety validation, evidence of generalization to unseen rooms, a production-resolution selection or a physical-clearance guarantee.

A final model-selection/generalization claim requires a separately designated evaluation set not used to diagnose or select the compared system, with its protocol fixed before inspecting the outcomes. Physical navigation, fresh hazards, support and device behavior require their own validation; even untouched offline views would not establish those properties alone.
