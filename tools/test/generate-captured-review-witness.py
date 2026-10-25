from pathlib import Path
import sys
root=Path(sys.argv[1]); output=Path(sys.argv[2])
s=(root/'ios/BlindAssist/NavigationModel.swift').read_text()
names=['clearCapturedText','purgeCapturedTextPlayback','capturedTextContext','revalidateCapturedText','capturedTextPlaybackAllowed','cancelCapturedTextBudgetWake','capturedTextPacingChanged','scheduleCapturedTextBudgetWake','speakNextCapturedText','capturedTextSpeechPermission','finishCapturedTextSpeech','pauseCapturedTextPlayback','offerCapturedTextReviewGuidance','routeCapturedTextReview','stopReadingTool','repeatHomeInformation']
functions=[]
for name in names:
 pos=s.index('func '+name+'(');a=s.rfind('\n',0,pos)+1;b=s.index('\n    }',pos)+6
 functions.append(s[a:b].replace('private func','func'))
header='''import Foundation
import XCTest
// Extracted NavigationModel methods; platform/session/budget/sink substitutes below.
// This executes production controller bodies, NOT UIKit, ARKit, Vision or audio.
struct Session { var generation: UInt64 = 3; var foregroundActive = true; var mayRespond = true; var privateAudioHeld = false }
struct Hazard: Equatable { var isUrgent = false; static let observing = Hazard() }; struct Detection { var hazard = Hazard() }
struct Voice { var awaitingUtterance = false }
struct Work { mutating func cancel() {} }
struct Stability { mutating func reset() {} }
struct Companion {
 var release: Double = 0
 mutating func nextInformationBudgetTime(words: Int, settings: Int, now: Double) -> Double? { max(now, release) }
}
final class Sink {
 var speechPriority: SpeechPriority?
 var stopped: [UUID] = []
 var onStop: ((UUID) -> Void)?
 func stopRequestedSpeech(_ id: UUID) { stopped.append(id); onStop?(id) }
 func stopInformation(announceCancellation: Bool) -> Bool { true }
}
final class Witness {
 // Document dispatch is outside this captured-page witness. Real Core owner,
 // narrow picker/display placeholders and a counted guidance seam preserve the
 // extracted production Repeat priority without claiming PDF/audio execution.
 var selectedDocument = SelectedDocumentReference()
 var selectedDocumentImportOwner: UUID?
 var selectedDocumentDisplay: String?
 var documentRepeats = 0
 func repeatSelectedDocumentGuidance() { documentRepeats += 1 }
 var capturedText = CapturedTextReference()
 var capturedTextSpeechIDs = Set<UUID>()
 var capturedTextReviewGuidanceEligible = true
 var capturedTextReviewNotice: (id: UUID,text: String,selection: UUID)?
 var lastCapturedTextPlaybackReceipt: CapturedTextReference.PlaybackReceipt?
 var capturedTextBudgetWake: Task<Void,Never>?
 var capturedTextBudgetWakeAt: Double?
 var cameraTextEpoch = UUID(), requestID = UUID()
 var assistantSession = Session(), detection = Detection(), voice = Voice(), companion = Companion()
 let feedback = Sink()
 var textOnly = false, arabic = false, companionSettings = 30
 var readingTool: ReadingTool? = .document
 var readingWork = Work(), documentStability = Stability()
 var readingTask: Task<Void,Never>?
 var readingInFlight = false
 var documentOrigin: Int?, documentSpeechID: UUID?
 var documentChunks: [String] = []
 var usesCapturedText: Bool { readingTool == .liveText || readingTool == .document }
 var dispatched: [(UUID,String)] = []
 var plainReplies: [String] = []
 var admission = true
 var running = false, currentReply = "", narrationHistory: [Int] = []
 struct ClockReceipt { var text: String }; var currentClockReceipt: ClockReceipt?
 var genericRepeats = 0
 var homePrompt = "Generic prompt"
 func revalidateClockReplies() {}
 func repeatMonitoringStatus() { genericRepeats += 1 }
 func repeatDescription() { genericRepeats += 1 }
 func capturedTextCameraAllowed() -> Bool { false }
 func clearBoardingReading() {}
 @discardableResult func speakOperation(_ text: String) -> Bool { plainReplies.append(text); return true }
 @discardableResult func speakRequested(_ text: String, replace: Bool = true) -> Bool {
  guard admission, companion.release <= ProcessInfo.processInfo.systemUptime, feedback.speechPriority == nil else { return false }
  plainReplies.append(text); return true
 }
 static func wordCount(_ text: String) -> Int { CompanionReferenceReading.wordCount(text) }
 func dispatchText(_ text: String, kind: InformationCandidate.Kind, requested: Bool, replace: Bool, speechID: UUID) -> Bool {
  guard admission, capturedTextSpeechPermission(id: speechID,text: text) else { return false }
  dispatched.append((speechID,text)); return true
 }
 func install() {
  let now = ProcessInfo.processInfo.systemUptime
  let selected = capturedText.select(cameraEpoch: cameraTextEpoch,generation: assistantSession.generation,requestID: requestID,issuedAt: now,capturedAt: now,orientation: 6,now: now)!
  let identity = CompanionReferenceIdentity(sourceID: selected.id,revision: UUID(),sha256: String(repeating:"a",count:64),media:.capturedText)
  let text = (1...60).map { "word\\($0)" }.joined(separator:" ")
  let e = CompanionEvidence(id:"line",kind:.historicalMemory,text:text,source:identity.evidenceSource)
  let source = CompanionReferenceSource(identity:identity,toolResult:.init(status:.success,source:identity.evidenceSource,evidence:[e]),blocks:[.init(evidence:e,bodyUTF16Range:NSRange(location:0,length:text.utf16.count),locator:"line")])
  XCTAssertTrue(capturedText.install(source,for:selected,now:now))
 }
 func completePage() {
  speakNextCapturedText()
  while let p = capturedText.pending { XCTAssertTrue(finishCapturedTextSpeech(id:p.id,text:p.text,outcome:.completed)) }
 }
}
'''
header=header.replace('\n}\n', '\n'+ '\n'.join(functions)+'\n}\n',1) if False else header
# Insert extracted bodies just before Witness closing brace.
pos=header.rfind('\n}')
header=header[:pos]+'\n'+'\n'.join(functions)+header[pos:]
tests='''
final class NativeReviewWitnessTests: XCTestCase {
 func testCompletionRetainsWithoutFreshCameraThenNewReplayAndOldCallback() {
  let w = Witness(); w.install(); w.completePage()
  XCTAssertNil(w.readingTool); XCTAssertNotNil(w.capturedText.source)
  let prior = w.lastCapturedTextPlaybackReceipt!; XCTAssertEqual(prior.outcome,.completed)
  let notice = w.capturedTextReviewNotice!
  XCTAssertTrue(w.routeCapturedTextReview("repeat the last part",origin:.trustedInterface))
  let p = w.capturedText.pending!; XCTAssertNotEqual(w.requestID,prior.requestID)
  XCTAssertEqual(w.lastCapturedTextPlaybackReceipt,prior)
  XCTAssertTrue(w.finishCapturedTextSpeech(id:notice.id,text:notice.text,outcome:.completed))
  XCTAssertEqual(w.capturedText.pending,p); XCTAssertEqual(w.capturedText.completed,0)
 }
 func testSynchronousCancellationCannotAdvanceReplacement() {
  let w = Witness(); w.install(); w.speakNextCapturedText(); let old = w.capturedText.pending!
  XCTAssertTrue(w.capturedText.started(id:old.id,text:old.text,context:w.capturedTextContext()!))
  w.feedback.onStop = { id in _ = w.finishCapturedTextSpeech(id:id,text:old.text,outcome:.completed) }
  XCTAssertTrue(w.routeCapturedTextReview("repeat current part",origin:.trustedInterface))
  XCTAssertEqual(w.capturedText.completed,0); XCTAssertNotEqual(w.capturedText.pending!.id,old.id)
  XCTAssertEqual(w.capturedText.pending!.text,old.text)
 }
 func testNoAutomaticResumeAfterInterruptionButExplicitReviewWorks() {
  let w = Witness(); w.install(); w.speakNextCapturedText(); let p = w.capturedText.pending!
  XCTAssertTrue(w.capturedText.started(id:p.id,text:p.text,context:w.capturedTextContext()!))
  XCTAssertTrue(w.finishCapturedTextSpeech(id:p.id,text:p.text,outcome:.interrupted))
  w.revalidateCapturedText(); XCTAssertNil(w.capturedText.pending); XCTAssertNotNil(w.capturedText.source)
  XCTAssertTrue(w.routeCapturedTextReview("repeat last spoken part",origin:.trustedInterface)); XCTAssertNotNil(w.capturedText.pending)
 }
 func testBudgetWaitIsRetiredAndNewAttemptWaitsNotCompletion() {
  let w = Witness(); w.install(); w.completePage()
  w.companion.release = ProcessInfo.processInfo.systemUptime + 3600
  XCTAssertTrue(w.routeCapturedTextReview("read captured text again",origin:.trustedInterface))
  let firstOwner = w.capturedText.selection!.id
  XCTAssertNotNil(w.capturedTextBudgetWakeAt); XCTAssertNil(w.capturedText.pending)
  XCTAssertTrue(w.routeCapturedTextReview("read captured text again",origin:.trustedInterface))
  XCTAssertNotEqual(w.capturedText.selection!.id,firstOwner); XCTAssertNotNil(w.capturedTextBudgetWakeAt)
  XCTAssertEqual(w.capturedText.completed,0)
  w.purgeCapturedTextPlayback(); XCTAssertNil(w.capturedTextBudgetWake); XCTAssertNil(w.capturedText.source)
 }
 func testPrivacyHazardAndForgetClearEveryRetainedOwner() {
  for mode in 0..<6 {
   let w = Witness(); w.install(); w.completePage()
   let notice = w.capturedTextReviewNotice!
   switch mode {
   case 0: w.assistantSession.privateAudioHeld = true
   case 1: w.assistantSession.foregroundActive = false
   case 2: w.assistantSession.generation += 1
   case 3: w.detection.hazard.isUrgent = true
   case 4: w.cameraTextEpoch = UUID()
   default: break
   }
   _ = w.routeCapturedTextReview(mode == 5 ? "forget this page" : "read captured text again",origin:.trustedInterface)
   XCTAssertNil(w.capturedText.source); XCTAssertNil(w.capturedTextReviewNotice)
   XCTAssertTrue(w.finishCapturedTextSpeech(id:notice.id,text:notice.text,outcome:.completed))
   XCTAssertNil(w.capturedText.source)
  }
 }
 func testUntrustedInputCannotReadOrForgetAndUnstartedCannotRepeat() {
  let w = Witness(); w.install(); w.speakNextCapturedText(); let p = w.capturedText.pending!
  XCTAssertFalse(w.routeCapturedTextReview("forget this page",origin:.unverifiedMicrophone))
  XCTAssertEqual(w.capturedText.pending,p)
  XCTAssertTrue(w.routeCapturedTextReview("repeat last spoken part",origin:.trustedInterface))
  XCTAssertEqual(w.capturedText.pending,p); XCTAssertNotNil(w.capturedText.source)
 }
 func testContextualRepeatControlAndGenericFallback() {
  let w = Witness(); w.install(); w.speakNextCapturedText(); let p = w.capturedText.pending!
  XCTAssertTrue(w.capturedText.started(id:p.id,text:p.text,context:w.capturedTextContext()!))
  w.narrationHistory = [1]; w.repeatHomeInformation()
  XCTAssertEqual(w.genericRepeats,0); XCTAssertEqual(w.capturedText.pending!.text,p.text)
  XCTAssertNotEqual(w.capturedText.pending!.id,p.id)
  w.purgeCapturedTextPlayback(); w.repeatHomeInformation(); XCTAssertEqual(w.genericRepeats,1)
  let privatePage = Witness(); privatePage.install(); privatePage.assistantSession.privateAudioHeld = true
  privatePage.narrationHistory = [1]; privatePage.repeatHomeInformation()
  XCTAssertNil(privatePage.capturedText.source); XCTAssertEqual(privatePage.genericRepeats,0)
  let hazardPage = Witness(); hazardPage.install(); hazardPage.detection.hazard.isUrgent = true
  hazardPage.repeatHomeInformation(); XCTAssertNil(hazardPage.capturedText.source); XCTAssertEqual(hazardPage.genericRepeats,1)
 }
 func testEarlyRepeatPreservesBudgetWakeWhenStatusDenied() {
  let w = Witness(); w.install(); w.companion.release = ProcessInfo.processInfo.systemUptime + 3600
  w.speakNextCapturedText(); let owner = w.capturedText.selection!.id, wake = w.capturedTextBudgetWakeAt
  XCTAssertNotNil(wake); XCTAssertNil(w.capturedText.pending)
  XCTAssertTrue(w.routeCapturedTextReview("repeat",origin:.trustedInterface))
  XCTAssertTrue(w.plainReplies.isEmpty); XCTAssertEqual(w.capturedText.selection!.id,owner)
  XCTAssertEqual(w.capturedTextBudgetWakeAt,wake); XCTAssertFalse(w.capturedText.paused)
  w.companion.release = 0; w.cancelCapturedTextBudgetWake(); w.revalidateCapturedText()
  XCTAssertNotNil(w.capturedText.pending)
 }
 func testDocumentRepeatPriorityDoesNotFallThroughToCapturedOrPersistedHistory() {
  for mode in 0..<3 {
   let w = Witness(); w.install(); w.narrationHistory = [1]
   if mode == 0 {
    let identity = CompanionReferenceIdentity(sourceID:UUID(),revision:UUID(),sha256:String(repeating:"a",count:64),media:.selectedDocument)
    XCTAssertNotNil(w.selectedDocument.select(identity:identity,pageCount:1,generation:3,now:ProcessInfo.processInfo.systemUptime))
   } else if mode == 1 { w.selectedDocumentImportOwner = UUID() }
   else { w.selectedDocumentDisplay = "Fixed PDF guidance" }
   let capturedOwner = w.capturedText.selection
   w.repeatHomeInformation()
   XCTAssertEqual(w.documentRepeats,1); XCTAssertEqual(w.genericRepeats,0)
   XCTAssertEqual(w.capturedText.selection,capturedOwner); XCTAssertNil(w.capturedText.pending)
   XCTAssertTrue(w.plainReplies.isEmpty)
  }
 }
 func testGuidanceHasOneOpportunityNotOneTipPerReview() {
  let w = Witness(); w.install(); w.completePage()
  XCTAssertNotNil(w.capturedTextReviewNotice); XCTAssertFalse(w.capturedTextReviewGuidanceEligible)
  XCTAssertTrue(w.routeCapturedTextReview("repeat that part",origin:.trustedInterface))
  let p = w.capturedText.pending!; XCTAssertTrue(w.finishCapturedTextSpeech(id:p.id,text:p.text,outcome:.completed))
  XCTAssertNil(w.capturedTextReviewNotice)
  XCTAssertTrue(w.routeCapturedTextReview("read captured text again",origin:.trustedInterface))
  w.completePage(); XCTAssertNil(w.capturedTextReviewNotice)
  // An initial rejected tip consumes its opportunity, not a delivery receipt.
  let rejected = Witness(); rejected.install(); rejected.speakNextCapturedText()
  while let part = rejected.capturedText.pending {
   if rejected.capturedText.completed == rejected.capturedText.phrases.count-1 { rejected.admission = false }
   _ = rejected.finishCapturedTextSpeech(id:part.id,text:part.text,outcome:.completed)
  }
  XCTAssertFalse(rejected.capturedTextReviewGuidanceEligible); XCTAssertNil(rejected.capturedTextReviewNotice)
  XCTAssertEqual(rejected.lastCapturedTextPlaybackReceipt!.outcome,.completed)
  rejected.admission = true; rejected.offerCapturedTextReviewGuidance(); XCTAssertNil(rejected.capturedTextReviewNotice)
 }

}
XCTMain([testCase([
("testCompletionRetainsWithoutFreshCameraThenNewReplayAndOldCallback",NativeReviewWitnessTests.testCompletionRetainsWithoutFreshCameraThenNewReplayAndOldCallback),
("testSynchronousCancellationCannotAdvanceReplacement",NativeReviewWitnessTests.testSynchronousCancellationCannotAdvanceReplacement),
("testNoAutomaticResumeAfterInterruptionButExplicitReviewWorks",NativeReviewWitnessTests.testNoAutomaticResumeAfterInterruptionButExplicitReviewWorks),
("testBudgetWaitIsRetiredAndNewAttemptWaitsNotCompletion",NativeReviewWitnessTests.testBudgetWaitIsRetiredAndNewAttemptWaitsNotCompletion),
("testPrivacyHazardAndForgetClearEveryRetainedOwner",NativeReviewWitnessTests.testPrivacyHazardAndForgetClearEveryRetainedOwner),
("testUntrustedInputCannotReadOrForgetAndUnstartedCannotRepeat",NativeReviewWitnessTests.testUntrustedInputCannotReadOrForgetAndUnstartedCannotRepeat),
("testContextualRepeatControlAndGenericFallback",NativeReviewWitnessTests.testContextualRepeatControlAndGenericFallback),
("testEarlyRepeatPreservesBudgetWakeWhenStatusDenied",NativeReviewWitnessTests.testEarlyRepeatPreservesBudgetWakeWhenStatusDenied),
("testDocumentRepeatPriorityDoesNotFallThroughToCapturedOrPersistedHistory",NativeReviewWitnessTests.testDocumentRepeatPriorityDoesNotFallThroughToCapturedOrPersistedHistory),
("testGuidanceHasOneOpportunityNotOneTipPerReview",NativeReviewWitnessTests.testGuidanceHasOneOpportunityNotOneTipPerReview)
])])
'''
core = root/'BlindCore/Sources/BlindCore'
# Exact controller/reading/authority sources. Only unrelated evidence helper is
# omitted from the DTO projection to avoid pulling in the banknote subsystem.
evidence=(core/'CompanionEvidence.swift').read_text()
evidence=evidence[:evidence.index('/// A read of the device')]
a=evidence.index('    /// Attributed RGB snapshot'); b=evidence.index('    public func isCurrent',a)
evidence=evidence[:a]+evidence[b:]
reading=(core/'ReadingTools.swift').read_text()
a=reading.index('public enum ReadingTool:');b=reading.index('public enum ReadingToolCommand:',a)
parts=[evidence,reading[a:b], 'enum InformationCandidate { enum Kind { case answer } }']
for file in ['SelectedDocumentReference.swift','CapturedTextReference.swift','CapturedTextReviewCommand.swift','CompanionReferenceReading.swift',
             'NarrationDelivery.swift','SpeechPriority.swift','SpeechDeliveryLedger.swift','CommandAuthority.swift','SpatialClaimGuard.swift']:
    parts.append((core/file).read_text())
output.write_text('\n'.join(parts)+header+tests)

