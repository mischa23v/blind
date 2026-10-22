# Saudi banknotes: no-new-training reference comparison

## Current state

The active app route uses `SaudiBanknoteReferenceRecognition`, not a language model,
OCR-digit lookup or the earlier trained-classifier adapter. It reuses actual OpenCV
4.14.0 local-feature algorithms. **No validated reference pack is selected:**
`SaudiBanknoteReferenceProfile.selected` remains `nil`, so ordinary builds explicitly
say that recognition is unavailable and do not speak a guessed denomination.
This is implemented experimental source, not an installed reliable cash reader.
No classifier training, banknote photograph, descriptor pack or model weight is
part of this update. The earlier training/export utilities remain dormant.

## What the code actually does

1. A requested English/Arabic money intent enters the existing attention/speech
   flow. Current capture, tracking, strict <10 cm/<5-degree full optical pose (including pitch), cancellation and freshness gates still
   apply. Generic scene/OCR/remembered descriptions cannot bypass the money guard.
2. When a separately approved immutable profile exists, load a bounded private
   pack with an exact manifest SHA-256 and exact per-image hashes. Strict schema,
   path, symlink, decoded-size and provenance checks fail closed. Both sides of
   all eight labels and paper/polymer 5 are minimum inventory requirements, not
   proof of complete issue coverage, correct labels or lawful redistribution.
3. Rectify each reference from reviewed source-note corners, then extract SIFT,
   ORB or AKAZE features. The query retains the full view so a crop cannot hide a
   second note. BF ratio matches and RANSAC homography produce geometric evidence,
   not class probabilities. Inlier count/ratio, spread, grid coverage, projected
   shape, reprojection, competing labels and distinct matched regions are gated.
4. Apple Vision supplies an independent full-frame rectangle proposal. Require
   exactly one proposal and overlap of its actual four-corner polygon with the
   matched note, not merely their axis-aligned bounding boxes. This is an extra
   rejection mechanism, not a proven detector of every fold, overlap or second note.
5. Recheck cancellation and view validity before gated speech. Native computation
   is blocking internally; cancellation prevents obsolete output before/after it,
   but phone latency and interruption responsiveness still need measurement.

Uncertain, unsupported, multiple-note and unavailable cases never become a value.
Framing instructions must follow measured evidence; no invented blur/light cause.
There is no authenticity, counterfeit, total-value or safe-payment assertion.
Face and currency share one process-wide OpenCV thread initializer; face model,
alignment and recognition thresholds are unchanged.

## Evidence and recovery limits

The earlier private development comparison used 17 source-query cases, nine
references and seven denomination labels. It reported three acceptable single-note
matches, thirteen abstentions and one unsafe historical front/back composite
acceptance for each prepared-reference method. No wrong value was observed in that
tiny set. SIFT and AKAZE accepted 100, paper 5 and 10; ORB's polymer-5 query matched a
paper-5 reference, so material discrimination was not demonstrated. These are
development observations, not independent accuracy, a release winner or phone speed.
Modern 1/20, most backs/issues, broad negatives and physical capture conditions
remain insufficiently covered. Only two negative-image cases were represented.

The workspace was subsequently lost. Eight source/document files were recovered
and checked against saved Git blob hashes. Native adapter source was replayed from
its recorded writing commands; missing integration and portable Python files were
reconstructed and require fresh tests. Original private photos, raw experiment
outputs and the original 103-test portable suite are not recovered. The historical
observations are retained honestly, not claimed as a new evaluation of reconstructed
code. See `tools/currency-reference/RECOVERY.md` and its fresh test record.

The real unsafe composite has **not** been rerun through Apple Vision/native code.
Synthetic policy tests cover additional regions and tilted-polygon/bounding-box
confusion, but do not establish real-image rejection. This is a release blocker,
not a hidden successful test. Current fresh portable checks are recorded separately
in `PROGRESS.md`; Apple SDK typechecking, device builds, camera/VoiceOver, native
image parity, thermal/battery and end-to-end accuracy remain unverified for this
combined update. Earlier Mac face/UI results cover their own pre-currency checkout.

## Local setup and next acceptance gate

Preserve current Mac changes and regenerate from shared primary `master`. The
default source build includes colour; currency intentionally remains unavailable.
For a native experimental build, use the same official pinned OpenCV framework as
the existing face workflow:

```sh
npm ci --ignore-scripts
node tools/generate-xcode-project.mjs --currency-reference --opencv-framework /absolute/path/opencv2.framework
```

Face options may be combined, with their separately required external model paths.
The verified OpenCV 4.14.0 framework has arm64 device and x86_64 simulator slices,
not arm64 simulator. On an M1 Mac use the device build for this native experiment.
No framework or private image pack is committed. A folder alone never activates
recognition. See `ios/BlindAssist/CurrencyNative/REFERENCE_PACK_CONTRACT.md` for the
runtime schema, private pack option and activation requirements. The reconstructed
portable harness has its own documented development manifest; do not silently treat
that as the native runtime contract or assume preprocessing parity.

Next, inventory the user's locally downloaded labelled photos without publishing
them. Audit denomination, side, issue, paper/polymer material and actual note edges.
Separate physical notes and capture sessions before reference/calibration/test
selection; transformed copies of one photo are not independent note trials. Freeze
thresholds before held-out evaluation. Include 100↔1 and every costly pair, modern
and old issues, 20/200, paper/polymer 5, front/back, rotations, blur, lighting,
folds/occlusion, clipped notes, two notes/overlaps, foreign notes and non-money.
Report wrong-value rate, abstentions and per-class coverage with sample sizes.
Reject the known composite in the actual native chain, verify native/portable
preprocessing, then controlled adult phone trials before any child-facing use.

## Sources, licenses and boundaries

- OpenCV 4.14.0 code/API: https://github.com/opencv/opencv/tree/4.14.0
  and Apache-2.0 license: https://github.com/opencv/opencv/blob/4.14.0/LICENSE.
  Local guards are custom experimental policy, not upstream accuracy certification.
- The reviewed AlFloos paper: https://link.springer.com/article/10.1007/s43995-024-00067-z
  and dataset: https://www.kaggle.com/datasets/gfbati/alfloos. Paper and dataset
  licenses are separate. Earlier private sampled data were not redistributed.
- User-selected Mendeley dataset: https://data.mendeley.com/datasets/7sys44td9c/1.
  Published description: 2,000 smartphone photos, eight values, Pascal VOC labels,
  6.29 GB, CC BY 4.0. User download completion and actual archive coverage remain
  unconfirmed here; preserve annotations and attribution during local inspection.
- SAMA reproduction notice: https://sama.gov.sa/en-US/MediaCenter/News/Pages/News20071024.aspx.
  Image licensing does not by itself resolve applicable currency reproduction
  permissions. No conclusion that private training is categorically prohibited is
  claimed; no photos/reference assets are published in this change.

No external service receives camera frames. No paid resources or third-party
outreach are needed for this code preparation. Publication is source/tests/docs
only, not deployment or release approval.
