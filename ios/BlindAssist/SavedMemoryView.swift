import SwiftUI
import BlindCore

/// Everything the phone remembers about this person, in one place, with delete for each part.
/// All of it stays on this phone; nothing here is uploaded or backed up online.
struct SavedMemoryView: View {
    @ObservedObject var model: NavigationModel
    /// One pending deletion, confirmed before anything is removed.
    private enum Pending: Identifiable {
        case item(RememberedItem), roomPictures(id: String, name: String), room(id: String, name: String), hint(id: String, name: String), conversation, observations
        var id: String {
            switch self {
            case .item(let item): return "item:" + item.id
            case .roomPictures(let id, _): return "pictures:" + id
            case .room(let id, _): return "room:" + id
            case .hint(let id, _): return "hint:" + id
            case .observations: return "observations"
            case .conversation: return "conversation"
            }
        }
    }
    @State private var pending: Pending?
    private func t(_ english: String, _ arabic: String) -> String { model.arabic ? arabic : english }

    private func question(_ value: Pending) -> String {
        switch value {
        case .item(let item): return t("Delete \(item.name) and its pictures?", "حذف \(item.name) وصوره؟")
        case .roomPictures(_, let name): return t("Delete the pictures of \(name)?", "حذف صور \(name)؟")
        case .room(_, let name): return t("Forget \(name)?", "نسيان \(name)؟")
        case .hint(_, let name): return t("Remove \"\(name)\"?", "إزالة «\(name)»؟")
        case .observations: return t("Delete automatically remembered sightings?", "حذف المشاهدات المحفوظة تلقائياً؟")
        case .conversation: return t("Clear the goal, the conversation and what you told me about your things?", "مسح الهدف والمحادثة وما أخبرتني به عن أغراضك؟")
        }
    }
    private func perform(_ value: Pending) {
        switch value {
        case .item(let item): model.forgetItem(item)
        case .roomPictures(let id, _): model.forgetRoomPictures(id)
        case .room(let id, _): model.forgetRoom(id)
        case .hint(let id, _): model.removeHint(id)
        case .observations: model.clearObservedObjects()
        case .conversation: model.clearAssistantConversation()
        }
    }
    private func hintName(_ hint: LearnedHint) -> String {
        hint.kind == .describeRoom ? t("Don't offer room descriptions", "لا تعرض وصف الغرف") : t("Don't offer this again", "لا تعرض هذا مجدداً")
    }

    var body: some View {
        Form {
            Section {
                ForEach(model.savedItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text([item.name, item.roomName.map { t("in ", "في ") + $0 }, t("\(model.itemViewCount(item)) pictures", "\(model.itemViewCount(item)) صور")]
                            .compactMap { $0 }.joined(separator: ", "))
                            .font(.headline)
                        if let description = item.description { Text(description) }
                        Button(t("Delete \(item.name)", "حذف \(item.name)"), role: .destructive) { pending = .item(item) }
                    }
                }
                if model.savedItems.isEmpty {
                    Text(t("Nothing saved yet. Hold a thing and say: this is my cup.", "لا شيء محفوظ بعد. أمسك الغرض وقل: هذا كوبي."))
                }
            } header: { Text(t("My things", "أغراضي")) }
            Section {
                Text(model.objectAwarenessStatus)
                Text(t("\(model.rememberedObservationCount) candidate sightings remembered", "تم حفظ \(model.rememberedObservationCount) مشاهدات مرشحة"))
                ForEach(model.recentObjectObservations) { sighting in
                    Text([sighting.category, sighting.roomName, sighting.observedAt.formatted(date: .abbreviated, time: .shortened)]
                        .compactMap { $0 }.joined(separator: ", "))
                }
                Button(t("Delete sighting history", "حذف سجل المشاهدات"), role: .destructive) { pending = .observations }
            } header: { Text(t("Seen before", "شوهد سابقاً")) } footer: {
                Text(t("These are past observations, not confirmed current locations. With camera awareness on, new sightings may be remembered after clearing.", "هذه مشاهدات سابقة، وليست تأكيداً للمواقع الحالية. عندما تكون الكاميرا مفعلة، قد تُحفظ مشاهدات جديدة بعد المسح."))
            }
            Section {
                ForEach(model.savedRooms, id: \.id) { room in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.name + ", " + t("\(room.visits) visits", "\(room.visits) زيارات")).font(.headline)
                        Button(t("Delete pictures of \(room.name)", "حذف صور \(room.name)"), role: .destructive) { pending = .roomPictures(id: room.id, name: room.name) }
                        Button(t("Forget \(room.name)", "نسيان \(room.name)"), role: .destructive) { pending = .room(id: room.id, name: room.name) }
                    }
                }
                if model.savedRooms.isEmpty { Text(t("No rooms remembered yet.", "لا توجد غرف محفوظة بعد.")) }
            } header: { Text(t("Rooms", "الغرف")) }
            Section {
                ForEach(model.learnedHints) { hint in
                    Button(t("Remove: ", "إزالة: ") + hintName(hint), role: .destructive) { pending = .hint(id: hint.id, name: hintName(hint)) }
                }
                if model.learnedHints.isEmpty { Text(t("Nothing learned yet.", "لم يُتعلَّم شيء بعد.")) }
            } header: { Text(t("Learned habits", "العادات المتعلَّمة")) }
            Section {
                Button(t("Clear goal and conversation", "امسح الهدف والمحادثة"), role: .destructive) { pending = .conversation }
                NavigationLink(t("Recent descriptions", "الأوصاف الأخيرة")) { NarrationHistoryView(model: model) }
                NavigationLink(t("Interests", "الاهتمامات")) { AssistantPreferencesView(model: model) }
                #if BLIND_FAMILIAR_PEOPLE
                NavigationLink(t("Familiar people (test)", "الأشخاص المألوفون (تجربة)")) {
                    FamiliarPeopleView(model: model, experiment: model.familiarPeople)
                }
                #endif
            } header: { Text(t("Conversation and more", "المحادثة والمزيد")) } footer: {
                Text(t("Saved places, scans and journeys are in Places. Everything stays on this phone.", "الأماكن والمسوح والرحلات في تبويب الأماكن. كل شيء يبقى على هذا الهاتف."))
            }
        }
        .navigationTitle(t("Saved memory", "الذاكرة المحفوظة"))
        .confirmationDialog(pending.map(question) ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible, presenting: pending) { value in
            Button(t("Delete", "حذف"), role: .destructive) { perform(value); pending = nil }
        }
    }
}
