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
                Text(t("These choices guide ordinary descriptions. Danger and mobility alerts remain active. A specific question can request any category.", "توجه هذه الخيارات الأوصاف العادية. تظل تنبيهات الخطر والحركة فعالة. يمكنك السؤال تحديداً عن أي فئة."))
            }
            Section(t("What would you like to hear about?", "ما الذي ترغب في سماع معلومات عنه؟")) {
                Text(t("For example: aquariums, room décor, blue clothing or vegetarian food. Your current question and goal take priority; interests do not hide other choices.", "مثلاً: أحواض الأسماك أو ديكور الغرفة أو الملابس الزرقاء أو الطعام النباتي. يتقدم سؤالك وهدفك الحاليان، ولا تُخفي الاهتمامات الخيارات الأخرى."))
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
                Text(t("Only preferences you add are used here. Online photo requests can share these interests after the send confirmation. Community-map exports do not include them.", "تُستخدم هنا التفضيلات التي تضيفها فقط. قد تشارك طلبات الصور عبر الإنترنت هذه الاهتمامات بعد تأكيد الإرسال. لا تتضمنها صادرات خرائط المجتمع."))
            }
        }.navigationTitle(t("Interests and preferences", "الاهتمامات والتفضيلات"))
    }
}
