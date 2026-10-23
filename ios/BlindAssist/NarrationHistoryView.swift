import SwiftUI
import BlindMemory

struct NarrationHistoryView: View {
    @ObservedObject var model: NavigationModel
    @State private var clearing = false
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    private func status(_ value: String) -> String {
        switch value {
        case "completed": return t("Spoken", "قيلت")
        case "interrupted": return t("Cut off, maybe not heard", "انقطعت، ربما لم تُسمع")
        case "pending": return t("Not finished yet", "لم تنتهِ بعد")
        default: return t("Not sure if heard", "غير متأكد إن سُمعت")
        }
    }
    var body: some View {
        List {
            Section {
                Text(t("The last 20 descriptions. They describe the past, not where things are now.", "آخر ٢٠ وصفاً. تصف ما مضى، لا أماكن الأشياء الآن."))
                if !model.narrationHistoryError.isEmpty { Text(model.narrationHistoryError) }
                Button(t("Clear description history", "مسح سجل الأوصاف"), role: .destructive) { clearing = true }
            }
            ForEach(model.narrationHistory) { record in
                // One VoiceOver stop per description: time, whether it was heard, and the words.
                Text(record.created.formatted(date: .abbreviated, time: .shortened) + ". " + status(record.outcome) + ". " + record.text)
            }
        }
        .navigationTitle(t("Recent descriptions", "الأوصاف الأخيرة"))
        .confirmationDialog(t("Clear saved description history on this phone?", "مسح سجل الأوصاف المحفوظ على هذا الهاتف؟"), isPresented: $clearing, titleVisibility: .visible) {
            Button(t("Clear history", "مسح السجل"), role: .destructive) { model.clearNarrationHistory() }
        }
    }
}
