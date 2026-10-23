# Family recognition source follow-on, 2026-10-23

This is source implementation plus portable regression evidence, not an Apple build,
phone accuracy result, authentication system, liveness proof, or child-use acceptance.
No model was replaced, downloaded or trained. No private images were uploaded.

## Implemented

- Reuses existing YuNet and the selected SFace/AuraFace model and thresholds.
- Enrollment still requires exactly one detected face. The new flow starts with an
  unnamed, consented draft, collects 3–6 examples, validates a unique name, and asks
  for the exact named save. Editing the name or examples invalidates save approval.
  Existing encrypted persistence, model-profile checks and deletion are unchanged.
- Recognition has a separate batch adapter. Each candidate uses its own row's five
  landmarks and aligned crop from the same upright source image, never another crop's
  coordinates. Candidate bounds use normalized top-left image coordinates, not body
  bearings. No name is attached to the separate anonymous body tracker.
- At most two embeddings per pass, with rotating spatial-order slots covering stable
  scenes of up to 32 detected faces. The adapter checks an 0.8-second budget between
  native operations; it cannot interrupt an in-flight OpenCV call. Over-capacity and
  unprocessed faces remain unrecognized. This does not guarantee every person is
  detected or every face is checked before that person moves away.
- A foreground active-camera consumer runs at most once per 0.75 seconds, one pass
  in flight. Existing calibrated portrait, three-seconds-stationary and camera-pose
  gates remain. Results expire at 1.5 seconds and are bound to capture, session,
  current gallery, model and operation generation. Late results are not published.
- Duplicate same-frame name assignments abstain. Names are never selected from the
  nearest/largest face, a guessed relationship or an old body track.
- Two fresh matches can propose one tentative social notice. A delivered/admitted
  notice latches once per person; there is no periodic repeat. Unknown results,
  occlusion and camera gaps do not reset it. Ten seconds of continuously observed
  empty view starts a new encounter. This is conservative event bookkeeping, not
  proof of identity continuity or a verified physical arrival.
- Leaving People discards unfinished enrollment but does not switch off an enabled
  camera session. Foreground camera activity is required; this code never starts a
  background camera. Enable consent explains automatic notices. Disable, gallery
  action, hazards, context loss and camera stop invalidate pending evidence.

## Coordinator-owned integration contract

1. In the foreground AR frame path, after familiarPeople.revalidate(model: self),
   call familiarPeople.consume(model: self).
2. Bind onArrivalHint to a short InformationCandidate of kind social through the
   existing deliverCandidate/attention gate. Use key familiar-arrival:<personID>,
   revision encounterID, createdAt capture.capturedAt, expiresAt capture.capturedAt
   + 1.5, category social and requested false. Recheck familiarCaptureIsCurrent.
   Suggested text: “I might see <label>.” No front/distance/follow/trust statement.
   Return whether admitted. Pass speechID: encounterID for cancellable speech.
3. Add Feedback.stopRequestedSpeech(id) that cancels only an active .requested(id)
   destination, never unrelated speech, hazards or mobility. Bind onCancelArrivalHint
   to it. Forward matching onRequestedSpeechFinished IDs to arrivalSpeechFinished.
   Controller independently cancels on evidence expiry or pose/context loss.
4. Regenerate/check the optional Xcode project with the SAME approved external
   model/framework paths. The default project still has no face model or feature.
   Do not copy this checkout's old NavigationModel/project over the coordinator's.

The notice latch currently means admitted, not fully heard. An interrupted notice is
not repeated automatically; this conservatively follows the once-only requirement.
Existing explicit “who is this” and finite named search remain single-face snapshot
workflows; the new automatic path is the multi-face path. No stale position is used
to answer a later “where” question.

## Portable checks run here

- 69 Familiar* BlindCore tests passed on Linux Swift 6.4.1, including 10 new encounter,
  duplicate-name and bounds cases. These are synthetic policy tests, not recognition.
- 28 Node source/integration contracts passed (familiar-people, auraface-backend,
  attention-routing).
- The production C++ slot scheduler compiled with g++ -std=c++17 -Wall -Wextra
  -Werror; its test passed for 1–32 faces, wraparound, negative/large cursors, per-pass
  uniqueness, and rejection of empty/over-capacity scenes.
- Changed Swift controller and view pass swiftc -parse with BLIND_FAMILIAR_PEOPLE.
- git diff --check passed for the packet.

Reproduce from this checkout (Swift toolchain/cache paths are environment-specific):

    swift test --package-path BlindCore --scratch-path /tmp/blind-family-build --jobs 2 --filter Familiar
    node --test tools/test/familiar-people.test.mjs tools/test/auraface-backend.test.mjs tools/test/attention-routing.test.mjs
    g++ -std=c++17 -Wall -Wextra -Werror tools/face-evaluation/batch_schedule_test.cpp -o /tmp/face-slots && /tmp/face-slots
    swiftc -parse -D BLIND_FAMILIAR_PEOPLE ios/BlindAssist/FamiliarFaceExperiment.swift ios/BlindAssist/FamiliarPeopleView.swift

## Required Mac/iPhone acceptance

Build/typecheck/link the Objective-C++ bridge and Swift app; parsing is not an Apple
build. Test real portrait orientation, per-row alignment and score parity; two known
adults, known plus unknown, similar-looking adults, crossing/reordered detections,
blur, clipped/partial faces, more than two faces, detector misses and photos/screens.
Measure latency, thermal/memory cost and starvation on BOTH intended backends. Keep
the conservative gates if they cause abstention; do not lower thresholds to make a
demo work. Test encrypted save/relaunch/unlock/delete, consent cancellation, wrong or
mixed enrollment examples, Photos picker interruption, camera permission denial,
screen exit, background, turn, hazard interruption and VoiceOver arrival completion.

Unknown rejection is not proof against false matches. The enrollment quality gate
does not prove that all examples are the same person; adult review remains required.
No independent child use, reliable family identification, exact direction, or safe
approach/follow behavior has been established by these cloud checks.
