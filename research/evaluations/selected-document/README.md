# Selected PDF page quotation — bounded local candidate

This increment adds **Choose a PDF**, a one-based PDF-file page selector, **Read PDF page N**, and **Forget PDF** to the existing conversation controls. The same complete trusted typed commands are supported in English/Arabic. It adds no app page, account, dependency, cloud service, file-sharing entitlement or hands-free authority. Unverified microphone input cannot select/read a private document.

Typed commands use a small whole-request grammar, not general natural-language understanding: one final `.`, `!`, `?` or `؟` and reviewed direct polite English/Arabic forms are accepted (for example, “Can you read PDF page 2?” and “هل يمكنك قراءة صفحة PDF ٢؟”). Quoted, negated, conditional and multi-clause requests are not interpreted as document commands. Recognized invalid decimal page numbers use the same page-only correction flow. The visible controls remain the primary discoverable route.

Selection and reading are separate. The supported system picker supplies the sole URL authority; its delegate resolves success/cancel once. Dismissing the SwiftUI sheet does not cancel a successful result. A bounded coordinated read releases security-scoped access on every outcome, retaining only immutable in-memory bytes, their actual SHA-256 and page count. An explicit page request extracts that page's real PDFKit text layer. Source identity is `.selectedDocument`, always private, with no exact appliance model or physical/control authority.

## Lifetime, privacy and delivery

- Each page request has its own identity and original request time. Native extraction **and installation** must complete inside 60 seconds. A new asynchronous result cannot refresh that time. The one native resource lease remains occupied until synchronous PDFKit work returns, even after cancellation.
- After admission, the finite immutable page text can finish through ordinary budget waits beyond 60 seconds. Every attributed English/Arabic phrase fits the minimum 30-word allowance and preserves original slices. Existing manual and selected-photo `prepare`/`revalidate` deadline wrappers are unchanged; a pure slicing helper grants no authority.
- Exact IDs/text/source/request/session own dispatch, onset and real completion callbacks. Enqueue is not completion. Source replacement, unrelated trusted input, stop/forget, background/session retirement, quiet, private-route loss and urgent hazards revoke ownership before stopping only that document's speech. Old callbacks cannot revive it or erase a newer reply. Native return alone releases the worker lease.
- Source text, names, URL, bytes and hash do not enter dialogue, narration history, model context, persistent stores or diagnostics. Private-reference recognition is installed **before dispatch**, including rejection/start/completion redaction in Feedback. The displayed private phrase is cleared only while its exact display revision is still owned—even an identical-text newer unrelated reply survives.
- One owner-bound budget wake and actual idle/voice-ready callbacks retry playback, not camera frames. Pacing changes preserve the unread cursor. Ambient work is suppressed only while acquisition/playback owns attention; independent hazards remain enabled.
- A parsed trusted PDF request also retires prior ordinary/captured/photo reading before any failure guidance, so an invalid or missing-file request cannot continue quoting the wrong source. Unknown commands, unverified microphone input and contextual Repeat do not enter that takeover boundary.
- Repeat stays in the PDF context and gives bounded guidance for explicitly requesting the same page again. It does not renew acquisition, automatically resume, jump pages or fall through to unrelated narration. Invalid page requests retire the old page work and give the valid page range while retaining the valid selected file. A corrected explicit page request needs no new picker. In-flight native work still holds its lease; correction cannot stack jobs or silently resume. Page-only timeouts and no-readable-text-layer/oversized-page failures likewise retain a valid file for a new explicit request; they do not renew the old request.

## Honest limits

PDF file page numbers can differ from printed page labels. Locked, malformed, inaccessible, permission-denied, oversized, invalid-page and no-readable-text-layer results are distinct. Empty extraction **does not mean a blank page**. Copy permission is not treated as accessibility extraction permission. Oversized input/results are rejected whole, never silently truncated.

Only the text layer is quoted. Diagrams, tables, columns, reading order and qualifiers may be absent. No OCR fallback, model interpretation, price/allergen/column association, appliance/manual binding, control instructions or physical guidance is provided. No automatic next page or persisted document exists.

**R39 and R40 remain partial.** This is not the exact-model manual pathway or complete native/audio/participant acceptance.

## Verification scope

The accompanying verification receipt records the exact executed portable counts and source manifests. Core tests cover ownership, source identity, original acquisition expiry versus installed playback, callback completion, cancellation, whole-text preservation, minimum budgets and unchanged manual/photo expiry. The controller projection executes the actual document extension, start callback and private-reference expression with real Core ownership and explicitly substituted PDF/audio/session/budget boundaries. It is not native acceptance.

Fourteen prepared native tests generate actual PDF bytes for English, Arabic/mixed numbers, multipage, image-only, locked, malformed, permission, oversized and column/table cases, plus immutable replacement, externally mutable NSData-alias freezing and picker delegate races. No XCTestCase is constructed as a fixture. The first actual app run at `6d6954b17b0a35836506a7dead62aa855112cb98` compiled successfully and executed all fourteen PDF tests: **nine passed, five failed**. The selected native fixture repair is not yet Apple-executed; original failures remain evidence, not erased by portable checks. Manual delegate calls are not a real system picker/security-grant test. Actual speech/VoiceOver, comprehension, latency, interruptions, accessibility and supervised participant acceptance remain separate gates.

See [platform API/adoption and fixture boundaries](PLATFORM_ADAPTER.md).

## Actual native failures and fixture-only repair

Main run 40243450535, job 121319972133 exposed five failing PDF methods. Three source-binding methods assumed underscore-containing sentinel text; the precise extraction difference was not logged, so an underscore explanation remains a hypothesis. Short distinct ALPHA/BETA tokens plus direct native per-page/source text comparisons preserve and strengthen the page/source/byte/hash checks.

The old oversized-text fixture placed 80,000 characters on one horizontal line outside a 612-point page; actual PDFKit extracted 161 bytes. Its replacement places 900 nonoverlapping 100-character rows inside a 1,000 × 10,000-point page. The native test still requires actual PDFKit extraction above 64 KiB before asserting whole-page rejection; portable structure/extraction does not satisfy that gate.

The copying-only writer fixture actually allowed accessibility extraction. That input is retained and adapter behavior is compared to the actual native accessibility flag. The existing accessibility-allowed/copy-denied case is unchanged. A separate no-permissions fixture must be encrypted, unlocked and actually deny accessibility before the adapter rejection assertion. No conditional pass, skip, injected text, production permission bypass or lowered size limit replaces that negative test. If native fixture preconditions fail, the test remains failed.

The standalone 0320629 probe reached zero tests because its 120-second simulator readiness bound expired; it is not a competing PDFKit result. Proposed 180-second readiness correction is held, not activated. App adapter/picker/Core/controller production code remains unchanged. Corrected fixture Apple execution, real system-picker grants, speech/VoiceOver and participant usefulness remain pending; R39/R40 remain partial.
