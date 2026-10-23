#if BLIND_FAMILIAR_PEOPLE
import SwiftUI
import PhotosUI
import AVFoundation

/// A short People landing page; experimental controls are only in the helper workflow.
struct FamiliarPeopleView: View {
    @ObservedObject var model: NavigationModel
    @ObservedObject var experiment: FamiliarFaceExperiment
    private func t(_ english: String, _ arabic: String) -> String { model.arabic ? arabic : english }
    var body: some View {
        List {
            Section(t("Saved people", "الأشخاص المحفوظون")) {
                if experiment.people.isEmpty { Text(t("No people saved yet.", "لا يوجد أشخاص محفوظون بعد.")) }
                ForEach(experiment.people) { person in
                    NavigationLink(person.label) { FamiliarPeopleToolsView(model: model, experiment: experiment) }
                        .frame(minHeight: 44)
                }
            }
            NavigationLink(t("Add person", "أضف شخصاً")) { FamiliarPeopleToolsView(model: model, experiment: experiment) }
                .frame(minHeight: 44).accessibilityIdentifier("familiar-add-person")
            Text(t("Use a sighted helper, but keep the phone with the child. Ask the adult being added to face the child and change their own angle. A familiar-person hint can be wrong.", "استعن بمساعد مبصر مع إبقاء الهاتف مع الطفل. اطلب من الشخص البالغ المراد إضافته مواجهة الطفل وتغيير زاويته بنفسه. قد يخطئ التعرف على الشخص المألوف."))
        }
        .navigationTitle(t("People", "الأشخاص"))
        .onAppear { experiment.prepareForForegroundSession() }
    }
}

private struct FamiliarPeopleToolsView: View {
    @ObservedObject var model: NavigationModel
    @ObservedObject var experiment: FamiliarFaceExperiment
    @Environment(\.scenePhase) private var scenePhase
    @State private var acknowledged = false
    @State private var label = ""
    @State private var confirmDeleteAll = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoLoading = false
    @State private var photoLoadError = ""
    @State private var photoGeneration = UUID()
    @State private var photoTask: Task<Void, Never>?
    @State private var awaitingCameraForEnrollment = false
    var body: some View {
        Form {
            Section("Add a person with a helper") {
                Text("For now, enroll only a consenting adult with sighted supervision. Keep the phone with the child throughout. The adult being added faces the child and changes their own angle when asked. Familiar-person hints can be wrong; ask the person to speak. Templates stay on this phone.")
                if !experiment.enabled {
                    Button("Turn familiar-person hints back on") { experiment.requestEnable() }
                        .frame(minHeight: 44).accessibilityIdentifier("familiar-guided-enable")
                }
            }
            Section("Current action") {
                Text(experiment.status).accessibilityIdentifier("familiar-status")
                if !photoLoadError.isEmpty { Text(photoLoadError) }
                if experiment.awaitingConfirmation {
                    Button("Confirm exact spoken face action") { experiment.confirm() }.accessibilityIdentifier("familiar-confirm")
                    Text("Confirmation expires after 30 seconds. Confirm the exact label, consent and operation you just heard.")
                }
                Button("Compare the face now") { experiment.compare(model: model) }
                    .disabled(!experiment.enabled || experiment.busy || photoLoading).accessibilityIdentifier("familiar-compare")
            }
            if !experiment.hasEnrollmentDraft {
            Section("1. Take photos") {
                Button(model.cameraAwareness ? "Take photos of a person" : "Turn on camera and take photos") {
                    if model.running { experiment.requestUnnamedEnrollment() }
                    else { startCameraForEnrollment() }
                }
                    .disabled(!experiment.enabled || experiment.busy || photoLoading).accessibilityIdentifier("familiar-consent")
                Button("Use photos already on this phone") { experiment.requestUnnamedEnrollment() }
                    .disabled(!experiment.enabled || experiment.busy || photoLoading)
                if awaitingCameraForEnrollment { Text("Waiting for camera permission or startup. You can cancel at any time.") }
                if !model.running { Text(model.message) }
                Text("Child enrollment is unavailable in this build. Enroll only the adult who permits these examples. Imported photos cannot establish consent or a family relationship. All examples must show the same adult alone.")
            }
            }
            if experiment.hasEnrollmentDraft {
                Section("1. Take three clear photos") {
                    Text("\(experiment.draftExamples.count) of 6 examples. At least 3 required to finish. \(experiment.captureInstruction)")
                    Button("Capture face · next angle") { experiment.captureExample(model: model) }
                        .disabled(experiment.busy || photoLoading || experiment.remainingExamples == 0).accessibilityIdentifier("familiar-capture")
                    Button("Import existing photos from this phone") { experiment.requestPhotoImport() }
                        .disabled(experiment.busy || photoLoading || experiment.remainingExamples == 0).accessibilityIdentifier("familiar-import")
                    Text("Apple's accessible Photos picker selects up to the remaining six-example limit. Voice can open it but cannot choose its photos. System Photos may need to download an existing iCloud original; unavailable offline selections fail without an app upload. Maximum 20 MB per selected still image.")
                    if photoLoading { ProgressView("Loading selected photos locally") }
                    ForEach(Array(experiment.draftExamples.enumerated()), id: \.element.id) { index, example in
                        VStack(alignment: .leading) {
                            Text("Example \(index + 1): \(example.source == "camera" ? "camera capture" : "selected photo")")
                            if let image = experiment.preview(example.id) {
                                Image(image, scale: 1, label: Text("Temporary aligned face preview")).resizable().scaledToFit().frame(maxHeight: 160)
                                    .accessibilityLabel("Temporary aligned face preview for example \(index + 1). A sighted helper must verify it shows the intended consenting adult.")
                            }
                            Button("Remove unfinished example \(index + 1)", role: .destructive) { experiment.removeDraftExample(example.id) }
                        }
                    }
                    Text("Only one consenting adult in each photo. The adult adjusts their own position; the child keeps the phone. If a photo is unclear, try again.")
                }
                if experiment.draftExamples.count >= 3 {
                    Section("2. Name and save") {
                        TextField("Their name, such as Mom or Dad", text: $label).accessibilityIdentifier("familiar-label")
                            .onChange(of: label) { _, value in
                                // Editing cannot leave an old named-save confirmation active.
                                if value.trimmingCharacters(in: .whitespacesAndNewlines) != experiment.draftLabel {
                                    experiment.cancelSaveConfirmation()
                                }
                            }
                        Button("Save person") {
                            if experiment.setDraftLabel(label) { experiment.finishEnrollment() }
                        }
                        .disabled(experiment.busy || photoLoading || label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("familiar-finish-enrollment")
                        Text("Review the name and photos, then confirm the save above.")
                    }
                }
            }
            Section {
                NavigationLink("Helper setup and full limitations") { helperDetails }
                    .frame(minHeight: 44).accessibilityIdentifier("familiar-helper-setup")
            }
            Section("Private gallery") {
                Button("Reload private gallery") { cancelPhotoLoad(); experiment.reload() }
                ForEach(experiment.people) { person in
                    VStack(alignment: .leading) {
                        Text("\(person.label): \(person.examples.count) examples")
                        Button("Look for \(person.label) briefly") { experiment.find(person.label, model: model) }
                        Button("Review \(person.label)") { experiment.review(person.label) }
                        Button("Add examples for \(person.label)") { experiment.requestEnrollment(label: person.label, mode: .add) }
                        Button("Replace examples for \(person.label)") { experiment.requestEnrollment(label: person.label, mode: .replace) }
                        ForEach(Array(person.examples.enumerated()), id: \.element.id) { index, example in
                            Button("Delete example \(index + 1) for \(person.label)", role: .destructive) { experiment.requestDeleteExample(person.id, index: index) }
                        }
                        Button("Delete person \(person.label)", role: .destructive) { experiment.requestDeletePerson(person.id) }
                    }
                }
                Text("Saved-example review lists capture metadata, not photographs. Original photos are not retained. Delete-all also removes the encryption key; flash storage is not securely overwritten.")
                Button("Delete all experimental people", role: .destructive) { confirmDeleteAll = true }.accessibilityIdentifier("familiar-delete-all")
            }
        }
        .navigationTitle("Add or manage a person")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(model.voice.listening ? "Finish speaking" : "Speak face command") { toggleVoice() }
                    .accessibilityIdentifier("familiar-voice")
                Button("Cancel", role: .cancel) { awaitingCameraForEnrollment = false; cancelPhotoLoad(); experiment.cancel(); model.voice.endManualTurn() }
                Button("Retry capture") { experiment.captureExample(model: model) }.disabled(!experiment.hasEnrollmentDraft || experiment.busy)
            }.padding().background(.regularMaterial)
        }
        .accessibilityAction(.magicTap) { toggleVoice() }
        .photosPicker(isPresented: $experiment.showPicker, selection: $selectedPhotos,
            maxSelectionCount: max(1, experiment.remainingExamples), matching: .images, preferredItemEncoding: .current)
        .onChange(of: experiment.enrollmentToken) { _, _ in cancelPhotoLoad() }
        .onChange(of: selectedPhotos) { _, selected in loadPhotos(selected) }
        .onChange(of: model.running) { _, running in
            if running && awaitingCameraForEnrollment { awaitingCameraForEnrollment = false; experiment.requestUnnamedEnrollment() }
        }
        .onChange(of: model.message) { _, _ in
            if !model.running && (AVCaptureDevice.authorizationStatus(for: .video) == .denied || AVCaptureDevice.authorizationStatus(for: .video) == .restricted || !model.supported) {
                awaitingCameraForEnrollment = false
            }
        }
        .onChange(of: experiment.draftLabel) { _, name in if let name { label = name } }
        .onAppear { experiment.presentationActive = true; experiment.prepareForForegroundSession() }
        .onDisappear { awaitingCameraForEnrollment = false; cancelPhotoLoad(); experiment.leaveEnrollmentScreen(); model.voice.endManualTurn() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { awaitingCameraForEnrollment = false; cancelPhotoLoad(); experiment.leaveEnrollmentScreen(); model.voice.endManualTurn() }
        }
        .confirmationDialog("Delete every experimental face template and label on this phone?", isPresented: $confirmDeleteAll) {
            Button("Delete all experimental people", role: .destructive) { cancelPhotoLoad(); experiment.deleteAll() }
        }
    }
    private func startCameraForEnrollment() {
        guard model.supported, !model.textOnly else {
            photoLoadError = "Live camera enrollment is unavailable on this device or in text-only mode. Use existing photos instead."
            return
        }
        awaitingCameraForEnrollment = true
        // The button explicitly says it turns the camera on. Merely visiting People
        // never changes a previously saved camera-off choice.
        if !model.cameraAwareness { model.cameraAwareness = true } else { model.start() }
        if AVCaptureDevice.authorizationStatus(for: .video) == .denied || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
            awaitingCameraForEnrollment = false
        }
    }

    private var helperDetails: some View {
        Form {
            Section("Experimental familiar-person hints") {
                Text("A tentative hint, not authentication. Current enrollment uses consenting adults for supervised stationary lab tests. Mac and phone checks are pending; supervised child-user feasibility comes later. An earlier baseline offline benchmark falsely named 7 of 200 unknown-person photos. Photos or screens may fool it. No safe-to-follow, trust or navigation advice.")
                Text("Enrollment needs one consenting adult in each photo. Recognition checks up to two detected faces per pass, rotating through up to 32 faces. Larger crowds are unsupported. A detector can miss people. Position means the camera image, never your body's direction or distance.")
                Toggle("I understand the limits and have sighted supervision for this first-stage test", isOn: $acknowledged)
                    .accessibilityIdentifier("familiar-disclosure")
                    .onChange(of: acknowledged) { _, value in if !value { experiment.setEnabled(false) } }
                Toggle("Automatic familiar-person hints", isOn: Binding(get: { experiment.enabled }, set: { experiment.setEnabled($0) }))
                    .disabled(!acknowledged && !experiment.enabled).accessibilityIdentifier("familiar-enable")
                Button(experiment.enabled ? "Hear current recognition setting" : "Hear limits and confirm by voice") { experiment.requestEnable() }
                Text("Consented saved people are checked automatically when your foreground camera and monitoring are ready, including outside this screen. No separate helper enable step is needed. A newly recognized person gets one tentative notice, not repeated chatter. Your explicit on or off choice is saved across visits and restarts. You can always turn hints off here or say stop familiar people. Templates and labels stay encrypted on this phone, excluded from backups. No app uploads. Original or aligned photos are not saved by this app; selected photos remain in your Photos library.")
                Text("Start camera monitoring and complete calibration before camera enrollment. Starting or stopping a camera session cancels unfinished face work. Existing-photo enrollment does not require camera monitoring.")
                Button(model.running ? "Stop live camera" : "Turn on live camera monitoring") {
                    if model.running { model.cameraAwareness = false }
                    else if !model.cameraAwareness { model.cameraAwareness = true }
                    else { model.start() }
                }
            }
            Section("Voice and gesture controls") {
                Text("Tap Speak, or use VoiceOver's two-finger double-tap here, to start or finish the existing offline speech input. Say familiar people; enroll person Mom; confirm face action; capture face; import face photos; finish face enrollment; who is this; find person Mom; review person Mom; add face examples for Mom; replace face examples for Mom; delete person Mom; cancel face action; or stop familiar people. Mom and Dad are labels you choose, never inferred relationships. Generic yes or no does not confirm a face action.")
                Text(model.voice.message)
                if !model.voice.transcript.isEmpty { Text(model.voice.transcript) }
            }
            Section("Build-selected experimental model") {
                Text("\(FamiliarModelConfiguration.selected.backendKind): cosine floor \(FamiliarModelConfiguration.selected.cosineThreshold), margin \(FamiliarModelConfiguration.selected.minimumMargin). These were selected on separate still-photo calibration, not validated for this multi-example phone workflow.")
            }
            Section("Optional second pipeline") {
                Toggle("Also require Apple image-similarity agreement", isOn: Binding(get: { experiment.dualPipeline }, set: { experiment.setDualPipeline($0) }))
                    .disabled(!experiment.enabled).accessibilityIdentifier("familiar-dual-pipeline")
                Text("Off by default. Uses the same aligned face crop, not whole-scene clothing or surroundings. Agreement can only retain the selected face-model candidate; Both can agree on the wrong person. Every example needs compatible prints. Generic image distance 0.3 and margin 0.1 are uncalibrated. No improvement has been measured on Apple hardware. These settings may reject every face.")
            }
        }
        .navigationTitle("Helper setup")
    }
    private func toggleVoice() { if model.voice.listening { model.voice.finish() } else { model.startVoiceQuestion() } }
    private func cancelPhotoLoad() { photoGeneration = UUID(); photoTask?.cancel(); photoTask = nil; photoLoading = false; selectedPhotos = [] }
    private func loadPhotos(_ selected: [PhotosPickerItem]) {
        guard !selected.isEmpty, let enrollmentToken = experiment.enrollmentToken else { return }
        let id = UUID(); photoGeneration = id; photoLoading = true; photoLoadError = ""
        photoTask?.cancel()
        photoTask = Task { @MainActor in
            var data: [Data] = []
            for item in selected.prefix(6) {
                guard !Task.isCancelled, photoGeneration == id else { return }
                if let image = try? await item.loadTransferable(type: Data.self), image.count <= 20_000_000 { data.append(image) }
                else { photoLoadError = "One or more photos were unavailable, too large, or not transferable. No app upload occurred." }
            }
            guard !Task.isCancelled, photoGeneration == id, experiment.enabled, experiment.enrollmentToken == enrollmentToken else { return }
            photoLoading = false; selectedPhotos = []; experiment.importPhotos(data)
        }
    }
}
#endif
