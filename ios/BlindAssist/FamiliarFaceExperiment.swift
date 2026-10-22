#if BLIND_FAMILIAR_PEOPLE
import ARKit
import CoreImage
import CryptoKit
import Combine
import BlindCore
import ImageIO

struct FamiliarCapture {
    let image: CVPixelBuffer
    let capturedAt: Double
    let generation: UUID
    let camera: Point3
    let forward: Point3
}
private struct FamiliarAnalysis: Sendable {
    let faceCount: Int
    let centerX: Double
    let feature: [Float]
    let scores: [Double]
    let visionPrint: FamiliarVisionPrint?
    let visionDistances: [Double]?
    let quality: Float?
    let alignedRGB: Data
}
/// One serial owner of OpenCV; no frame history, network, or per-frame naming loop.
private actor FamiliarInference {
    private var engine: BAFaceEngine?
    private let context = CIContext(options: [.cacheIntermediates: false])
    private func load() throws -> BAFaceEngine {
        if let engine { return engine }
        let profile = FamiliarModelConfiguration.selected
        let assets = [(profile.detectorFilename, profile.detectorSHA256), (profile.recognizerFilename, profile.recognizerSHA256)]
        let paths = try assets.map { name, expected -> String in
            guard let url = Bundle.main.url(forResource: name, withExtension: nil),
                  try SHA256.hash(data: Data(contentsOf: url, options: .mappedIfSafe)).map({ String(format: "%02x", $0) }).joined() == expected
            else { throw FamiliarFaceStore.StoreError.unavailable }
            return url.path
        }
        let loaded = try BAFaceEngine(detectorPath: paths[0], recognizerPath: paths[1], backendKind: profile.backendKind)
        engine = loaded
        return loaded
    }
    func inspect(_ image: CVPixelBuffer, gallery: [FamiliarTemplate], dualPipeline: Bool, enrolling: Bool) throws -> FamiliarAnalysis {
        let oriented = CIImage(cvPixelBuffer: image).oriented(.right)
        guard let cg = context.createCGImage(oriented, from: oriented.extent) else { throw FamiliarFaceStore.StoreError.unavailable }
        return try inspect(cg, gallery: gallery, dualPipeline: dualPipeline, enrolling: enrolling)
    }
    func inspectPhoto(_ data: Data, dualPipeline: Bool) throws -> FamiliarAnalysis {
        guard data.count <= 20_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024, kCGImageSourceShouldCacheImmediately: false] as CFDictionary)
        else { throw FamiliarFaceStore.StoreError.invalid }
        return try inspect(image, gallery: [], dualPipeline: dualPipeline, enrolling: true)
    }
    private func inspect(_ cg: CGImage, gallery: [FamiliarTemplate], dualPipeline: Bool, enrolling: Bool) throws -> FamiliarAnalysis {
        try Task.checkCancellation()
        let engine = try load()
        let result = try engine.inspect(image: cg, includeAlignedFace: dualPipeline || enrolling)
        try Task.checkCancellation()
        var quality: Float?
        if enrolling, result.faceCount == 1 {
            guard result.faceWidth >= 80, result.faceHeight >= 80 else { throw FamiliarFaceStore.StoreError.invalid }
            quality = try FamiliarVisionComparison.captureQuality(alignedRGB: result.alignedRGB)
            // Laboratory capture filter, NOT calibrated identity confidence or spoof resistance.
            guard let quality, quality >= 0.25 else { throw FamiliarFaceStore.StoreError.invalid }
        }
        let scores = result.faceCount == 1 && !enrolling ? try engine.scores(feature: result.feature,
            gallery: gallery.map { $0.feature.map { NSNumber(value: $0) } }) : []
        var visionPrint: FamiliarVisionPrint?
        var visionDistances: [Double]?
        if dualPipeline, result.faceCount == 1 {
            let (probe, stored) = try FamiliarVisionComparison.printFace(alignedRGB: result.alignedRGB)
            visionPrint = stored
            if !enrolling { visionDistances = try FamiliarVisionComparison.distances(probe: probe, gallery: gallery) }
        }
        try Task.checkCancellation()
        return FamiliarAnalysis(faceCount: result.faceCount, centerX: result.centerX,
            feature: result.feature.map(\.floatValue), scores: scores.map(\.doubleValue),
            visionPrint: visionPrint, visionDistances: visionDistances, quality: quality,
            alignedRGB: enrolling ? result.alignedRGB : Data())
    }

}

/// Main-thread owned, matching NavigationModel and its .main ARSession delegate queue.
final class FamiliarFaceExperiment: ObservableObject {
    enum EnrollmentMode { case new, add, replace }
    private struct Draft {
        let id: UUID
        let token = UUID()
        let label: String
        let consentAt: Date
        var examples: [FamiliarExample]
        var previews: [UUID: Data] = [:] // Ephemeral aligned crops for sighted review; never written.
    }
    private enum Pending {
        case enable, begin(String, UUID?, EnrollmentMode), save
        case deletePerson(UUID), deleteExample(UUID, UUID)
    }
    @Published private(set) var enabled = false
    @Published private(set) var busy = false
    @Published private(set) var dualPipeline = false
    @Published private(set) var status = "Experimental comparison is off." { didSet { if !silenceStatus { onStatus?(status) } } }
    @Published private(set) var people: [FamiliarTemplate] = []
    @Published private(set) var draftLabel: String?
    @Published private(set) var enrollmentToken: UUID?
    @Published private(set) var draftExamples: [FamiliarExample] = []
    @Published private(set) var awaitingConfirmation = false
    @Published private(set) var reviewedPersonID: UUID?
    @Published var showPicker = false
    var presentationActive = false
    var hasActiveWork: Bool { busy || draft != nil || pending != nil || snapshotCapture != nil || resultCapture != nil || showPicker }
    var isSearching: Bool { searching }
    var operationRevision: UUID { generation }
    var onSearchStarted: (() -> Void)?
    var onSnapshotHint: ((String) -> Void)?
    var onStatus: ((String) -> Void)?
    var onCancelSpeech: (() -> Void)?
    private let store = FamiliarFaceStore()
    private let inference = FamiliarInference()
    private var generation = UUID()
    private var task: Task<Void, Never>?
    private var expiry: Task<Void, Never>?
    private var storageReady = false
    private var searching = false
    private var lastFaceGuidanceAt: Double?
    private var silenceStatus = false
    private var snapshotCapture: FamiliarCapture?
    private var resultCapture: FamiliarCapture?
    private var draft: Draft?
    private var pending: Pending?
    private var confirmation = FamiliarActionConfirmation()
    private var confirmationToken: UUID?
    var remainingExamples: Int { max(0, 6 - draftExamples.count) }
    var captureInstruction: String {
        switch draftExamples.count {
        case 0: return "Face the camera straight on, alone and well lit."
        case 1: return "Turn your head slightly left, keeping both eyes visible."
        case 2: return "Turn your head slightly right, keeping both eyes visible."
        default: return "You have at least three examples. Review and finish, or add a different well-lit view."
        }
    }
    func preview(_ id: UUID) -> CGImage? {
        draft?.previews[id].flatMap { try? FamiliarVisionComparison.faceImage(alignedRGB: $0) }
    }
    private func publishDraft() { draftLabel = draft?.label; enrollmentToken = draft?.token; draftExamples = draft?.examples ?? [] }
    private func cancelWork() {
        generation = UUID(); task?.cancel(); task = nil; expiry?.cancel(); expiry = nil; busy = false; searching = false
        resultCapture = nil; snapshotCapture = nil; onCancelSpeech?()
    }
    func cancel() {
        dispatchPrecondition(condition: .onQueue(.main))
        cancelWork(); pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false; draft = nil; publishDraft(); showPicker = false
        status = "Face action canceled. No unfinished examples were saved."
    }
    func reload() {
        cancel()
        do { people = try store.load(); storageReady = true; status = "Private gallery ready. \(people.count) saved people." }
        catch { people = []; storageReady = false; status = "Private gallery unavailable or from an older experiment. Unlock and retry, or delete this experimental gallery and re-enroll." }
    }
    func setEnabled(_ value: Bool) {
        cancel(); enabled = value
        if !value { dualPipeline = false }
        status = value ? "Experimental hints enabled. Say enroll person followed by a label, or who is this. Use your own judgment; hints can be wrong." : "Experimental comparison is off."
    }
    func setDualPipeline(_ value: Bool) {
        cancel(); dualPipeline = value
        status = value ? "Two-pipeline veto selected. All examples need compatible Apple prints. Re-enroll with consent. Agreement can still be wrong." : "Selected face-model baseline only."
    }
    private func ask(_ action: Pending, _ text: String) {
        cancelWork(); pending = action; confirmationToken = confirmation.request(now: ProcessInfo.processInfo.systemUptime); awaitingConfirmation = confirmationToken != nil
        status = text + " Say confirm face action, or cancel face action."
    }
    func requestEnable() {
        cancel()
        ask(.enable, "This is a first-stage, stationary supervised adult laboratory test, not authentication. It can name the wrong person. No navigation or safe-to-follow advice. Enable experimental hints for this visit?")
    }
    func requestEnrollment(label: String, mode: EnrollmentMode = .new) {
        guard enabled, storageReady else { status = "Enable the experiment and reload the private gallery first."; return }
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 60, !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            status = "Choose a short label such as Mom or Dad. Labels do not verify relationships."; return
        }
        let existing = people.first { $0.label.caseInsensitiveCompare(name) == .orderedSame }
        switch mode {
        case .new: guard existing == nil, people.count < 20 else { status = "That label already exists or the gallery is full. Use add or replace examples for an existing label."; return }
        case .add, .replace: guard existing != nil else { status = "No saved person has that label."; return }
        }
        let action = mode == .new ? "Enroll" : mode == .add ? "Add examples for" : "Replace all examples for"
        cancel()
        ask(.begin(existing?.label ?? name, existing?.id, mode), "\(action) label \(existing?.label ?? name)? Confirm this adult permits local face templates, including enabled extra prints, and these photos show only them. Originals are not saved or uploaded.")
    }
    func confirm() {
        guard let pending, let token = confirmationToken, confirmation.consume(token, now: ProcessInfo.processInfo.systemUptime) else {
            self.pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false; status = "No current confirmation, or it expired. Repeat the action."; return
        }
        self.pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false
        do {
            switch pending {
            case .enable: setEnabled(true)
            case let .begin(label, id, mode):
                guard enabled, storageReady else { throw FamiliarFaceStore.StoreError.unavailable }
                let originals = mode == .add ? people.first(where: { $0.id == id })?.examples ?? [] : []
                guard originals.count < 6 else { status = "Six examples already saved. Delete one or replace examples first."; return }
                draft = Draft(id: id ?? UUID(), label: label, consentAt: Date(), examples: originals)
                publishDraft(); status = "Consent recorded for label \(label). Collect at least three, at most six examples. \(captureInstruction) Say capture face, or import face photos."
            case .save:
                guard enabled, let draft, draft.examples.count >= 3,
                      FamiliarFacePolicy.normalizedMean(draft.examples.map(\.feature), expectedDimension: FamiliarModelConfiguration.selected.embeddingDimension) != nil else { throw FamiliarFaceStore.StoreError.invalid }
                let person = FamiliarTemplate(id: draft.id, label: draft.label, examples: draft.examples,
                    consent: "self-or-consenting-adult", consentAt: draft.consentAt)
                var updated = try store.load().filter { $0.id != draft.id }; updated.append(person)
                try store.save(updated); people = updated; self.draft = nil; publishDraft()
                status = "Saved \(person.examples.count) face examples under your label \(person.label). Hints can still be wrong."
            case .deletePerson(let id):
                let updated = try store.load().filter { $0.id != id }; try store.save(updated); people = updated
                status = "Person and all their examples deleted."
            case let .deleteExample(personID, exampleID):
                let loaded = try store.load()
                guard let person = loaded.first(where: { $0.id == personID }), person.examples.count > 1,
                      person.examples.contains(where: { $0.id == exampleID }) else { throw FamiliarFaceStore.StoreError.invalid }
                let replacement = FamiliarTemplate(id: person.id, label: person.label,
                    examples: person.examples.filter { $0.id != exampleID }, consent: person.consent, consentAt: person.consentAt)
                let updated = loaded.map { $0.id == person.id ? replacement : $0 }
                try store.save(updated); people = updated; status = "Example deleted for label \(person.label)."
            }
        } catch { status = "Action could not finish. Nothing is confirmed saved or deleted. Retry when private storage is available." }
    }
    func finishEnrollment() {
        guard let draft, !busy, draft.examples.count >= 3 else { status = "Collect at least three valid examples before finishing."; return }
        ask(.save, "Save \(draft.examples.count) examples for label \(draft.label)? Confirm every example shows the same consenting adult, not a bystander. This replaces the saved example set for that label.")
    }
    func requestDeletePerson(_ id: UUID) {
        guard let person = people.first(where: { $0.id == id }) else { return }
        cancel(); ask(.deletePerson(id), "Delete label \(person.label) and all \(person.examples.count) examples?")
    }
    func requestDeleteExample(_ personID: UUID, index: Int) {
        guard let person = people.first(where: { $0.id == personID }), person.examples.indices.contains(index), person.examples.count > 1 else {
            status = "Example unavailable, or it is the last one. Delete the person to remove their final example."; return
        }
        cancel(); ask(.deleteExample(personID, person.examples[index].id), "Delete example \(index + 1) for label \(person.label)?")
    }
    func removeDraftExample(_ id: UUID) {
        cancelWork(); pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false
        draft?.examples.removeAll { $0.id == id }; draft?.previews[id] = nil; publishDraft()
        status = "Unfinished example removed. \(draftExamples.count) examples remain."
    }
    func deleteAll() {
        cancel(); enabled = false; dualPipeline = false
        do { try store.deleteAll(); people = []; storageReady = true; status = "All experimental people and the encryption key were deleted." }
        catch { storageReady = false; people = []; status = "Deletion could not finish. Unlock the phone and retry." }
    }
    func review(_ label: String) {
        guard let person = people.first(where: { $0.label.caseInsensitiveCompare(label) == .orderedSame }) else { status = "No saved person has that label."; return }
        cancel(); reviewedPersonID = person.id
        let examples = person.examples.enumerated().map { "Example \($0.offset + 1), \($0.element.source == "camera" ? "camera" : "selected photo")" }.joined(separator: ". ")
        status = "Label \(person.label), \(person.examples.count) examples. \(examples). No original photos retained. Use the labeled controls to add, replace or delete."
    }
    private func accept(_ result: FamiliarAnalysis, source: String) throws {
        guard var draft, draft.examples.count < 6, result.faceCount == 1,
              FamiliarFacePolicy.validFeature(result.feature, expectedDimension: FamiliarModelConfiguration.selected.embeddingDimension), let quality = result.quality else { throw FamiliarFaceStore.StoreError.invalid }
        let example = FamiliarExample(id: UUID(), feature: result.feature, visionPrint: result.visionPrint,
            source: source, createdAt: Date(), quality: quality)
        // Do not accept identical descriptor copies as independent views.
        guard !draft.examples.contains(where: { $0.feature == example.feature }) else { throw FamiliarFaceStore.StoreError.invalid }
        draft.examples.append(example); draft.previews[example.id] = result.alignedRGB
        guard FamiliarFacePolicy.normalizedMean(draft.examples.map(\.feature), expectedDimension: FamiliarModelConfiguration.selected.embeddingDimension) != nil else { throw FamiliarFaceStore.StoreError.invalid }
        self.draft = draft; publishDraft()
    }
    func captureExample(model: NavigationModel) {
        guard enabled, draft != nil, !busy, remainingExamples > 0 else { status = "Begin consented enrollment first, or finish the current six examples."; return }
        guard let capture = model.captureFamiliarFace() else { status = "Need current portrait camera, calibrated monitoring and three seconds stationary. Then retry face capture."; return }
        cancelWork(); pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false
        let token = generation, useVision = dualPipeline; busy = true; status = "Capturing example \(draftExamples.count + 1). Hold still."
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await inference.inspect(capture.image, gallery: [], dualPipeline: useVision, enrolling: true)
                guard generation == token, !Task.isCancelled, enabled else { return }
                guard model.familiarCaptureIsCurrent(capture) else { throw FamiliarFaceStore.StoreError.invalid }
                try accept(result, source: "camera")
                status = "Accepted \(draftExamples.count) of at most six examples for \(draftLabel ?? "this label"). \(captureInstruction)"
            } catch {
                guard generation == token, !Task.isCancelled else { return }
                status = "Example not accepted. Need one sufficiently large, sharp, well-lit face. Move closer or improve lighting, then retry; no example was saved."
            }
            guard generation == token else { return }; busy = false; task = nil
        }
    }
    func requestPhotoImport() {
        guard enabled, draft != nil, !busy, remainingExamples > 0 else { status = "Begin consented enrollment before importing photos."; return }
        cancelWork(); pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false
        showPicker = true
        status = "Choose up to \(remainingExamples) photos of the same consenting adult alone in Apple's accessible photo picker. Voice commands cannot select its photos; use VoiceOver or the picker controls."
    }
    /// Called by the local system picker, one bounded image at a time. Not a live recognition route.
    func importPhotos(_ photos: [Data]) {
        guard !photos.isEmpty else { status = "No selected photos loaded. Retry with an available local still photo."; return }
        guard enabled, draft != nil, !busy, !photos.isEmpty, photos.count <= remainingExamples else { status = "No import started. Select no more than the remaining example slots."; return }
        cancelWork(); pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false
        let token = generation, useVision = dualPipeline; busy = true
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            var rejected = 0
            for (index, photo) in photos.enumerated() {
                guard generation == token, !Task.isCancelled, enabled else { return }
                status = "Checking selected photo \(index + 1) of \(photos.count) locally."
                do {
                    let result = try await inference.inspectPhoto(photo, dualPipeline: useVision)
                    guard generation == token, !Task.isCancelled, enabled else { return }
                    try accept(result, source: "selected-photo")
                } catch { rejected += 1 }
            }
            guard generation == token, !Task.isCancelled else { return }
            busy = false; task = nil
            status = "Import review: \(draftExamples.count) examples in the draft; \(rejected) selected photos rejected for missing, multiple, small, low-quality, duplicate or unusable faces. Review every accepted face and label before finishing."
        }
    }
    private func showFaceGuidance() {
        let text = "I can’t get a clear face view. You can call out to the person you’re looking for and ask them to look toward you. Then try again."
        let now = ProcessInfo.processInfo.systemUptime
        if FamiliarFacePolicy.shouldSpeakFaceGuidance(lastAt: lastFaceGuidanceAt, now: now) {
            lastFaceGuidanceAt = now; status = text
        } else { setSilentStatus(text) }
    }
    private func setSilentStatus(_ text: String) { silenceStatus = true; status = text; silenceStatus = false }
    func revalidate(model: NavigationModel) {
        if searching && (!model.running || model.detection.hazard != .observing) {
            cancelWork(); setSilentStatus("Named search canceled because monitoring context changed."); return
        }
        if let snapshotCapture, !model.familiarSnapshotContextIsCurrent(snapshotCapture) {
            cancelWork(); status = "Snapshot hint canceled. Ask again when stationary and the camera is current."
        } else if let resultCapture, !model.familiarCaptureIsCurrent(resultCapture) {
            self.resultCapture = nil; setSilentStatus("Live hint expired. The spoken hint refers only to the earlier snapshot.")
        }
    }
    func compare(model: NavigationModel) {
        cancelWork() // A fresh request always clears the previous candidate and snapshot speech.
        pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false
        guard enabled, !busy, draft == nil, storageReady, !people.isEmpty else { status = "Enable the experiment, finish or cancel enrollment, and ensure a person is saved first."; return }
        guard let capture = model.captureFamiliarFace() else { status = "Need a current tracked portrait camera and three seconds stationary. Calibrate monitoring and try again."; return }
        cancelWork(); pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false
        let token = generation, gallery = people, useVision = dualPipeline; busy = true; status = "Comparing locally."
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await inference.inspect(capture.image, gallery: gallery, dualPipeline: useVision, enrolling: false)
                guard generation == token, !Task.isCancelled, enabled else { return }
                busy = false; task = nil
                guard model.familiarCaptureIsCurrent(capture) else { status = "Hint expired or camera moved. Try again."; return }
                guard result.faceCount == 1, FamiliarFacePolicy.validFeature(result.feature, expectedDimension: FamiliarModelConfiguration.selected.embeddingDimension) else { showFaceGuidance(); return }
                guard let id = matchingID(result, gallery: gallery, useVision: useVision, requestID: token),
                      let match = gallery.first(where: { $0.id == id }) else { status = "Unknown or uncertain. Ask the person to speak."; return }
                publishSnapshot(match: match, result: result, capture: capture, token: token)

            } catch {
                guard generation == token, !Task.isCancelled else { return }
                busy = false; task = nil
                status = "Comparison unavailable or prints incompatible. No hint is confirmed. Retry or consent to re-enrollment."
            }
        }
    }
    private func matchingID(_ result: FamiliarAnalysis, gallery: [FamiliarTemplate], useVision: Bool, requestID: UUID) -> UUID? {
        let scored = zip(gallery, result.scores).map { (id: $0.0.id, cosine: $0.1) }
        guard result.scores.count == gallery.count,
              let id = FamiliarFacePolicy.candidateForAttempt(requestID: requestID, currentRequestID: generation,
                faceCount: result.faceCount, feature: result.feature, scores: scored,
                expectedDimension: FamiliarModelConfiguration.selected.embeddingDimension,
                cosineThreshold: FamiliarModelConfiguration.selected.cosineThreshold,
                minimumMargin: FamiliarModelConfiguration.selected.minimumMargin) else { return nil }
        if useVision {
            guard let distances = result.visionDistances, distances.count == gallery.count,
                  FamiliarFacePolicy.corroboratedCandidate(sface: id,
                    visionDistances: zip(gallery, distances).map { (id: $0.0.id, distance: $0.1) },
                    expectedIDs: Set(gallery.map(\.id))) == id else { return nil }
        }
        return id
    }
    private func publishSnapshot(match: FamiliarTemplate, result: FamiliarAnalysis, capture: FamiliarCapture, token: UUID) {
        expiry?.cancel(); searching = false
        resultCapture = capture; snapshotCapture = capture
        let position = result.centerX < 0.33 ? "left part" : result.centerX > 0.67 ? "right part" : "middle"
        setSilentStatus("Might be \(match.label), your saved label, in the \(position) of the camera image. I could be wrong. Ask them to speak and confirm for yourself.")
        onSnapshotHint?("Snapshot: might be \(match.label). Could be wrong. Ask them to speak.")
        let remaining = max(0, 1.5 - (ProcessInfo.processInfo.systemUptime - capture.capturedAt))
        expiry = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled, let self, generation == token else { return }
            resultCapture = nil
            setSilentStatus("Live hint expired. The spoken hint refers only to the earlier snapshot.")
            // Only the explicitly past-snapshot sentence may finish. No live direction speech.
            try? await Task.sleep(nanoseconds: 10_500_000_000)
            guard !Task.isCancelled, generation == token else { return }
            snapshotCapture = nil; onCancelSpeech?()
        }
    }
    /// Finite explicit named-label search, not passive or walking identity tracking.
    func find(_ label: String, model: NavigationModel) {
        cancelWork(); pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false
        guard enabled, storageReady, draft == nil,
              let target = people.first(where: { $0.label.caseInsensitiveCompare(label) == .orderedSame }) else {
            status = "Choose an exact saved label first. I do not infer who your parent is."; return
        }
        let token = generation, gallery = people, useVision = dualPipeline
        onSearchStarted?()
        busy = true; searching = true; setSilentStatus("Looking briefly for your saved label \(target.label).")
        expiry = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard !Task.isCancelled, let self, generation == token else { return }
            cancelWork(); setSilentStatus("Named search ended without a current hint. Ask again to retry.")
        }
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            let searchStarted = ProcessInfo.processInfo.systemUptime
            var budget = FamiliarSearchBudget(startedAt: searchStarted)
            var announcedMiss = false
            func reportFirstMiss() {
                guard !announcedMiss else { return }
                announcedMiss = true; status = "Can’t identify \(target.label) yet. Try calling \(target.label)."
            }
            for poll in 0..<10 {
                if poll > 0 { try? await Task.sleep(nanoseconds: 2_000_000_000) }
                guard !Task.isCancelled, generation == token, enabled else { return }
                let now = ProcessInfo.processInfo.systemUptime
                guard !budget.isExpired(now: now) else { break }
                // Quietly wait for a current stationary frame, never relax the existing gate.
                guard let capture = model.captureFamiliarFace() else { reportFirstMiss(); continue }
                guard budget.consumeAttempt(now: now) else { continue }
                do {
                    let result = try await inference.inspect(capture.image, gallery: gallery, dualPipeline: useVision, enrolling: false)
                    guard !Task.isCancelled, generation == token, enabled else { return }
                    guard ProcessInfo.processInfo.systemUptime - searchStarted <= 20 else { break }
                    guard model.familiarCaptureIsCurrent(capture),
                          matchingID(result, gallery: gallery, useVision: useVision, requestID: token) == target.id else { reportFirstMiss(); continue }
                    busy = false; task = nil
                    publishSnapshot(match: target, result: result, capture: capture, token: token)
                    return
                } catch {
                    guard !Task.isCancelled, generation == token else { return }
                    reportFirstMiss() // Never repeat failures or fall back to a cached name.
                }
            }
            guard !Task.isCancelled, generation == token else { return }
            expiry?.cancel(); expiry = nil; searching = false
            busy = false; task = nil; setSilentStatus("Named search ended without a current hint. This does not mean the person is absent. Ask again to retry.")
        }
    }
    func cancelSearchForNewGoal() {
        guard searching || snapshotCapture != nil else { return }
        cancelWork(); setSilentStatus("Face search canceled for the new question or goal.")
    }
    func handle(_ command: FamiliarPeopleCommand, model: NavigationModel) {
        if command != .confirm { pending = nil; confirmation.cancel(); confirmationToken = nil; awaitingConfirmation = false }
        switch command {
        case .open: requestEnable()
        case .recognize: compare(model: model)
        case .find(let label): find(label, model: model)
        case .enroll(let label): requestEnrollment(label: label)
        case .addExamples(let label): requestEnrollment(label: label, mode: .add)
        case .replaceExamples(let label): requestEnrollment(label: label, mode: .replace)
        case .review(let label): review(label)
        case .deletePerson(let label):
            guard let person = people.first(where: { $0.label.caseInsensitiveCompare(label) == .orderedSame }) else { status = "No saved person has that label."; return }
            requestDeletePerson(person.id)
        case .deleteExample(let index):
            guard let id = reviewedPersonID else { status = "Review the named person first."; return }
            requestDeleteExample(id, index: index - 1)
        case .capture, .retry: captureExample(model: model)
        case .importPhotos: requestPhotoImport()
        case .confirm: confirm()
        case .cancel: cancel()
        case .finishEnrollment: finishEnrollment()
        case .stop: setEnabled(false)
        }
    }
}
#endif
