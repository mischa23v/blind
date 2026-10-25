import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// The delegate is the result authority. Sheet dismissal is not cancellation:
/// a successful result may be delivered after the system dismisses its picker.
struct SelectedDocumentPicker: UIViewControllerRepresentable {
    let ownerID: UUID
    let onPicked: (UUID, URL) -> Void
    let onCancelled: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(ownerID: ownerID, onPicked: onPicked, onCancelled: onCancelled)
    }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    @MainActor final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let ownerID: UUID
        private let onPicked: (UUID, URL) -> Void
        private let onCancelled: (UUID) -> Void
        private var resolved = false
        init(ownerID: UUID, onPicked: @escaping (UUID, URL) -> Void,
             onCancelled: @escaping (UUID) -> Void) {
            self.ownerID = ownerID; self.onPicked = onPicked; self.onCancelled = onCancelled
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !resolved else { return }
            resolved = true
            guard urls.count == 1, let url = urls.first else { onCancelled(ownerID); return }
            onPicked(ownerID, url)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard !resolved else { return }
            resolved = true; onCancelled(ownerID)
        }
    }
}
