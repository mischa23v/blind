import Foundation
import BlindCore
final class ExtractedHistoricalIngress {
 var companionWorkingState = CompanionWorkingState()
 var arabic = false, message = "", sceneAnswer = "", currentReply = ""
 var taskCalls = 0, voiceCalls = 0, outputs: [String] = []
 var requestID = UUID()
 func interruptOrdinaryConversation(origin: CompanionCommandOrigin) {}
 func queueConversationSpeech(_ text: String, request: UUID, generation: UInt64, codeOwned: Bool) { outputs.append(text) }
 struct Session { var shouldListen = true; var generation: UInt64 = 1 }; var assistantSession = Session()
 struct Photo { var selection: Int? }; var selectedPhoto = Photo()
 func clearExploreSnapshot() { selectedPhoto.selection = nil }
 // Unrelated captured-page lane substitute: these history/search fixtures
 // have no selected page; actual review methods execute in their own witness.
 var capturedText = CapturedTextReference()
 func routeCapturedTextReview(_ text: String, origin: CompanionCommandOrigin) -> Bool { false }
 // Isolated history/search ingress seam, not PDF execution: only the real
 // strict Core command parser may consume trusted document command syntax.
 var documentCommands: [SelectedDocumentCommand] = []
 var documentClearCalls = 0
 func routeSelectedDocumentCommand(_ text: String, origin: CompanionCommandOrigin) -> Bool {
  guard origin == .trustedInterface, let command = SelectedDocumentCommand.parse(text) else { return false }
  documentCommands.append(command); return true
 }
 func clearSelectedDocument() { documentClearCalls += 1 }
 func stopReadingTool(announce: Bool) { capturedText.clear() }
 func routeClockInquiry(_ text: String, origin: CompanionCommandOrigin) -> Bool { false }
 func receiveUnverifiedConversation(_ text: String, origin: CompanionCommandOrigin) { voiceCalls += 1 }
 static func wordCount(_ text: String) -> Int { CompanionReferenceReading.wordCount(text) }
 func speakRequested(_ text: String) -> Bool { outputs.append(text); return true }
