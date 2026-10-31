import SwiftUI
import UniformTypeIdentifiers
import BlindCore

/// Local reference reader; no model, network client, physical directions or
/// notification permission. Imported material is volatile and never uploaded.
struct LocalRecipeView: View {
    @ObservedObject var model: NavigationModel
    private var arabic: Bool { model.arabic }
    @Environment(\.scenePhase) private var scenePhase
    @State private var selecting = false
    @State private var pickerOwner: UUID?
    private var session: LocalRecipeSession? { model.localRecipe.session }
    @State private var status = ""
    private func t(_ en: String, _ ar: String) -> String { arabic ? ar : en }
    var body: some View {
        Form {
            Section {
                Text(t("Read a recipe you selected. Amounts and steps are quoted, not verified. This does not check allergies, appliances, safe handling or whether food is cooked.",
                       "اقرأ وصفة اخترتها. المقادير والخطوات من المصدر وليست مؤكدة. لا يتم التحقق من الحساسية أو الأجهزة أو سلامة التعامل أو نضج الطعام."))
                Button(t("Choose recipe JSON", "اختر ملف وصفة JSON")) {
                    pickerOwner = model.beginLocalRecipeSelection()
                    selecting = pickerOwner != nil
                }
                    .accessibilityIdentifier("choose-local-recipe")
                if !status.isEmpty { Text(status).accessibilityIdentifier("local-recipe-status") }
            }
            if let current = session {
                Section(t("Selected source", "المصدر المختار")) {
                    Text(current.recipe.title); Text(current.recipe.attribution)
                    if let selected = model.localRecipe.selection {
                        Button(t("Use this source in typed companion commands", "استخدم هذا المصدر في أوامر المحادثة المكتوبة")) {
                            _ = model.enableLocalRecipeCommands(selected)
                        }.disabled(model.localRecipe.enabled)
                        Text(model.localRecipe.enabled
                            ? t("Typed commands: read recipe step, next recipe step, previous recipe step, start recipe timer, recipe timer status, cancel recipe timer, forget recipe. Raw microphone input cannot control this private source.", "الأوامر المكتوبة: اقرأ خطوة الوصفة، الخطوة التالية في الوصفة، الخطوة السابقة في الوصفة، ابدأ مؤقت الوصفة، حالة مؤقت الوصفة، ألغ مؤقت الوصفة، انس الوصفة. لا يمكن للميكروفون غير الموثق التحكم في هذا المصدر الخاص.")
                            : t("The selected source stays on this page unless you explicitly enable companion commands. Enabling retains this exact local source until Stop, replacement, deletion, or leaving the app. Nothing is uploaded.", "يبقى المصدر في هذه الصفحة ما لم تفعل الأوامر صراحةً. التفعيل يحتفظ بهذا المصدر المحلي حتى الإيقاف أو الاستبدال أو الحذف أو مغادرة التطبيق. لا يتم رفع شيء."))
                    }
                    Button(t("Forget recipe and cancel timer", "انس الوصفة وألغ المؤقت")) { model.clearLocalRecipe(); status = "" }
                }
                Section(t("Ingredients as written", "المكونات كما وردت")) {
                    ForEach(Array(current.recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                        Text("\(ingredient.name): \(ingredient.quantity)")
                    }
                }
                Section(t("Source step \(current.stepIndex + 1) of \(current.recipe.steps.count)",
                          "خطوة المصدر \(current.stepIndex + 1) من \(current.recipe.steps.count)")) {
                    Text(current.step.text).accessibilityIdentifier("local-recipe-step")
                    Button(t("Previous source step", "الخطوة السابقة")) { model.localRecipeReaderCommand(.previousStep) }
                        .disabled(current.stepIndex == 0)
                    Button(t("Next source step", "الخطوة التالية")) { model.localRecipeReaderCommand(.nextStep) }
                        .disabled(current.stepIndex + 1 == current.recipe.steps.count)
                    Text(t("Changing steps cancels a running timer. It does not record that you performed the step.",
                           "تغيير الخطوة يلغي المؤقت الجاري، ولا يسجل أنك نفذت الخطوة."))
                }
                Section(t("Foreground timer", "مؤقت أثناء فتح التطبيق")) {
                    Text(t("No background alarm. Leaving this page, locking the phone or leaving the app cancels a running timer. Do not rely on it for cooking safety.",
                           "لا يوجد تنبيه في الخلفية. مغادرة الصفحة أو قفل الهاتف أو مغادرة التطبيق يلغي المؤقت الجاري. لا تعتمد عليه لسلامة الطهي."))
                    if let seconds = current.step.timerSeconds {
                        Button(t("Start \(seconds) second timer from source", "ابدأ مؤقت المصدر لمدة \(seconds) ثانية")) {
                            model.localRecipeReaderCommand(.startTimer)
                        }.disabled(current.timerState == .running)
                    }
                    Text(timerText(current)).accessibilityIdentifier("local-recipe-timer")
                    Button(t("Cancel timer", "إلغاء المؤقت")) { model.localRecipeReaderCommand(.cancelTimer) }
                        .disabled(current.timerState != .running)
                }
            }
        }
        .navigationTitle(t("Local recipe reference", "مرجع وصفة محلي"))
        .fileImporter(isPresented: $selecting, allowedContentTypes: [.json], allowsMultipleSelection: false) { [owner = pickerOwner] result in
            guard let owner, model.ownsLocalRecipeSelection(owner) else { return }
            // The original UI picker owner cannot be renewed after Stop/replacement.
            do {
                guard let url = try result.get().first else { model.cancelLocalRecipeSelection(owner); return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      let size = values.fileSize, size <= LocalRecipeReference.maximumBytes else { throw LocalRecipeReference.Invalid.malformed }
                let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                let data = try handle.read(upToCount: LocalRecipeReference.maximumBytes + 1) ?? Data()
                guard model.selectLocalRecipe(data, owner: owner) else { throw LocalRecipeReference.Invalid.malformed }
                status = t("Recipe selected. Companion access stays off until you explicitly enable it. Source text is not verified.", "تم اختيار الوصفة. تظل أوامر المحادثة متوقفة حتى تفعلها صراحةً. نص المصدر غير مؤكد.")
            } catch {
                model.cancelLocalRecipeSelection(owner)
                status = t("Recipe unavailable or invalid. Select a local JSON file in the supported recipe format. No previous recipe or timer remains active.",
                           "الوصفة غير متاحة أو غير صالحة. اختر ملف JSON محلياً بصيغة الوصفة المدعومة. لم تعد الوصفة أو المؤقت السابق نشطاً.")
            }
        }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                if scenePhase == .active { model.tickLocalRecipe() }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.clearLocalRecipe() } }
        .onDisappear { model.localRecipeReaderDisappeared() }
    }
    private func timerText(_ s: LocalRecipeSession) -> String {
        switch s.timerState {
        case .idle: return t("No timer started.", "لم يبدأ مؤقت.")
        case .running: return t("\(s.remainingSeconds ?? 0) seconds remaining.", "متبقي \(s.remainingSeconds ?? 0) ثانية.")
        case .elapsed: return t("Timer elapsed. This does not establish that food is ready.", "انتهت مدة المؤقت. هذا لا يؤكد أن الطعام جاهز.")
        case .cancelled: return t("Timer cancelled; no alarm will occur.", "تم إلغاء المؤقت؛ لن يصدر تنبيه.")
        case .invalidClock: return t("Timer unavailable after a clock discontinuity. Start a new timer explicitly.", "المؤقت غير متاح بعد تغير الساعة. ابدأ مؤقتاً جديداً صراحةً.")
        }
    }
}
