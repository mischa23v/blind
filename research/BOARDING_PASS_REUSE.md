# Bounded offline boarding-pass reading: staged adapter

## Source and inspection

Mandatory field sequence adapted from MIT BoardingPassKit, copyright 2024 Justin Ackermann, pinned ef3b329e71605a9582ee674bd5ed9c1c71f3904d:
https://github.com/anomaddev/BoardingPassKit/blob/ef3b329e71605a9582ee674bd5ed9c1c71f3904d/packages/swift/Sources/BoardingPassKit/BoardingPassDecoder.swift

Complete decoder reviewed before adaptation; complete source archive remains local-only; publication-evidence/upstream-file-manifest.json records file hashes without upstream passenger literals. License accompanies this adapter. This is a narrow derived layout reader, not adoption of the unsafe decoder class or its image extractor. No upstream scripts, manifests or test code executed. No dependency added. Upstream tests/CI presence is not upstream execution evidence. Local adapter execution is separately recorded in swift-tests.log.

Official format cross-check: IATA BCBP Implementation Guide seventh edition, effective June 2018, pp. 14–16 (PDF page indices 12–14), data format and unavailable-field/conditional-length rules:
https://www.iata.org/contentassets/1dccc9ed041b4f3bbdcf8ee8682e75c4/2021_03_02-bcbp-implementation-guide-version-7-.pdf

Guide viewed directly using web PDF extraction on 2026-10-25. Not redistributed: copyright restrictions apply. Its data-format discussion supports multi-leg handling and preserving missing fields; it does not certify our parser. Optional issuance date differs from mandatory flight day-of-year. We do not convert either into a year.

## Changes to reviewed source behavior

- Value-type bounded parser: printable ASCII only, maximum 4096 bytes, one to four legs. Byte cursor checks each exact length before decoding. No force unwrap, negative length, silent padding or lossy decoding.
- Only route codes, operating flight, seat and raw flight day-of-year survive. Names, PNR, sequence, optional/security payloads are skipped; no raw payload is retained by controller, Codable storage, network, logs or error strings. Security envelope is bounded but signature is NOT verified.
- Optional field length is skipped exactly as supplied; unsupported trailing airline extensions reject conservatively instead of guessing. This is NOT complete BCBP conformance or authenticity validation. Unknown seat/day remain nil. Some real airline encodings may be rejected.
- No inferred year, flight validity, live gate, flight status, boarding permission, itinerary ownership or navigation authority. OCR gate is separately attributed to printed text or a sign observation with original timestamp; flight-number agreement cannot establish same travel date.
- OCR accepts only bounded explicit label/value pairs from one already-associated pass/cropped sign row. Arabic-Indic and Eastern Arabic digits normalize only in OCR. No O/0 or I/1 correction. Confidence threshold is a policy gate, not a calibrated accuracy guarantee.
- Exact session/request/perception/source/revision, leg index and capture time travel with each output receipt. One pending speech result, delivery-once, output privacy recheck, stale/future time rejection, changed source rejection, and interrupt/delete invalidation are executable pure policy.

## Native integration proposal: not applied

Rebase only after current RGB reader and voice-source changes land. No new mode, first-tab UI, or scanner menu.

1. In existing permitted foreground barcode job, collect at most eight Vision observations across supported PDF417/Aztec/QR/DataMatrix. Route M-prefix candidates to this controller BEFORE generic CodeReading or product memory; malformed pass candidates must never fall through to raw speech or saved product payload. Multiple candidates abstain. URLs remain nonexecuting.
2. Existing passive OCR/semantic reading dispatch may propose this capability when an actual relevant pass or airport sign row is observed, or the user asks flight/seat/gate. Do not treat signs as commands or choose a flight/leg from an LLM. For multileg requests ask for the flight and select exact index. No inference from today's date.
3. Bind BoardingReadingOwner to the actual current private source owner and complete capture/speech lease. UUID source/revision must be code-issued, not generated from payload/model input. Printed OCR must use the SAME pass source/revision; signs retain their own source/revision and exact row association. Whole boards may not be concatenated. Unassociated rows abstain.
4. Use current native private-source admission before ingest/prepare/deliver; true is not a default. Cancel native queued speech on interruptions, source replacement, background, mute/end, camera off, privacy deletion or owner changes. Call clear on source deletion/session retirement; do not persist passes. Deliver only when both barcode source and OCR source receipts still match actual live state. Never log raw callbacks.
5. Route the returned bounded text through existing ordinary attention/preferences/budget and final speech ownership checks, not model paraphrase. Never turn gate/seat into movement instructions. Existing independent hazard speech retains priority.
6. When only OCR exists without a BCBP, prepareObservation provides a separate timestamped observation-only renderer with no selected leg or known date. Never merge it into a verified itinerary or provide current-flight navigation. Native dispatch remains to be rebased.

## Acceptance boundaries

Staged pure implementation only. Test log executes actual Swift parser, renderer, controller and delivery selection using synthetic standards-shaped payloads with blank private header/PNR. No actual passenger passes used. Tests do not execute Vision, camera crop/row association, voice semantic dispatch, private-source native lease wiring, Apple SDK compilation, audible output, physical airport journeys or device latency. Those remain explicit integration/device gates; airport navigation is not complete.

A first local manifest build hit read-only default Swift cache paths (no code executed); relocated HOME/cache/TMPDIR into staging for the bounded jobs=2 test. No escalation, installs, model downloads or live repository edits.

Initial executable tests exposed five-character numeric flight padding rejection (00123). The grammar now accepts the bounded numeric field, trims leading zeroes only in output, and retains the failed-before log. Final exact hashes and terminal results are in PUBLICATION-SHA256SUMS and publication-evidence/swift-tests.log.

## Independent review corrections

Reviewer identified wall-clock rollback and stale-owner mutation. Controller now requires explicit select(owner) by the native selected-source authority, before callbacks. Prior-owner ingest/prepare/delivery cannot clear newer owner's pending result. Native adapter must issue a new revision/request for every replacement acquisition; callbacks must never call select themselves. Privacy deletion calls clear and revokes selection. Original monotonic capture and OCR observation timestamps are mandatory API parameters, separate from wall-clock timestamps used in speech. Delivery checks monotonic expiry and a non-regressing monotonic clock fence. The clock domain must be the same process uptime source across acquisition/controller/delivery; do not pass Date.timeIntervalSince1970 or restart time as uptime. Clear/select do not reset the clock fence. Tests cover A→B→late-A and wall-clock rollback.

Synthetic private-header test initially used 21 characters instead of the required 20; parser correctly rejected it. Corrected synthetic fixture and kept the failed-before log. No passenger data was involved.

Reviewer also identified destructive trimming of unsupported all-zero numeric fields with a suffix (000A → A). Parser now rejects zero-only/zero-plus-suffix flight and seat fields rather than guessing their airline meaning; positive numeric suffix cases retain their suffix and normalized number. Standby blanks remain unknown. Added regressions. Native speech integration must split this potentially long factual output into ordinary-budget compliant interruptible chunks (including the existing 30-word limit), each retaining the exact same source/leg/revision/lease; do not simply bypass ordinary speech budgets or truncate away source/uncertainty disclaimers. Pure text generation is not evidence of audible delivery.

## Secondary OCR-owner race correction (2026-10-25 08:05 UTC)

Reopened review found that a stale OCR callback under the same primary pass could clear or replace newer pending speech. Reproduced before repair: two new same-primary regressions produced three assertion failures; the failed-before source and log are preserved. Controller now owns a separate selectedTextSource. Only native selection authority may call selectTextSource with the still-current primary owner; OCR callbacks must never self-select. Replacing the secondary selection retires old pending output. prepare checks exact optional secondary identity/revision and printed-pass source association BEFORE clock admission or pending mutation. Nil-text fallbacks cannot supersede a selected OCR source. prepareObservation likewise requires the selected source. Delivery rejects prior source selection without altering a newer pending result or monotonic fence. Clear revokes both selections.

New tests cover same-primary selected printed/sign C followed by late B, selected-source retirement, nil fallback, late delivery, stale primary selection, privacy clear and a late callback carrying a far-future monotonic timestamp. This extends the earlier primary A→B regression; it does not prove native callback wiring, source association or audible delivery. Original publication-safe 0758 ZIP remains unchanged and superseded by this correction packet.
