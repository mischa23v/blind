import SwiftUI
import BlindCore

struct AssistantPreferencesView: View {
    @ObservedObject var model: NavigationModel
    @State private var category = "interest"
    @State private var value = ""
    private func t(_ en: String, _ ar: String) -> String { model.arabic ? ar : en }
    var body: some View {
        Form {
            Section(t("Automatic information", "المعلومات التلقائية")) {
                ForEach(AssistantPreferences.categories, id: \.self) { category in
                    let names = ["social": t("People and activity", "الأشخاص والنشاط"), "signs": t("Signs and text", "اللافتات والنص"),
                                 "objects": t("Objects and choices", "الأشياء والخيارات"), "decor": t("Art and décor", "الفن والديكور"), "interests": t("Personal interests", "الاهتمامات الشخصية")]
                    Picker(names[category] ?? category, selection: Binding(get: { model.assistantPreferences.mode(for: category) },
                        set: { model.setAssistantCategory(category, mode: $0) })) {
                        Text(t("Automatic", "تلقائي")).tag("automatic")
                        Text(t("When I ask", "عندما أسأل")).tag("onRequest")
                        Text(t("Only when I ask specifically", "فقط عندما أسأل عنه تحديداً")).tag("muted")
                    }
                }
                Text(t("Danger alerts always stay on. You can still ask about anything.", "تنبيهات الخطر تبقى دائماً. يمكنك السؤال عن أي شيء."))
            }
            Section(t("What would you like to hear about?", "ما الذي ترغب في سماع معلومات عنه؟")) {
                Text(t("For example: fish tanks, blue clothes or vegetarian food.", "مثلاً: أحواض السمك أو الملابس الزرقاء أو الطعام النباتي."))
                Picker(t("Category", "الفئة"), selection: $category) {
                    Text(t("Personal interest", "اهتمام شخصي")).tag("interest")
                    Text(t("Shopping", "التسوق")).tag("shopping")
                    Text(t("Food", "الطعام")).tag("food")
                    Text(t("Description preference", "تفضيل الوصف")).tag("description")
                }
                TextField(t("Your preference", "تفضيلك"), text: $value, axis: .vertical)
                    .accessibilityIdentifier("interest-value")
                Button(t("Save this preference", "حفظ هذا التفضيل")) {
                    if model.addAssistantInterest(category: category, value: value) { value = "" }
                }.accessibilityIdentifier("interest-save")
                if !model.preferenceError.isEmpty { Text(model.preferenceError) }
            }
            Section(t("Saved on this phone", "محفوظ على هذا الهاتف")) {
                ForEach(model.assistantPreferences.interests) { interest in
                    VStack(alignment: .leading) {
                        Text(interest.value)
                        Button(t("Remove this preference", "إزالة هذا التفضيل"), role: .destructive) { model.removeAssistantInterest(id: interest.id) }
                            .accessibilityLabel(t("Remove preference: ", "إزالة التفضيل: ") + interest.value)
                    }
                }
                Text(t("Stays on this phone. Never shared in community maps.", "يبقى على هذا الهاتف. لا يُشارك في خرائط المجتمع أبداً."))
                #if BLIND_DEVELOPER_CLOUD
                Text("Developer build: an online photo request can include these after its send confirmation.")
                #endif
            }
        }.navigationTitle(t("Interests", "الاهتمامات"))
    }
}
