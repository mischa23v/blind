#if BLIND_FAMILIAR_PEOPLE
import SwiftUI
import PhotosUI

struct FamiliarPeopleView: View {
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
    var body: some View {
        Form {
            Section("Experimental familiar-person hints") {
                Text("A tentative hint, not authentication. Current enrollment uses consenting adults for supervised stationary lab tests. Mac and phone checks are pending; supervised child-user feasibility comes later. An earlier baseline offline benchmark falsely named 7 of 200 unknown-person photos. Photos or screens may fool it. No safe-to-follow, trust or navigation advice.")
                Text("Only one consenting adult in each capture or selected photo. Crowds are unsupported: a detector can miss another person even when it reports one face. Position means the camera image, never your body's direction or distance.")
                Toggle("I understand the limits and have sighted supervision for this first-stage test", isOn: $acknowledged)
                    .accessibilityIdentifier("familiar-disclosure")
                    .onChange(of: acknowledged) { _, value in if !value { experiment.setEnabled(false) } }
                Toggle("Enable experimental hints for this visit", isOn: Binding(get: { experiment.enabled }, set: { experiment.setEnabled($0) }))
                    .disabled(!acknowledged).accessibilityIdentifier("familiar-enable")
                Button("Hear limits and confirm by voice") { experiment.requestEnable() }
                Text("Off by default and when leaving. Templates and labels stay encrypted on this phone, excluded from backups. No app uploads. Original or aligned photos are not saved by this app; selected photos remain in your Photos library.")
                Text("Start camera monitoring and complete calibration before camera enrollment. Starting or stopping a camera session cancels unfinished face work. Existing-photo enrollment does not require camera monitoring.")
                Button(model.running ? "Stop live camera" : "Start live camera monitoring") { if model.running { model.stop() } else { model.start() } }
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
            Section("Current action") {
                Text(experiment.status).accessibilityIdentifier("familiar-status")
                if experiment.awaitingConfirmation {
                    Button("Confirm exact spoken face action") { experiment.confirm() }.accessibilityIdentifier("familiar-confirm")
                    Text("Confirmation expires after 30 seconds. Confirm the exact label, consent and operation you just heard.")
                }
                Button("Compare the face now") { experiment.compare(model: model) }
                    .disabled(!experiment.enabled || experiment.busy || photoLoading).accessibilityIdentifier("familiar-compare")
                Text("Named search checks for at most 20 seconds and six fresh comparisons, quietly between attempts. It still requires calibrated portrait monitoring and three seconds stationary; it does not recognize while walking. Looking toward a chest-worn phone does not guarantee a face is visible.")
                Text("The hint might be wrong. Ask the person to speak and recognize them yourself; this is not your only way to identify anyone.")
            }
            Section("Enroll a consenting adult") {
                TextField("Your label, such as Mom or Dad", text: $label).accessibilityIdentifier("familiar-label")
                Button("Begin enrollment and hear consent confirmation") { experiment.requestEnrollment(label: label) }
                    .disabled(!experiment.enabled || experiment.busy || photoLoading).accessibilityIdentifier("familiar-consent")
                Text("Child enrollment is unavailable in this build. Enroll only the adult who permits these examples. Imported photos cannot establish consent or a family relationship. All examples must show the same adult alone.")
            }
            if let draftLabel = experiment.draftLabel {
                Section("Review unfinished examples for \(draftLabel)") {
                    Text("\(experiment.draftExamples.count) of 6 examples. At least 3 required to finish. \(experiment.captureInstruction)")
                    Button("Capture face · next angle") { experiment.captureExample(model: model) }
                        .disabled(experiment.busy || photoLoading || experiment.remainingExamples == 0).accessibilityIdentifier("familiar-capture")
                    Button("Import existing photos from this phone") { experiment.requestPhotoImport() }
                        .disabled(experiment.busy || photoLoading || experiment.remainingExamples == 0).accessibilityIdentifier("familiar-import")
                    Text("Apple's accessible Photos picker selects up to the remaining six-example limit. Voice can open it but cannot choose its photos. System Photos may need to download an existing iCloud original; unavailable offline selections fail without an app upload. Maximum 20 MB per selected still image.")
                    if photoLoading { ProgressView("Loading selected photos locally") }
                    if !photoLoadError.isEmpty { Text(photoLoadError) }
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
                    Text("Enrollment checks for one detected face, at least 80-pixel face width/height, and Apple capture quality at least 0.25. These are uncalibrated lab filters, not identity confidence or spoof protection. A rejection asks you to retry; it never enrolls a bystander automatically.")
                    Button("Review label and finish enrollment") { experiment.finishEnrollment() }
                        .disabled(experiment.busy || photoLoading || experiment.draftExamples.count < 3).accessibilityIdentifier("familiar-finish-enrollment")
                }
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
        .navigationTitle("Familiar people · experiment")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(model.voice.listening ? "Finish speaking" : "Speak face command") { toggleVoice() }
                    .accessibilityIdentifier("familiar-voice")
                Button("Cancel", role: .cancel) { cancelPhotoLoad(); experiment.cancel(); model.voice.cancel() }
                Button("Retry capture") { experiment.captureExample(model: model) }.disabled(experiment.draftLabel == nil || experiment.busy)
            }.padding().background(.regularMaterial)
        }
        .accessibilityAction(.magicTap) { toggleVoice() }
        .photosPicker(isPresented: $experiment.showPicker, selection: $selectedPhotos,
            maxSelectionCount: max(1, experiment.remainingExamples), matching: .images, preferredItemEncoding: .current)
        .onChange(of: experiment.enrollmentToken) { _, _ in cancelPhotoLoad() }
        .onChange(of: selectedPhotos) { _, selected in loadPhotos(selected) }
        .onAppear { experiment.presentationActive = true; if !experiment.enabled && !experiment.awaitingConfirmation { experiment.reload() } }
        .onDisappear { experiment.presentationActive = false; cancelPhotoLoad(); experiment.setEnabled(false); model.voice.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelPhotoLoad(); experiment.setEnabled(false); acknowledged = false; model.voice.cancel() }
        }
        .confirmationDialog("Delete every experimental face template and label on this phone?", isPresented: $confirmDeleteAll) {
            Button("Delete all experimental people", role: .destructive) { cancelPhotoLoad(); experiment.deleteAll() }
        }
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
