import SwiftUI

/// Explore a picture by touch (Seeing AI-style): with VoiceOver on, moving a finger over the picture
/// reads what Vision found at that spot (text, people, a page, detector objects) and where it is.
/// The picture stays in memory only; it is never saved or sent. Nothing is guessed by a model.
struct ExplorePictureView: View {
    @ObservedObject var model: NavigationModel
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }

    private func position(_ rect: CGRect) -> String {
        let vertical = rect.midY < 0.33 ? t("top", "أعلى") : rect.midY > 0.66 ? t("bottom", "أسفل") : t("middle", "وسط")
        let horizontal = rect.midX < 0.33 ? t("left", "يسار") : rect.midX > 0.66 ? t("right", "يمين") : t("centre", "وسط")
        return model.arabic ? "\(vertical) \(horizontal) الصورة" : "\(vertical) \(horizontal) of the picture"
    }

    var body: some View {
        List {
            Section {
                Button(t("Take a new picture to explore", "التقط صورة جديدة للاستكشاف")) { model.captureExploreSnapshot() }
                    .accessibilityIdentifier("explore-capture")
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
                    Button(t("Forget this picture", "انسَ هذه الصورة"), role: .destructive) { model.clearExploreSnapshot() }
                } header: { Text(t("Everything found", "كل ما وُجد")) }
            }
        }
        .navigationTitle(t("Explore a picture", "استكشف صورة"))
        .onDisappear { model.clearExploreSnapshot() }
    }
}
