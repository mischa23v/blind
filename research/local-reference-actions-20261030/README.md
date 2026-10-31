# Local source and explicit-action increment

Source implementation only; no native build/device test or external action was run. No tracker family is closed by this increment.

## Concrete functionality

- **SC16:** a reachable local recipe JSON reader, bounded to 128 KiB, 100 ingredients and 100 steps. Original quantity/unit strings are retained, not guessed or automatically scaled. Navigation only changes which source step is displayed; it never reports cooking completion. Optional per-step seconds require an explicit Start. The monotonic foreground timer cancels on step change, page exit or inactive/background lifecycle. It has **no background alarm** and is explicitly unsuitable as a cooking-safety guarantee. No bundled recipe database or model is required. Imported text remains volatile/private and is not uploaded.
- **SC42/43 action handoff:** a user-authored local email draft with five explicit text checkpoints/undo and native Mail review. A direct UI action opens Apple's composer; only the person's subsequent system Send button can send. No programmatic send, account creation or payment operation exists. Cancelled, saved, failed and queued-for-sending outcomes remain separate. Queued is not delivered. No configured Mail account means the handoff is unavailable while local writing remains usable. This does not implement long voice dictation, contact resolution or an autonomous external assistant.
- Two additive Dashboard links make the functionality reachable after canonical project regeneration. The new source files must enter the generated iOS project. The root integration owner should regenerate once for the combined batch rather than merge independent generated-project rewrites.

## Existing source adapters reused, not replaced

`SelectedDocumentPDFAdapter` / `SelectedDocumentReference` already implement explicit selected-PDF page reading with bounded private literal source, expiry, speech and lifecycle receipts. `SelectedPhotoReference` and `CapturedTextReference` retain their own capture/source limits. These support literal menu/manual/document reading when supplied, not current restaurant inventory, appliance compatibility, verified allergens or an online booking.

`CompanionClock` in `CompanionEvidence.swift` and its `NavigationModel` delivery receipts already support device-configured clock answers. Time is not Khobar weather, daylight or location. There is no new weather service in this increment.

The checkout's `TASKS.md` E03/E04 mean danger priority and speech arbitration, not source/action adapters. This packet does not modify them. The referenced `tests/scenarios/integrated/requirement-coverage.json` is absent in this checkout; SC03/16/28/29/42/43/44 requirements were inventoried from the existing `research/tracker-reconciliation-20261028/TRACKER.json`, not reconstructed as completed tests.

## Source format

A user-selected recipe JSON contains schema 1, title, attribution, ingredients (`name`, verbatim `quantity`) and steps (`text`, optional integer `timerSeconds`, 1–86400). Unknown model output is not imported automatically. A source file's wording is reference content, not permission to execute its instructions. `example-format.json` is an authored no-food software fixture, not a recipe recommendation.

## Offline assets and remaining work

`OFFLINE_ASSETS.json` pins observed source assets/notices and records their honest availability. No model weights or recipes were added. The empty currency reference manifest is not a working recognizer, and familiar model license notices are not evidence that their weights are shipped. Apple Foundation Models/platform recognition availability still requires existing runtime checks and compatible locally installed assets. No paid API, private-image upload or download/install was introduced.

SC03 weather/daylight, SC28 live venue/menu sources, SC29 full reservation journeys, SC42 other assistants, SC43 long spoken review/editing and SC44 flights/orders/inaccessible web workflows remain incomplete. Source reading and native Mail handoff must not be counted as those complete scenarios. Reservation/payment/order actions remain unimplemented rather than falsely marked sent or booked.

## Upstream reuse and tests

Recipe decoding uses Foundation JSONDecoder; timers use ProcessInfo monotonic uptime; import/UI uses SwiftUI and the system document picker. Email uses the maintained Apple MessageUI framework rather than a new SMTP/client implementation. No external dependency or redistribution license is added. Apple confirms `.sent` means queued in the outbox, not delivery: https://developer.apple.com/documentation/messageui/mfmailcomposeresult/sent . Composer lifecycle: https://developer.apple.com/documentation/messageui/mfmailcomposeviewcontrollerdelegate/mailcomposecontroller(_:didfinishwith:error:) . Documentation checked 2026-10-30; native integration remains unverified.

Seven `LocalRecipeReferenceTests` methods are prepared: source/quantity preservation, bad/oversized data, bounds, monotonic expiry, no duplicate Start, step cancellation, clock discontinuity and background cancellation. They have **not been run** (native execution prohibited for this source batch). Required Apple follow-ups: compile all new views, test JSON selection/cancel/oversize/cloud-file-unavailable, English/Arabic VoiceOver, lifecycle timer cancellation, configured/unconfigured Mail, editing in composer, Cancel/Save/Send outcomes and stale/duplicate delegate callbacks. Use a controlled test mailbox only after separate explicit authorization for any actual sending.
