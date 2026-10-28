# Bounded ingress timing extraction and callback harness repair

The b1 native hosted run failed seven classification-ingress tests by timeout. Its raw job log did not include the newly authored ingress marker because the CI helper exported only the older runtime stage marker. This is an evidence gap, not proof of a runtime cause.

The reviewed test callbacks now only store the result and fulfill the expectation; terminal discard callbacks only fulfill. Timing snapshots run after waiting and are labelled `waitFinished`, which does not assert completion when a wait timed out. Deadlines, real runtime and assertions are unchanged.

The helper adds an anchored whitelist for synthetic diagnostic UUIDs, submitted/waitFinished event names, numeric elapsed time, Boolean thread flag and existing closed runtime stage names. It retains at most 80 lines and 1800 characters per line. It runs on success and failure and does not modify the test exit status. No image, mesh, app-container, source/session identifier or arbitrary error text is exported.

`test_marker.py` executes the actual shell extraction with accepted and rejected synthetic mutations and both bounds. Five tests pass normally and with Python optimization. `REVIEW.json` records source checks, not native success. The separate reversible stage85 patch restores the exact b1 helper before older historical proof layers; historical manifests remain unchanged.
