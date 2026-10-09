import SwiftUI
import BlindCore

/// Everything the phone remembers about this person, in one place, with delete for each part.
/// All of it stays on this phone; nothing here is uploaded or backed up online.
struct SavedMemoryView: View {
    @ObservedObject var model: NavigationModel
    private func t(_ english: String, _ arabic: String) -> String { model.arabic ? arabic : english }

    var body: some View {
        Form {
            Section {
                Text(t("Saved on this phone only. Delete anything at any time.", "محفوظ على هذا الهاتف فقط. احذف أي شيء في أي وقت."))
            }
            Section(t("My things", "أغراضي")) {
                if model.savedItems.isEmpty {
                    Text(t("No saved items. Say: this is my cup, while holding it.", "لا أغراض محفوظة. قل: هذا كوبي، وأنت تمسكه."))
                }
                ForEach(model.savedItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.headline)
                        if let room = item.roomName { Text(t("Saved in: ", "محفوظ في: ") + room) }
                        Text(t("Views saved: ", "صور محفوظة: ") + "\(model.itemViewCount(item))")
                        if let description = item.description { Text(description).foregroundStyle(.secondary) }
                        Button(t("Delete", "حذف"), role: .destructive) { model.forgetItem(item) }
                            .accessibilityLabel(t("Delete \(item.name)", "حذف \(item.name)"))
                    }
                    .accessibilityElement(children: .contain)
                }
            }
            Section(t("Rooms", "الغرف")) {
                if model.savedRooms.isEmpty { Text(t("No rooms remembered yet.", "لا توجد غرف محفوظة بعد.")) }
                ForEach(model.savedRooms, id: \.id) { room in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.name).font(.headline)
                        Text(t("Visits: ", "الزيارات: ") + "\(room.visits)")
                        Button(t("Delete room pictures", "حذف صور الغرفة"), role: .destructive) { model.forgetRoomPictures(room.id) }
                            .accessibilityLabel(t("Delete pictures of \(room.name)", "حذف صور \(room.name)"))
                        Button(t("Forget this room", "نسيان هذه الغرفة"), role: .destructive) { model.forgetRoom(room.id) }
                            .accessibilityLabel(t("Forget \(room.name)", "نسيان \(room.name)"))
                    }
                    .accessibilityElement(children: .contain)
                }
            }
            Section(t("Learned habits", "العادات المتعلَّمة")) {
                if model.learnedHints.isEmpty { Text(t("Nothing learned yet.", "لم يُتعلَّم شيء بعد.")) }
                ForEach(model.learnedHints) { hint in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hint.kind == .describeRoom ? t("Don't offer room descriptions", "لا تعرض وصف الغرف")
                                                        : t("Don't offer: ", "لا تعرض: ") + hint.scope)
                        Button(t("Remove", "إزالة"), role: .destructive) { model.removeHint(hint.id) }
                    }
                }
            }
        }
        .navigationTitle(t("Saved memory", "الذاكرة المحفوظة"))
    }
}
