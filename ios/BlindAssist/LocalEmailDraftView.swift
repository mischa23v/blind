import SwiftUI
import MessageUI

/// User-authored text only. Opening Apple's composer never sends a message.
/// The user reviews recipients/content there and explicitly presses Send.
struct LocalEmailDraftView: View {
    let arabic: Bool
    @State private var recipient = ""
    @State private var subject = ""
    @State private var message = ""
    @State private var history: [String] = []
    @State private var composer: ReviewedEmailDraft?
    @State private var status = ""
    private func t(_ en: String, _ ar: String) -> String { arabic ? ar : en }
    private var valid: Bool {
        !recipient.isEmpty && recipient.utf8.count <= 254 &&
        !recipient.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }) &&
        recipient.filter({ $0 == "@" }).count == 1 &&
        subject.utf8.count <= 500 && !subject.contains("\n") && !subject.contains("\r") &&
        message.utf8.count <= 32 * 1024 && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        Form {
            Text(t("Write and review your own draft. Nothing is sent automatically. Apple's Mail composer requires a configured account and may need a network connection to deliver.",
                   "اكتب مسودتك وراجعها. لا يتم إرسال شيء تلقائياً. تتطلب نافذة البريد حساباً معداً وقد تحتاج إلى اتصال لتسليم الرسالة."))
            TextField(t("Recipient email", "بريد المستلم"), text: $recipient)
                .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
            TextField(t("Subject", "الموضوع"), text: $subject)
            TextEditor(text: $message).frame(minHeight: 160)
                .accessibilityLabel(t("Message draft", "مسودة الرسالة"))
            Button(t("Save text checkpoint for undo", "احفظ نسخة من النص للتراجع")) {
                guard message.utf8.count <= 32 * 1024 else { return }
                history.append(message); if history.count > 5 { history.removeFirst() }
            }
            Button(t("Restore last text checkpoint", "استعد آخر نسخة من النص")) {
                if let previous = history.popLast() { message = previous }
            }.disabled(history.isEmpty)
            Button(t("Review in Mail — not send", "راجع في البريد — دون إرسال")) {
                guard valid, MFMailComposeViewController.canSendMail() else { return }
                composer = ReviewedEmailDraft(recipient: recipient, subject: subject, body: message)
                status = t("Handed to Mail for your review. Not sent by this app.", "تم فتح البريد للمراجعة. لم يرسل التطبيق الرسالة.")
            }.disabled(!valid || !MFMailComposeViewController.canSendMail() || composer != nil)
            if !MFMailComposeViewController.canSendMail() {
                Text(t("Mail handoff unavailable: no configured Mail account. You can still write, select and copy your local draft.",
                       "فتح البريد غير متاح: لا يوجد حساب بريد معد. يمكنك كتابة المسودة المحلية وتحديدها ونسخها."))
            }
            Text(t("Drafts and undo checkpoints are kept only on this page. They are not uploaded or restored after app termination.",
                   "تُحفظ المسودة ونسخ التراجع في هذه الصفحة فقط. لا تُرفع ولا تُستعاد بعد إغلاق التطبيق."))
            if !status.isEmpty { Text(status).accessibilityIdentifier("email-handoff-status") }
        }
        .navigationTitle(t("Email draft", "مسودة بريد"))
        .sheet(item: $composer) { draft in
            LocalMailComposer(draft: draft) { id, outcome in
                guard composer?.id == id else { return }
                switch outcome {
                case .cancelled: status = t("Cancelled in Mail. No send confirmed.", "أُلغي في البريد. لم يتأكد إرسال.")
                case .saved: status = t("Mail reports the draft saved. Not sent.", "أفاد البريد بحفظ المسودة. لم تُرسل.")
                case .sent: status = t("Mail accepted the message for sending. Delivery and receipt are not confirmed.", "قبل البريد الرسالة للإرسال. لم يتأكد التسليم أو الاستلام.")
                case .failed: status = t("Mail reported a failure. No successful send confirmed.", "أبلغ البريد عن خطأ. لم يتأكد إرسال ناجح.")
                @unknown default: status = t("Mail outcome unknown. No send confirmed.", "نتيجة البريد غير معروفة. لم يتأكد إرسال.")
                }
                composer = nil
            }.interactiveDismissDisabled()
        }
    }
}
private struct ReviewedEmailDraft: Identifiable {
    let id = UUID()
    let recipient, subject, body: String
}
private struct LocalMailComposer: UIViewControllerRepresentable {
    let draft: ReviewedEmailDraft
    let finish: (UUID, MFMailComposeResult) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(draft.id, finish) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([draft.recipient]); controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        return controller
    }
    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let id: UUID; let finish: (UUID, MFMailComposeResult) -> Void
        private var completed = false
        init(_ id: UUID, _ finish: @escaping (UUID, MFMailComposeResult) -> Void) { self.id = id; self.finish = finish }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            guard !completed else { return }; completed = true
            finish(id, error == nil ? result : .failed)
        }
    }
}
