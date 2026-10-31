import SwiftUI
import MessageUI
import BlindCore

/// The existing user-authored helper and companion share one volatile draft.
/// The system Mail composer alone owns its explicit Send action; no send API.
struct LocalEmailDraftView: View {
    @ObservedObject var model: NavigationModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var opened = false
    @State private var owner: UUID?
    private var arabic: Bool { model.arabic }
    private func t(_ en: String, _ ar: String) -> String { arabic ? ar : en }
    private func binding(_ field: LocalEmailDraft.Field, expected: LocalEmailDraft.Snapshot) -> Binding<String> {
        Binding(get: {
            guard model.localEmailDraft.snapshot == expected else { return "" }
            let draft = expected
            switch field { case .recipient: return draft.content.recipient; case .subject: return draft.content.subject; case .body: return draft.content.body }
        }, set: { model.editLocalEmailField(field, text: $0, expected: expected) })
    }
    var body: some View {
        Form {
            Text(t("Write and review your own draft. Nothing is sent automatically. Apple's Mail composer requires a configured account and may need a network connection to deliver.",
                   "اكتب مسودتك وراجعها. لا يتم إرسال شيء تلقائياً. تتطلب نافذة البريد حساباً معداً وقد تحتاج إلى اتصال لتسليم الرسالة."))
            if let draft = model.localEmailDraft.snapshot, draft.id == owner {
                TextField(t("Recipient email", "بريد المستلم"), text: binding(.recipient, expected: draft))
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                    .disabled(model.localEmailDraft.handoff != nil)
                TextField(t("Subject", "الموضوع"), text: binding(.subject, expected: draft))
                    .disabled(model.localEmailDraft.handoff != nil)
                TextEditor(text: binding(.body, expected: draft)).frame(minHeight: 160)
                    .accessibilityLabel(t("Message draft", "مسودة الرسالة"))
                    .disabled(model.localEmailDraft.handoff != nil)
                Button(t("Save draft checkpoint for undo", "احفظ نسخة من المسودة للتراجع")) {
                    model.checkpointLocalEmailDraft(expected: draft)
                }.disabled(model.localEmailDraft.handoff != nil)
                Button(t("Restore last draft checkpoint", "استعد آخر نسخة من المسودة")) {
                    model.undoLocalEmailDraft(expected: draft)
                }.disabled(model.localEmailDraft.checkpointCount == 0 || model.localEmailDraft.handoff != nil)
                Button(t("Use this draft in typed companion commands", "استخدم هذه المسودة في أوامر المحادثة المكتوبة")) {
                    _ = model.enableLocalEmailCommands(draft)
                }.disabled(model.localEmailDraft.commandsEnabled || model.localEmailDraft.handoff != nil)
                Text(t("Typed commands: email draft recipient: your address; email draft subject: your words; replace email draft body: your words; append email draft body: your words. Read email draft recipient/subject/body; next or previous email draft part; undo email draft; discard email draft; review email draft in Mail. Raw microphone input cannot edit or read this private draft.",
                       "أوامر مكتوبة: مستلم مسودة البريد: عنوانك؛ موضوع مسودة البريد: كلماتك؛ استبدل نص مسودة البريد: كلماتك؛ أضف إلى نص مسودة البريد: كلماتك. اقرأ مستلم أو موضوع أو نص مسودة البريد؛ الجزء التالي أو السابق من مسودة البريد؛ تراجع عن تعديل مسودة البريد؛ احذف مسودة البريد؛ راجع مسودة البريد في تطبيق البريد. لا يمكن للميكروفون غير الموثق قراءة هذه المسودة أو تعديلها."))
                Button(t("Review in Mail — not send", "راجع في البريد — دون إرسال")) {
                    model.requestLocalEmailMailReview(expected: draft)
                }.disabled(!draft.content.permitsMailReview || !MFMailComposeViewController.canSendMail() || model.localEmailDraft.handoff != nil)
                Button(t("Discard local draft and checkpoints", "احذف المسودة المحلية ونسخ التراجع"), role: .destructive) {
                    model.discardLocalEmailDraft(expected: draft)
                }
            } else {
                Button(t("Start an empty local draft", "ابدأ مسودة محلية فارغة")) { owner = model.openLocalEmailDraft() }
            }
            if !MFMailComposeViewController.canSendMail() {
                Text(t("Mail handoff unavailable: no configured Mail account. You can still write, select and copy your local draft.",
                       "فتح البريد غير متاح: لا يوجد حساب بريد معد. يمكنك كتابة المسودة المحلية وتحديدها ونسخها."))
            }
            Text(t("Drafts and five undo checkpoints remain only on this phone in this session. Leaving this page discards them unless you explicitly enable companion commands or open Mail review. Stop, backgrounding, replacement or Discard clears the local draft. This cannot revoke a message or draft you already handed to Mail.",
                   "تبقى المسودة وخمس نسخ تراجع على هذا الهاتف في هذه الجلسة فقط. مغادرة الصفحة تحذفها ما لم تفعل الأوامر صراحةً أو تفتح مراجعة البريد. الإيقاف أو مغادرة التطبيق أو الاستبدال أو الحذف يمحو المسودة المحلية. لا يلغي ذلك رسالة أو مسودة سلمتها إلى البريد."))
            if !model.localEmailStatus.isEmpty { Text(model.localEmailStatus).accessibilityIdentifier("email-handoff-status") }
        }
        .navigationTitle(t("Email draft", "مسودة بريد"))
        .onAppear {
            if !opened { opened = true; owner = model.openLocalEmailDraft() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.clearLocalEmailDraft() } }
        .onDisappear { model.localEmailReaderDisappeared(owner: owner) }
    }
}

/// Reuses the existing MessageUI bridge, now with an exact immutable draft owner.
/// Only a current, explicitly requested snapshot is copied to the native composer.
struct LocalMailComposer: UIViewControllerRepresentable {
    let draft: LocalEmailDraft.Handoff
    let isCurrent: () -> Bool
    let finish: (UUID, LocalEmailDraft.MailOutcome) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(draft.id, finish) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        guard isCurrent() else { return controller }
        controller.setToRecipients([draft.snapshot.content.recipient])
        controller.setSubject(draft.snapshot.content.subject)
        controller.setMessageBody(draft.snapshot.content.body, isHTML: false)
        return controller
    }
    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let id: UUID; let finish: (UUID, LocalEmailDraft.MailOutcome) -> Void
        private var completed = false
        init(_ id: UUID, _ finish: @escaping (UUID, LocalEmailDraft.MailOutcome) -> Void) { self.id = id; self.finish = finish }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            guard !completed else { return }; completed = true
            guard error == nil else { finish(id, .failed); return }
            switch result {
            case .cancelled: finish(id, .cancelled)
            case .saved: finish(id, .saved)
            case .sent: finish(id, .queued) // accepted by Mail, not delivery or receipt
            case .failed: finish(id, .failed)
            @unknown default: finish(id, .unknown)
            }
        }
    }
}
