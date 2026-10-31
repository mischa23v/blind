# Existing N00/N02/N04 navigation integration — source checkpoint

This source batch connects existing layers, without creating a replacement planner/SLAM system or turning unvalidated measurements into guidance. Tracker IDs refer to the reconciliation tracker. **Implementation checkpoint, not completed navigation acceptance.** Existing Apple failures and device/O&M gates remain open.

## Implemented source slices

- **N00 / R09–R15:** explicit helper opt-in restores the selected destination’s actual paired local world into the same exclusive diagnostic ARSession. Protected local ownership, paired hashes, saved origin, fresh tracking/mapping callbacks and original camera/source identities gate the actual mapped native request and audit. Unpaired/imported/unregistered/reset sessions never receive identity alignment from names, GPS or equal coordinates. See [same-owner details](SAME_OWNER_RECOVERY.md).
- **N02:** the existing saved-world recovery gate now has this real diagnostic producer/consumer hookup. This does **not** supply measured camera-to-body calibration, live position/yaw uncertainty or full-footprint support. The production physical issuer still withholds. Positive Apple archive decode/configuration/relocalization remains unexecuted.
- **N04:** existing route-owner off-route/blocked-leg errors now retire the itinerary/output and require a fresh uniquely supported authored endpoint before the existing planner replans. Existing portal source acceptance now requests the target localization context/session, never a pose or crossing claim. Return/history and restrictions remain with existing owners. See [route details](ROUTE_REASSOCIATION.md).
- **N03 contract:** preserve the active-camera hazard worker’s actual output veto; observing is not clearance or support. N04’s runtime source is based on that slice. Diagnostic camera mode still warns that phone hazard monitoring is unavailable and must not be used for walking.

## Evidence and adoption

Actual base is `79951a34966f0881cd942fc27c833e020aacde2b`, followed by the reviewed map17 layer. No later map commit is asserted by this packet. Ordered source composition is N03 active-hazard → N00 same-owner → N04 route-reassociation. The strict classified71 CI companion is independently checked (manifest `3c72acb24029f539d1aff8483c989e6ac13b3a2339c417f6bda9313477a5035c`,62 portable parser tests passed). The parent must merge this three-file companion and refresh current-source provenance before publication; historical manifests/results must remain unchanged.

Two isolated patches independently reviewed: N00 manifest `634aa56e03b0f13b747329d2770fa025a781e048bf81b2441b212a757a9771e6` (8 source files), N04 `62255fc6cf7fa462ed75557fd2cc27958a0a6be712c1789e720a7b84aff41d47` (3 source files). Portable source controls22+13 and exact ordered forward/reverse composition passed; these are not Swift behavior tests. Independent review is recorded in [CHECKPOINT.json](CHECKPOINT.json).

Six recovery fixtures appended to the existing expected-source XCTest suite make classified71; all original65 identities remain. Seated21 identities remain, extending actual-consumer tests with malformed archive and held-loader deletion/goal/cancel cases. Three ordinary ConnectedJourneyRuntime fixtures exercise off-route replan, target-context waiting, old-session rejection and restart. **No new Swift/native cases were compiled or executed for this checkpoint.** The held-loader tests deliberately return a decoder failure; they do not forge positive archive restoration.

Remaining prerequisites are measured localization/body/heading error, calibrated current support, current full-body obstacle evidence, actual destination-map relocalization, complete end-to-end journeys, native and device execution, and supervised/O&M acceptance. Target context is not current floor identity; endpoint associations are not observed portal traversal. These tasks remain open rather than being marked complete by source review.
