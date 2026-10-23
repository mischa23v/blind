import SwiftUI
import PhotosUI

/// Explore a picture by touch (Seeing AI-style): with VoiceOver on, moving a finger over the picture
/// reads what Vision found at that spot (text, people, a page, detector objects) and where it is.
/// The picture stays in memory only; it is never saved or sent. Nothing is guessed by a model.
struct ExplorePictureView: View {
    @ObservedObject var model: NavigationModel
    @State private var photo: PhotosPickerItem?
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var photoLoadGeneration = UUID()
    @State private var presentationActive = false
    @State private var photoLoadFailed = false
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }

    private func position(_ rect: CGRect) -> String {
        let vertical = rect.midY < 0.33 ? t("top", "أعلى") : rect.midY > 0.66 ? t("bottom", "أسفل") : t("middle", "وسط")
        let horizontal = rect.midX < 0.33 ? t("left", "يسار") : rect.midX > 0.66 ? t("right", "يمين") : t("centre", "وسط")
        return model.arabic ? "\(vertical) \(horizontal) الصورة" : "\(vertical) \(horizontal) of the picture"
    }

    var body: some View {
        List {
            Section {
                Button(t("Take a new picture to explore", "التقط صورة جديدة للاستكشاف")) {
                    cancelPhotoLoad()
                    photo = nil
                    model.captureExploreSnapshot()
                }
                    .accessibilityIdentifier("explore-capture")
                // A library photo is read on this phone only and never saved by the app.
                PhotosPicker(selection: $photo, matching: .images) { Text(t("Describe a photo from my library", "صف صورة من مكتبتي")) }
                    .accessibilityIdentifier("explore-library")
                if photoLoadTask != nil {
                    ProgressView(t("Opening photo…", "جارٍ فتح الصورة…"))
                        .accessibilityIdentifier("explore-loading")
                }
                if photoLoadFailed {
                    Text(t("I couldn't open that photo. Please choose it again.", "تعذر فتح الصورة. اخترها مرة أخرى من فضلك."))
                        .accessibilityIdentifier("explore-load-error")
                }
                if !model.sceneAnswer.isEmpty, model.exploreSnapshot != nil { Text(model.sceneAnswer) }
            }
            .onChange(of: photo) { _, item in
                guard let item, presentationActive else { return }
                cancelPhotoLoad()
                // Invalidate any previous Vision work before awaiting the new library transfer.
                model.clearExploreSnapshot()
                let generation = photoLoadGeneration
                let sessionGeneration = model.assistantSession.generation
                photoLoadTask = Task { @MainActor in
                    let data = try? await item.loadTransferable(type: Data.self)
                    // A cancelled Photos transfer can still return. Only this visible presentation's
                    // latest request may start model work or change the selection/loading state.
                    guard !Task.isCancelled, presentationActive, photoLoadGeneration == generation else { return }
                    photoLoadTask = nil
                    photo = nil
                    guard model.assistantSession.foregroundActive,
                          model.assistantSession.generation == sessionGeneration else { return }
                    guard let data, let image = UIImage(data: data) else {
                        photoLoadFailed = true
                        return
                    }
                    model.explorePhoto(image)
                }
            }
            if let snapshot = model.exploreSnapshot {
                Section {
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: snapshot.image).resizable().accessibilityHidden(true)
                        GeometryReader { geometry in
                            ForEach(snapshot.regions.indices, id: \.self) { index in
                                let region = snapshot.regions[index]
                                Rectangle()
                                    .stroke(Color.yellow, lineWidth: 3)
                                    .contentShape(Rectangle())
                                    .frame(width: max(24, region.rect.width * geometry.size.width),
                                           height: max(24, region.rect.height * geometry.size.height))
                                    .position(x: region.rect.midX * geometry.size.width, y: region.rect.midY * geometry.size.height)
                                    .accessibilityElement()
                                    .accessibilityLabel(region.label + ", " + position(region.rect))
                            }
                        }
                    }
                    .aspectRatio(snapshot.image.size.width / max(1, snapshot.image.size.height), contentMode: .fit)
                } header: { Text(t("Touch the picture", "المس الصورة")) } footer: {
                    Text(t("Only what the phone detected is listed. It may miss things.", "تُذكر فقط الأشياء التي رصدها الهاتف، وقد يفوته بعضها."))
                }
                Section {
                    ForEach(snapshot.regions.indices, id: \.self) { index in
                        Text(snapshot.regions[index].label + ", " + position(snapshot.regions[index].rect))
                    }
                    if snapshot.regions.isEmpty { Text(t("No text or people found.", "لم يُعثر على نص أو أشخاص.")) }
                    Button(t("Forget this picture", "انسَ هذه الصورة"), role: .destructive) {
                        cancelPhotoLoad()
                        photo = nil
                        model.clearExploreSnapshot()
                    }
                } header: { Text(t("Everything found", "كل ما وُجد")) }
            }
        }
        .navigationTitle(t("Explore a picture", "استكشف صورة"))
        .onAppear {
            cancelPhotoLoad()
            presentationActive = true
        }
        .onDisappear {
            presentationActive = false
            cancelPhotoLoad()
            photo = nil
            model.clearExploreSnapshot()
        }
    }

    private func cancelPhotoLoad() {
        photoLoadGeneration = UUID()
        photoLoadTask?.cancel()
        photoLoadTask = nil
        photoLoadFailed = false
    }
}
