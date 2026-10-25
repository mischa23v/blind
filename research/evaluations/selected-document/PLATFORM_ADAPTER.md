# Selected PDF platform adapter

This stage uses system **PDFKit**, **Foundation NSFileCoordinator/FileHandle**,
and **UIKit UIDocumentPickerViewController**, not a third-party parser, model,
service or permission bypass. These are Apple platform SDK components under the
Apple SDK terms, not vendored open-source code. The app's existing deployment
target controls availability; actual Apple SDK compilation remains a required gate.

Official API references checked 2026-10-25:

- [PDFDocument data initialization and page extraction](https://developer.apple.com/documentation/pdfkit/pdfdocument)
- [Accessibility extraction permission](https://developer.apple.com/documentation/pdfkit/pdfdocument/allowscontentaccessibility)
- [Copy permission is a separate operation](https://developer.apple.com/documentation/pdfkit/pdfdocument/allowscopying)
- [Document picker result delegate](https://developer.apple.com/documentation/uikit/uidocumentpickerdelegate/documentpicker(_:didpickdocumentsat:))
- [Explicit picker cancellation delegate](https://developer.apple.com/documentation/uikit/uidocumentpickerdelegate/documentpickerwascancelled(_:))
- [Security-scoped access and coordinated reading](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
- [PDF write options used only for authored encrypted test fixtures](https://developer.apple.com/documentation/pdfkit/pdfdocumentwriteoption)

## Local adaptation and boundaries

The adapter opens only a selected security-scoped file URL, balances successful
access with `defer`, coordinates the read, streams at most 20 MiB plus one detection
byte, and rejects the whole oversized input. It makes an owned bounded copy before PDFKit parsing and hashing, including when
a caller supplies externally mutable NSData-backed Data, and hashes precisely the
retained immutable bytes. Before parsing or hashing, selection deep-copies bounded input
into owned storage, including externally mutable `NSMutableData`-backed aliases.
It retains no provider URL, name, bookmark or PDFKit object after
acquisition. There is no upload, persistent file write, diagnostic logging or
model invocation. Selection checks structure and permission but reads no page
text. An explicit one-based page request reparses only the immutable bytes.

PDFKit text-layer extraction checks `allowsContentAccessibility`, independently
of Pasteboard copy permission. Locked and malformed files, file access refusal,
accessibility extraction refusal, invalid page, encoded/text oversize, and no
readable text layer are distinct. Empty text is not evidence of a blank page.
The 64 KiB text and 128-byte label bounds reject whole results, not truncation.
The owner treats page labels as private source metadata, never trusted commands.

Text-layer output can omit diagrams, columns, tables, reading order and qualifiers.
It conveys no appliance/model identity, control instructions, interpretation or
physical authority. The system picker delegate, not sheet dismissal or a guessed
delay, resolves exactly one owner-tagged success/cancel result.

## Evidence scope

`SelectedDocumentPDFTests.swift` creates actual PDF bytes in memory with native
UIKit/PDFKit (and one authored minimal oversized text-stream PDF). It covers
English, Arabic/mixed numerals, multipage selection, image-only content,
malformed/locked files, independent accessibility/copy permissions, whole-input
and page-text oversize, columns, immutable-source replacement, mutable backing
storage isolation and delegate
single-result races. The plain `PDFFixtures` helper never constructs an XCTestCase.
No binary resources or production private files are needed.

These native tests are **prepared, not executed** in this Linux stage. No Apple
SDK typecheck, real picker interaction, security-scoped provider lifecycle,
speech/VoiceOver callback, comprehension, latency or participant acceptance is
claimed. Source-contract checks do not establish those outcomes. Component
delegate calls are not an end-to-end system picker test. The native owner must
retain its noncancellable work lease until the synchronous adapter returns;
cancellation alone does not free that lease.
