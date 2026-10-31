# Saved-room camera diagnostic overlay — candidate increment

Follows durable recording checkpoint `efdc2c1952bfce22b5eb5543aaf931a8db32eda5`.
Source implementation, not native/device validation or a walking trial.

## What it adds

The existing AR callback can pass its exact `SavedWorldFrameCameraAssociation` receipt to the existing deferred pose-only recorder. No second capture, new AR session, live-output lease, identity transform or LLM is introduced. The receipt travels with that offered frame through the existing session/generation/continuity/recording-ID fences. Missing or mismatched receipt retains an ordinary unassociated sample; a retired asynchronous sample remains rejected under the existing continuity rules.

Core accepts same-frame provenance only for the exact observation ID, ARKit producer, session, canonical source frame, capture **and pose** timestamp, normal tracking and valid full saved-world descriptor. A receipt is issued by the existing restored-world recovery gate; this new adapter does not itself measure localization accuracy. Recorded coordinates remain the original camera position and transform. `Entry.cameraInMap` and `Plan.Alignment` are unchanged. Imported Koivu route-map coordinates acquire no association.

The new inert `SameFrameAssociation` contains schema version 1, exact observation/session/source-frame/capture, recovery epoch and full `SavedWorldFrame` (including both room/world-map hashes and origin identity). It cannot be used as a live recovery receipt and declares no physical guidance authority. Reading JSON is structural validation, not authentication of a live capture or proof of physical accuracy.

## Archive compatibility and bounds

A new typed `.associatedSample(entry, metadata)` event replaces the ordinary `.sample(entry)` **only for that newly admitted sample with a matching receipt**. Entry and metadata commit atomically as one opaque SQL payload. No later association is attached to already committed samples. Old raw `.sample` events remain readable and remain unassociated. Older app versions do not understand the new case and reject it rather than silently stripping its provenance. Unknown event cases and unsupported metadata schema versions reject rather than being reinterpreted. The SQL schema and 3,257 total-event / 3,000-sample limits do not change. Existing per-event, per-session, total-byte and transaction bounds still apply.

Committed-prefix recovery either contains the complete associated event or none of it. Incomplete historical sessions restore stopped with no invented actual stop time. Geometry is not duplicated into route-event payloads; the exact local saved-room artifact must still exist and match its descriptor to render. Deleting/changing the artifact does not delete the raw diagnostic trace and must not substitute another room.

## Drawing, not navigation

The view projects the original saved room's walls, openings, doors and furniture plus same-frame raw camera trace onto a two-dimensional top-down canvas. Original full transforms, dimensions and heights remain in the geometry provider/local artifact. This is **not** an interactive 3D simulation, collision result, current obstacle map, body envelope, floor-support test or clearance check. Furniture can have moved. The camera line's uncertainty is unmeasured.

The plot uses only the exact latest associated saved-world descriptor. It breaks lines across missing association, tracking/sample boundary, source-session change, recovery epoch change and time gap; it never fills gaps or snaps to a path. Planned route overlays remain separate unless independently supplied measured registration already exists. Original sample positions and event order remain available for diagnosis.

## Authored validation

New Core fixtures cover exact atomic event roundtrip, historical stopped/non-authority, no-association prefix, duplicate rejection, old raw archive compatibility, mismatched frame/capture retained as raw, future metadata version/corrupt capture/corrupt observation ID, positive continuous samples and missing-receipt/recovery-epoch boundaries.

New hosted Store fixtures cover receipt propagation through the real offer/persistence/reopen path and a deterministically blocked receipt-bearing extraction retired by tracking continuity loss. These use synthetic observations and descriptors, not a device or private user data. Existing late extraction/stop/restart and archive bounds tests remain relevant.

Native compilation, source-target membership of the new geometry provider, Swift/GRDB execution, background lifecycle, VoiceOver and real exact-room recovery/geometry alignment remain to be validated. No real person has been asked to walk based on this diagnostic.

## Bounded local check performed

The existing Python/SQLite schema contract was rerun unchanged: 9 checks passed, including diagnostic deletion cascade and payload/sequence/byte bounds. This executes SQLite schema statements only; it does **not** execute the Swift event decoder, GRDB integration or UI. All new Swift tests above are authored, not run in this Linux environment.
