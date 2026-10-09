import SwiftUI
import BlindMemory

struct NarrationHistoryView: View {
    @ObservedObject var model: NavigationModel
    @State private var clearing = false
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    private func status(_ value: String) -> String {
        switch value {
        case "completed": return t("Speech reported complete", "أبلغ النظام عن اكتمال النطق")
        case "interrupted": return t("Interrupted — may not have been heard", "مقاطع — ربما لم يُسمع")
        case "pending": return t("Completion not yet confirmed", "لم يُؤكد الاكتمال بعد")
        default: return t("Completion unknown", "الاكتمال غير معروف")
        }
    }
    var body: some View {
        List {
            Section {
                Text(t("The last 20 dispatched descriptions. These are historical statements, not current directions. A completion signal does not prove understanding.", "آخر ٢٠ وصفاً أُرسل للنطق. هذه أقوال سابقة وليست إرشادات حالية. إشارة الاكتمال لا تثبت فهم الكلام."))
                if !model.narrationHistoryError.isEmpty { Text(model.narrationHistoryError) }
                Button(t("Clear description history", "مسح سجل الأوصاف"), role: .destructive) { clearing = true }
            }
            ForEach(model.narrationHistory) { record in
                VStack(alignment: .leading) {
                    Text(record.created, style: .date); Text(record.created, style: .time)
                    Text(status(record.outcome)).font(.headline)
                    Text(record.text)
                }
            }
        }
        .navigationTitle(t("Recent descriptions", "الأوصاف الأخيرة"))
        .confirmationDialog(t("Clear saved description history on this phone?", "مسح سجل الأوصاف المحفوظ على هذا الهاتف؟"), isPresented: $clearing, titleVisibility: .visible) {
            Button(t("Clear history", "مسح السجل"), role: .destructive) { model.clearNarrationHistory() }
        }
    }
}
