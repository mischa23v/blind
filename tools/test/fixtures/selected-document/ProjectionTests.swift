@main struct SelectedDocumentProjectionTests {
    @MainActor static var assertions = 0
    @MainActor static var failures = 0
    @MainActor static func check(_ value: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
        assertions += 1
        if !value() { failures += 1; print("FAIL line \(line): \(message)") }
    }
    @MainActor static func until(_ predicate: () -> Bool) async {
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        while !predicate() && ProcessInfo.processInfo.systemUptime < deadline {
            try? await Task.sleep(for: .milliseconds(2))
        }
        check(predicate(), "bounded async event arrived")
    }
    @MainActor static func main() async {
        // Real Core owner + actual native extension: reserve before any sink callback.
        do {
            let w = NavigationModel(); w.installFixture(issuedAgo: 120)
            var reserved = false
            w.onDispatch = { id, text in
                reserved = w.selectedDocument.pending?.id == id && w.selectedDocumentSpeechIDs.contains(id)
                check(w.selectedDocumentSpeechPermission(id: id, text: text), "exact output is permitted")
            }
            w.speakNextSelectedDocumentPhrase()
            check(reserved, "reservation precedes dispatch")
            check(w.selectedDocument.completed == 0, "enqueue never counts completion")
            let first = w.selectedDocument.pending!
            check(!w.selectedDocumentSpeechPermission(id: first.id, text: first.text + "changed"), "text mismatch rejected")
            w.projectedNativeStart(id: first.id, text: first.text + "changed")
            check(w.selectedDocument.lastStartedOrCompleted == nil && w.currentReply.isEmpty, "mismatched start cannot display private text")
            w.projectedNativeStart(id: first.id, text: first.text)
            check(w.selectedDocument.lastStartedOrCompleted?.id == first.id && w.currentReply == first.text, "exact actual start handler owns display, not completion")
            check(w.selectedDocument.completed == 0, "start is not completion")
            while let phrase = w.selectedDocument.pending {
                check(w.finishSelectedDocumentSpeech(id: phrase.id, text: phrase.text, outcome: .completed), "exact synthetic completion handled")
            }
            check(w.selectedDocument.playbackCompleted, "installed page completes beyond60s")
            check(!w.documentAttentionOwned, "completed retained document does not suppress ambient")
            check(w.redactedDiagnostics.allSatisfy { $0 == "redacted" }, "production private-reference expression redacts sentinel")
            check((w.dialogue + w.narrationHistory + w.modelContext).isEmpty, "extension does not call persistence/model sinks")
            w.clearSelectedDocument()
            check(w.currentReply.isEmpty && w.sceneAnswer.isEmpty, "owned private display clears on retirement")
        }
        // Ownership is revoked before exact-ID stop callbacks, and a newer reply survives.
        do {
            let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
            let old = w.selectedDocument.pending!
            w.showSelectedDocumentReply(old.text)
            w.currentReply = "New unrelated reply"; w.sceneAnswer = "New unrelated scene"
            var revokedBeforeStop = false
            w.feedback.onStop = { id in
                revokedBeforeStop = w.selectedDocument.selection == nil
                _ = w.finishSelectedDocumentSpeech(id: id, text: old.text, outcome: .completed)
            }
            w.clearSelectedDocument()
            check(revokedBeforeStop, "clear happens before synchronous callback")
            check(w.currentReply == "New unrelated reply" && w.sceneAnswer == "New unrelated scene", "clear preserves newer display")
            check(w.selectedPDF == nil && w.selectedDocument.page == nil, "private source and text retired")
            check(w.feedback.stopped == [old.id], "only owned speech stopped")
            w.installFixture(); let freshID = w.selectedDocument.request!.id
            _ = w.finishSelectedDocumentSpeech(id: old.id, text: old.text, outcome: .completed)
            check(w.selectedDocument.request?.id == freshID && w.selectedDocument.completed == 0, "late callback cannot advance replacement")
            w.clearSelectedDocument()
        }
        // Display ownership is revision based, not text equality: an unrelated
        // newer reply may legitimately have byte-identical wording.
        for replacedDisplay in 0..<3 {
            let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
            let phrase = w.selectedDocument.pending!
            w.projectedNativeStart(id: phrase.id, text: phrase.text)
            if replacedDisplay != 2 { w.currentReply = phrase.text }
            if replacedDisplay != 1 { w.sceneAnswer = phrase.text }
            w.clearSelectedDocument()
            check(w.currentReply == (replacedDisplay != 2 ? phrase.text : ""),
                  "byte-identical newer reply survives while still-owned reply clears")
            check(w.sceneAnswer == (replacedDisplay != 1 ? phrase.text : ""),
                  "scene display revision is independently owned")
            check(w.selectedDocument.page == nil && w.selectedPDF == nil,
                  "display preservation does not retain private document ownership")
        }
        // Every privacy/lifecycle gate retires; no autonomous restart on restoration.
        for gate in 0..<6 {
            let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
            if gate == 0 { w.assistantSession.privateAudioHeld = true }
            if gate == 1 { w.assistantSession.foregroundActive = false }
            if gate == 2 { w.ambientDescriptions = false }
            if gate == 3 { w.detection.hazard.isUrgent = true }
            if gate == 4 { w.assistantSession.generation += 1 }
            if gate == 5 { w.assistantSession.mayRespond = false }
            w.revalidateSelectedDocumentOwnership()
            check(w.selectedDocument.selection == nil && w.selectedPDF == nil, "gate retires all owned private data")
            w.assistantSession = ProjectedSession(); w.detection = ProjectedDetection(); w.ambientDescriptions = true
            let count = w.delivered.count; w.speakNextSelectedDocumentPhrase()
            check(w.delivered.count == count, "restoration never restarts reading")
        }
        // Early Repeat never strands unread text; actual owned wake dispatches without frames.
        do {
            let w = NavigationModel(); w.installFixture()
            w.companion.release = ProcessInfo.processInfo.systemUptime + 0.04
            w.speakNextSelectedDocumentPhrase()
            let owner = w.selectedDocument.request!.id, wake = w.selectedDocumentBudgetWakeAt
            check(wake != nil && w.selectedDocument.pending == nil, "budget wait owns no speech")
            check(w.routeSelectedDocumentCommand("repeat", origin: .trustedInterface), "document handles early Repeat")
            check(w.selectedDocument.request?.id == owner && w.selectedDocumentBudgetWakeAt == wake, "Repeat retains original request and wake")
            check(w.notices.isEmpty, "denied guidance is not queued or persisted")
            await until { w.selectedDocument.pending != nil }
            check(w.selectedDocument.completed == 0 && w.delivered.count == 1, "wake admits not completes")
            w.clearSelectedDocument()
        }
        // Old wake cancellation cannot restart replacement, and budget changes keep cursor.
        do {
            let w = NavigationModel(); w.installFixture()
            w.companion.release = ProcessInfo.processInfo.systemUptime + 60
            w.speakNextSelectedDocumentPhrase(); let request = w.selectedDocument.request!.id
            w.cancelSelectedDocumentBudgetWake(); w.companion.release = 0; w.speakNextSelectedDocumentPhrase()
            check(w.selectedDocument.request?.id == request && w.selectedDocument.pending != nil, "pacing retry preserves request/cursor")
            let phrase = w.selectedDocument.pending!
            _ = w.finishSelectedDocumentSpeech(id: phrase.id, text: phrase.text, outcome: .interrupted)
            check(w.selectedDocument.selection == nil, "interruption terminally retires not pauses")
            w.speakNextSelectedDocumentPhrase(); check(w.delivered.count == 1, "no interrupted restart")
        }
        // Unverified speech is not a picker or page authority.
        do {
            let w = NavigationModel()
            check(!w.routeSelectedDocumentCommand("choose a PDF", origin: .unverifiedMicrophone), "unverified choose rejected")
            check(w.selectedDocumentPickerRequest == nil, "no unverified picker")
            w.installFixture(); let request = w.selectedDocument.request!.id
            check(!w.routeSelectedDocumentCommand("Read PDF page 2", origin: .unverifiedMicrophone), "unverified read rejected")
            check(w.selectedDocument.request?.id == request, "unverified request cannot replace owner")
            w.clearSelectedDocument()
        }
        // Hold a genuinely noncancellable detached substitute until actual return.
        do {
            SelectedDocumentPDFAdapter.work.reset(hold: true)
            let w = NavigationModel(); w.chooseSelectedDocument()
            let owner = w.selectedDocumentPickerRequest!.id
            w.selectedDocumentPickerPicked(owner, url: URL(fileURLWithPath: "/PRIVATE_FILENAME_SENTINEL.pdf"))
            await until { SelectedDocumentPDFAdapter.work.calls == 1 }
            check(w.selectedDocumentNativeLease == owner, "native import lease acquired")
            w.selectedDocumentPickerCancelled(owner)
            check(w.selectedDocumentNativeLease == owner, "cancel does not release noncancellable lease")
            w.chooseSelectedDocument()
            check(w.selectedDocumentPickerRequest == nil && SelectedDocumentPDFAdapter.work.calls == 1, "no stacked job")
            SelectedDocumentPDFAdapter.work.release()
            await until { w.selectedDocumentNativeLease == nil }
            check(w.selectedPDF == nil && w.selectedDocument.selection == nil, "late import cannot revive selection")
            check(SelectedDocumentPDFAdapter.work.peak == 1, "one native job at a time")
            check(!(w.notices + w.redactedDiagnostics).joined().contains("PRIVATE_"), "provider sentinels never reach notice or log")
            w.clearSelectedDocument()
        }
        // Selection completion is not a read, and stale extraction cannot install.
        do {
            SelectedDocumentPDFAdapter.work.reset(hold: false)
            let w = NavigationModel(); w.chooseSelectedDocument()
            let owner = w.selectedDocumentPickerRequest!.id
            w.selectedDocumentPickerPicked(owner, url: URL(fileURLWithPath: "/fixture-only.pdf"))
            await until { w.selectedDocument.selection != nil }
            check(w.selectedDocument.request == nil && w.delivered.isEmpty, "select does not read page text")
            check(!w.documentAttentionOwned, "idle selected bytes do not own attention")
            SelectedDocumentPDFAdapter.work.reset(hold: true)
            w.readSelectedDocumentPage(1)
            await until { SelectedDocumentPDFAdapter.work.calls == 1 }
            let lease = w.selectedDocumentNativeLease
            w.clearSelectedDocument()
            check(w.selectedDocumentNativeLease == lease, "page cancellation retains worker lease")
            SelectedDocumentPDFAdapter.work.release()
            await until { w.selectedDocumentNativeLease == nil }
            check(w.selectedDocument.page == nil && w.delivered.isEmpty, "late page cannot install or dispatch")
        }
        // Expiry uses original owner, never cancels a newer owner or extends old work.
        do {
            let w = NavigationModel(); w.installFixture()
            let request = w.selectedDocument.request!
            w.scheduleSelectedDocumentAcquisitionExpiry(ownerID: UUID(), issuedAt: 0)
            try? await Task.sleep(for: .milliseconds(10))
            check(w.selectedDocument.request == request, "stale expiry cannot clear installed owner")
            w.clearSelectedDocument()
            let expired = w.installExpiredAcquisition()
            w.scheduleSelectedDocumentAcquisitionExpiry(ownerID: expired.id, issuedAt: expired.issuedAt)
            await until { w.selectedDocument.request == nil }
            check(w.delivered.isEmpty, "expired acquisition never speaks")
            check(w.selectedDocument.selection != nil && w.selectedPDF != nil, "page timeout retains valid immutable file for explicit correction")
            w.speakNextSelectedDocumentPhrase()
            check(w.delivered.isEmpty, "timed-out page never automatically restarts")
            w.clearSelectedDocument()
        }
        for entry in 0..<2 {
            let w = NavigationModel(); let expired = w.installExpiredAcquisition()
            if entry == 0 { w.revalidateSelectedDocumentOwnership() }
            else { w.speakNextSelectedDocumentPhrase() }
            check(w.selectedDocument.request == nil && w.selectedDocument.selection != nil && w.selectedPDF != nil,
                  "validation or idle cannot withdraw whole source before page timeout handler")
            check(w.delivered.isEmpty, "expired validation entry never dispatches")
            w.readSelectedDocumentPage(1)
            check(w.selectedDocument.request?.id != expired.id && w.selectedDocument.request != nil,
                  "only explicit request creates a new timeout owner")
            await until { w.selectedDocument.page != nil }
            w.clearSelectedDocument()
        }
        do {
            let w = NavigationModel(); w.chooseSelectedDocument()
            let owner = w.selectedDocumentImportOwner!.id
            w.scheduleSelectedDocumentAcquisitionExpiry(ownerID: owner,
                issuedAt: ProcessInfo.processInfo.systemUptime - 61)
            await until { w.selectedDocumentImportOwner == nil }
            check(w.selectedDocumentPickerRequest == nil && w.selectedDocument.selection == nil && w.selectedPDF == nil,
                  "import timeout has no installed selection to preserve")
            check(w.delivered.isEmpty, "import expiry cannot read or resume")
            w.clearSelectedDocument()
        }
        do {
            SelectedDocumentPDFAdapter.work.reset(hold: true)
            let w = NavigationModel(); w.installFixture(); w.readSelectedDocumentPage(1)
            await until { SelectedDocumentPDFAdapter.work.calls == 1 }
            let lease = w.selectedDocumentNativeLease!
            // Invoke the real expiry event handler while a real detached substitute
            // is blocked; separate aged-request cases above test due-time checks.
            w.expireSelectedDocumentAcquisition(ownerID: lease)
            check(w.selectedDocument.request == nil && w.selectedDocument.selection != nil && w.selectedPDF != nil,
                  "page expiry event retains selected file but revokes request")
            check(w.selectedDocumentNativeLease == lease, "page timeout cannot release actual native worker")
            SelectedDocumentPDFAdapter.work.release()
            await until { w.selectedDocumentNativeLease == nil }
            check(w.selectedDocument.page == nil && w.delivered.isEmpty, "timed-out late extraction cannot install or dispatch")
            w.clearSelectedDocument()
        }
        // Invalid and out-of-range new page requests retire the OLD request in
        // every state; an error notice must not leave old private audio running.
        for invalid in ["Read PDF page 0", "Read PDF page 3"] {
            do {
                let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
                let phrase = w.selectedDocument.pending!
                var revoked = false
                w.feedback.onStop = { id in
                    revoked = w.selectedDocument.request == nil
                    _ = w.finishSelectedDocumentSpeech(id: id, text: phrase.text, outcome: .completed)
                }
                check(w.routeSelectedDocumentCommand(invalid, origin: .trustedInterface), "invalid new page is handled")
                check(revoked && w.feedback.stopped == [phrase.id], "invalid request revokes then stops exact old speech")
                check(w.selectedDocument.request == nil && w.selectedDocument.page == nil && w.selectedDocument.selection != nil && w.selectedPDF != nil, "invalid request retires page but retains explicitly selected immutable source")
                let count = w.delivered.count
                _ = w.finishSelectedDocumentSpeech(id: phrase.id, text: phrase.text, outcome: .completed)
                w.speakNextSelectedDocumentPhrase()
                check(w.delivered.count == count, "stale old completion cannot resume after invalid request")
                check(w.notices.last != nil && !w.notices.last!.contains("Choose the PDF again") && !w.notices.last!.contains("Choose it again"), "invalid request permits correction without reselecting PDF")
                w.clearSelectedDocument()
            }
            do {
                let w = NavigationModel(); w.installFixture()
                w.companion.release = ProcessInfo.processInfo.systemUptime + 0.025
                w.speakNextSelectedDocumentPhrase()
                check(w.selectedDocumentBudgetWakeAt != nil, "invalid budget scenario starts waiting")
                _ = w.routeSelectedDocumentCommand(invalid, origin: .trustedInterface)
                check(w.selectedDocumentBudgetWakeAt == nil && w.selectedDocument.request == nil && w.selectedDocument.selection != nil, "invalid request cancels owner-bound wake but retains selection")
                try? await Task.sleep(for: .milliseconds(40))
                check(w.delivered.isEmpty, "cancelled budget wake never speaks old page")
                w.clearSelectedDocument()
            }
            do {
                let w = NavigationModel(); w.installFixture(words: 3); w.speakNextSelectedDocumentPhrase()
                let phrase = w.selectedDocument.pending!
                _ = w.finishSelectedDocumentSpeech(id: phrase.id, text: phrase.text, outcome: .completed)
                check(w.selectedDocument.playbackCompleted, "invalid completion scenario starts complete")
                _ = w.routeSelectedDocumentCommand(invalid, origin: .trustedInterface)
                check(w.selectedDocument.request == nil && w.selectedDocument.page == nil && w.selectedDocument.selection != nil && w.selectedPDF != nil, "invalid request retires completed page but retains selection")
                w.speakNextSelectedDocumentPhrase()
                check(w.delivered.count == 1, "completed source cannot restart after invalid request")
                w.clearSelectedDocument()
            }
            do {
                SelectedDocumentPDFAdapter.work.reset(hold: true)
                let w = NavigationModel(); w.installFixture(); w.readSelectedDocumentPage(2)
                await until { SelectedDocumentPDFAdapter.work.calls == 1 }
                let lease = w.selectedDocumentNativeLease
                _ = w.routeSelectedDocumentCommand(invalid, origin: .trustedInterface)
                check(w.selectedDocument.request == nil && w.selectedDocument.selection != nil && w.selectedDocumentNativeLease == lease,
                      "invalid request revokes extraction owner but retains noncancellable lease")
                w.readSelectedDocumentPage(1)
                check(w.selectedDocument.request == nil && w.selectedDocument.selection != nil &&
                      SelectedDocumentPDFAdapter.work.calls == 1 && w.selectedDocumentNativeLease == lease,
                      "corrected request while old worker runs cannot stack work or discard selected bytes")
                SelectedDocumentPDFAdapter.work.release()
                await until { w.selectedDocumentNativeLease == nil }
                check(w.selectedDocument.page == nil && w.delivered.isEmpty, "invalidated extraction return cannot install or speak")
                let source = w.selectedDocument.selection!.identity
                w.readSelectedDocumentPage(1)
                let corrected = w.selectedDocument.request!.id
                check(corrected != lease && w.selectedDocument.selection?.identity == source && w.selectedDocumentPickerRequest == nil,
                      "corrected valid page gets new owner on same selected source without picker")
                await until { w.selectedDocument.page != nil }
                check(w.selectedDocument.pending != nil && w.delivered.count == 1,
                      "corrected explicit request can read after actual worker return")
                w.clearSelectedDocument()
            }
        }
        // Correction is not permission to retain a source through privacy loss.
        do {
            let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
            w.assistantSession.privateAudioHeld = true
            _ = w.routeSelectedDocumentCommand("Read PDF page 0", origin: .trustedInterface)
            check(w.selectedDocument.selection == nil && w.selectedPDF == nil,
                  "privacy-invalid correction clears entire source instead of preserving it")
            w.assistantSession.privateAudioHeld = false
            w.readSelectedDocumentPage(1)
            check(w.selectedDocument.request == nil && w.delivered.count == 1,
                  "privacy restoration cannot auto-reuse retired selected bytes")
            w.clearSelectedDocument()
        }
        // A cleared/error document reply keeps Repeat in this lane, not history.
        do {
            let w = NavigationModel()
            w.failSelectedDocument(SelectedDocumentPDFAdapter.Failure.noReadableTextLayer)
            check(w.selectedDocument.selection == nil && w.selectedDocumentDisplay != nil, "failure has a code-owned document reply only")
            let count = w.notices.count
            check(w.routeSelectedDocumentCommand("repeat", origin: .trustedInterface), "Repeat after error is claimed by document lane")
            check(w.notices.count == count + 1, "truthful no-source guidance is offered")
            check(!w.notices.last!.contains(SelectedDocumentPDFAdapter.sentinel), "no invented source quotation")
            w.clearSelectedDocument()
        }
        // Page-specific extraction failures retain the explicit source for a new
        // requested page; locked/permission/structure failures clear the file.
        for failure in [SelectedDocumentPDFAdapter.Failure.noReadableTextLayer, .oversizedPage, .invalidPage] {
            let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
            let source = w.selectedDocument.selection!.identity, phrase = w.selectedDocument.pending!
            w.failSelectedDocument(failure)
            check(w.selectedDocument.selection?.identity == source && w.selectedPDF != nil && w.selectedDocument.request == nil,
                  "page-specific failure retires request not valid selected file")
            check(w.feedback.stopped == [phrase.id] && w.selectedDocument.page == nil, "page failure retires exact old speech and page text")
            _ = w.finishSelectedDocumentSpeech(id: phrase.id, text: phrase.text, outcome: .completed)
            check(w.selectedDocument.request == nil && w.delivered.count == 1, "page-error stale callback cannot restart")
            w.clearSelectedDocument()
        }
        do {
            let w = NavigationModel(); w.installFixture()
            w.failSelectedDocument(SelectedDocumentPDFAdapter.Failure.locked)
            check(w.selectedDocument.selection == nil && w.selectedPDF == nil, "locked file failure clears entire selected source")
            w.clearSelectedDocument()
        }
        do {
            let w = NavigationModel(); w.installFixture()
            let request = w.selectedDocument.request!.id
            w.selectedDocumentNotice("Fixed PDF guidance only.")
            let noticeID = w.noticeSpeechIDs.last!
            check(!w.selectedDocumentSpeechIDs.contains(noticeID), "fixed notice is not a document quotation owner")
            w.projectedNativeStart(id: noticeID, text: "Fixed PDF guidance only.")
            check(!w.finishSelectedDocumentSpeech(id: noticeID, text: "Fixed PDF guidance only.", outcome: .completed),
                  "notice callback does not masquerade as document completion")
            check(w.selectedDocument.request?.id == request && w.selectedDocument.completed == 0,
                  "fixed notice never advances or replaces page request")
            w.clearSelectedDocument()
            check(w.currentReply.isEmpty && w.sceneAnswer.isEmpty, "fixed document notice clears with its own display revisions")
        }
        // Parsed trusted PDF requests take over narrow ordinary/captured/photo
        // work even when the page request is invalid or no file was selected.
        for (command, selected) in [("Read PDF page 0", true), ("Read PDF page 3", true),
                                    ("Read PDF page 1", false), ("Forget PDF", false), ("Choose a PDF", false)] {
            let w = NavigationModel()
            if selected { w.installFixture() }
            w.ordinarySourceActive = true; w.capturedSourceActive = true; w.photoSourceActive = true
            let foreignID = UUID(); var foreignCallbackAsDocument = false
            w.onRetireOtherWork = {
                if w.finishSelectedDocumentSpeech(id: foreignID, text: "OTHER_SOURCE_SENTINEL", outcome: .completed) {
                    foreignCallbackAsDocument = true
                }
            }
            check(w.routeSelectedDocumentCommand(command, origin: .trustedInterface), "trusted parsed PDF request handled")
            check(!w.ordinarySourceActive && !w.capturedSourceActive && !w.photoSourceActive,
                  "invalid or no-source PDF request retires all previous narrow reading owners")
            check(w.ordinaryRetirements > 0 && w.capturedRetirements > 0 && w.photoRetirements > 0,
                  "trusted PDF parser admission performs narrow cleanup before returning")
            check(!w.noticeHadPriorSource, "new PDF guidance cannot be admitted while older source work remains active")
            check(!foreignCallbackAsDocument && w.selectedDocument.completed == 0,
                  "old other-source callback cannot be mistaken for PDF completion")
            check(!w.notices.joined().contains("OTHER_SOURCE_SENTINEL"), "old-source sentinel never becomes PDF error guidance")
            w.clearSelectedDocument()
        }
        for (command, origin) in [("Read PDF page 1", CompanionCommandOrigin.unverifiedMicrophone),
                                  ("Choose a PDF", .unverifiedMicrophone),
                                  ("Read PDF page 1 extra", .trustedInterface),
                                  ("Hello", .trustedInterface), ("repeat", .trustedInterface)] {
            let w = NavigationModel(); w.installFixture()
            w.ordinarySourceActive = true; w.capturedSourceActive = true; w.photoSourceActive = true
            let request = w.selectedDocument.request!.id
            _ = w.routeSelectedDocumentCommand(command, origin: origin)
            check(w.ordinaryRetirements == 0 && w.capturedRetirements == 0 && w.photoRetirements == 0,
                  "unknown unverified or contextual Repeat never claims takeover cleanup")
            check(w.ordinarySourceActive && w.capturedSourceActive && w.photoSourceActive &&
                  w.selectedDocument.request?.id == request,
                  "non-authoritative input or Repeat preserves prior sources and queued document request")
            w.clearSelectedDocument()
        }
        // Closed punctuation/polite aliases invoke the SAME trusted owner path,
        // not a model or new authorization. Natural Arabic questions use nouns.
        for command in ["Choose a PDF.", "Please choose a PDF!", "Can you choose a PDF?",
                        "Could you please choose a PDF.", "من فضلك اختر ملف PDF.",
                        "لو سمحت اختر ملف PDF!", "هل يمكنك اختيار ملف PDF؟"] {
            let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
            let old = w.selectedDocument.pending!
            check(w.routeSelectedDocumentCommand(command, origin: .trustedInterface), "closed polite choose alias handled")
            check(w.selectedDocumentPickerRequest != nil && w.selectedDocumentImportOwner != nil,
                  "polite choose opens the real owner-tagged picker path")
            check(w.selectedDocument.selection == nil && w.selectedDocument.request == nil &&
                  w.feedback.stopped == [old.id], "polite replacement chooses without reading and retires exact old speech")
            w.clearSelectedDocument()
        }
        for command in ["Read PDF page 2.", "Please read PDF page 2!", "Can you read PDF page 2?",
                        "Could you please read PDF page 2.", "من فضلك اقرأ صفحة PDF ٢.",
                        "لو سمحت اقرأ صفحة PDF ٢!", "هل يمكنك من فضلك قراءة صفحة PDF ٢؟"] {
            SelectedDocumentPDFAdapter.work.reset(hold: true)
            let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
            let source = w.selectedDocument.selection!.identity, oldRequest = w.selectedDocument.request!.id
            let oldPhrase = w.selectedDocument.pending!
            let handled = w.routeSelectedDocumentCommand(command, origin: .trustedInterface)
            check(handled, "closed polite explicit-page alias handled")
            check(w.selectedDocument.request?.id != oldRequest && w.selectedDocument.request?.pageNumber == 2 &&
                  w.selectedDocument.selection?.identity == source, "polite read mints a new request for exactly page two of same selected source")
            if handled {
                await until { SelectedDocumentPDFAdapter.work.calls == 1 }
                _ = w.finishSelectedDocumentSpeech(id: oldPhrase.id, text: oldPhrase.text, outcome: .completed)
                check(w.selectedDocument.completed == 0 && w.selectedDocument.page == nil,
                      "prior-page callback cannot complete newly requested polite read")
            }
            SelectedDocumentPDFAdapter.work.release()
            if handled {
                await until { w.selectedDocument.page != nil }
                check(w.selectedDocument.page?.pageNumber == 2 && w.selectedDocument.pending != nil,
                      "polite page request installs only its explicit page")
            }
            w.clearSelectedDocument()
        }
        for command in ["Forget PDF.", "Please forget PDF!", "Can you forget PDF?",
                        "Could you please forget PDF.", "من فضلك انس ملف PDF.",
                        "لو سمحت انس ملف PDF!", "هل يمكنك نسيان ملف PDF؟"] {
            let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
            let old = w.selectedDocument.pending!
            check(w.routeSelectedDocumentCommand(command, origin: .trustedInterface), "closed polite forget alias handled")
            check(w.selectedDocument.selection == nil && w.selectedPDF == nil && w.selectedDocument.request == nil,
                  "polite forget retires selected bytes and page owner")
            check(w.feedback.stopped == [old.id], "polite forget stops exact owned speech")
            w.clearSelectedDocument()
        }
        for command in ["Can you read PDF page 0?", "Please read PDF page 3.",
                        "هل يمكنك قراءة صفحة PDF ٠؟", "لو سمحت اقرأ صفحة PDF ٣!"] {
            let w = NavigationModel(); w.installFixture(); w.speakNextSelectedDocumentPhrase()
            let source = w.selectedDocument.selection!.identity, old = w.selectedDocument.pending!
            check(w.routeSelectedDocumentCommand(command, origin: .trustedInterface), "polite invalid numeric page stays a recognized correction")
            check(w.selectedDocument.selection?.identity == source && w.selectedPDF != nil &&
                  w.selectedDocument.request == nil && w.selectedDocument.page == nil,
                  "polite invalid page retains chosen file but retires old page")
            check(w.feedback.stopped == [old.id], "polite invalid request stops old source speech")
            w.clearSelectedDocument()
        }
        for command in ["\"Please read PDF page 1.\"", "Do not read PDF page 1.",
                        "If you can, read PDF page 1.", "Can you not read PDF page 1?",
                        "She said please choose a PDF.", "Read PDF page 1 then page 2.",
                        "Read PDF page 1?!", "هل يمكنك عدم قراءة صفحة PDF ١؟",
                        "إذا أمكن اقرأ صفحة PDF ١.", "هل يمكنك اقرأ صفحة PDF ١؟"] {
            let w = NavigationModel(); w.installFixture(); let old = w.selectedDocument.request!.id
            check(!w.routeSelectedDocumentCommand(command, origin: .trustedInterface), "quoted negative conditional chained or non-grammar request stays outside PDF lane")
            check(w.selectedDocument.request?.id == old && w.ordinaryRetirements == 0 &&
                  w.capturedRetirements == 0 && w.photoRetirements == 0,
                  "unknown alias leaves source owner and unrelated work untouched")
            w.clearSelectedDocument()
        }
        for command in ["Please choose a PDF.", "Can you read PDF page 2?", "Could you forget PDF!",
                        "هل يمكنك اختيار ملف PDF؟", "هل يمكنك قراءة صفحة PDF ٢؟", "من فضلك انس ملف PDF."] {
            let w = NavigationModel(); w.installFixture(); let old = w.selectedDocument.request!.id
            check(!w.routeSelectedDocumentCommand(command, origin: .unverifiedMicrophone), "politeness never authenticates microphone input")
            check(w.selectedDocument.request?.id == old && w.selectedDocumentPickerRequest == nil &&
                  w.ordinaryRetirements == 0 && w.capturedRetirements == 0 && w.photoRetirements == 0,
                  "unverified polite input has no reading picking forgetting or takeover authority")
            w.clearSelectedDocument()
        }
        print("Selected document projection: \(assertions) assertions; \(failures) failures. Substitute PDF/speech/session/budget, not native acceptance.")
        if failures > 0 { exit(1) }
    }
}
