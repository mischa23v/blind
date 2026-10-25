// Authored platform/storage stubs only; production review and persistence bodies are extracted at execution.
import Foundation
@MainActor final class ExtractedScopedReviewUIActions {
 let model: ExtractedScopedReviewController
 let selection: CompanionWorkingState.ReviewSelection
 var replacement: String
 var failed = false, dismissed = false, saving = false
 init(model: ExtractedScopedReviewController, selection: CompanionWorkingState.ReviewSelection) {
  self.model = model; self.selection = selection; replacement = selection.report.text
 }
 func dismiss() { dismissed = true }
