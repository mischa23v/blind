import Foundation
import BlindCore
struct Feedback { func stopInformation(announceCancellation: Bool)->Bool { true } }
struct Indoor { func cancelRoute() {} }
final class Controller {
var companionWorkingState=CompanionWorkingState(),assistantDialogue=AssistantDialogue(),objectiveDraft="",feedback=Feedback(),indoor=Indoor()
func retireHeldSearchForPrivacyDeletion() {}
func cancelDescription() {}
func stopReturn() {}
func persistDialogue() {}
func persistWorkingState() {}
    func forgetConversationRecord(id: String) {
        // Do not delete same-word records in another home through a text join.
        guard companionWorkingState.allowsLegacyReportMutation else { return }
        retireHeldSearchForPrivacyDeletion()
        #if DEBUG
        purgeDebugSessionDiagnostics()
        #endif
        guard let original = assistantDialogue.userRecords.first(where: { $0.id == id }),
              assistantDialogue.forgetUserRecord(id: id) else { return }
        cancelDescription(); _ = feedback.stopInformation(announceCancellation: false)
        companionWorkingState.removeReport(original.text)
        if companionWorkingState.goal != assistantDialogue.goal { companionWorkingState.changeGoal(assistantDialogue.goal) }
        objectiveDraft = assistantDialogue.goal
        stopReturn(); indoor.cancelRoute()
        persistDialogue(); persistWorkingState()
    }

}
let c=Controller(), report="I got the milk", step="Check the milk"
c.companionWorkingState.changeGoal("Help me make breakfast")
c.companionWorkingState.proposedStep=step
c.companionWorkingState.record(report)
c.assistantDialogue.record(role:"user",text:report)
c.companionWorkingState.apply(.init(goal:"",nextStep:"",completionReport:report,completionStep:step),latest:report)
precondition(c.companionWorkingState.reportedCompletedSteps == [step])
precondition(c.companionWorkingState.suspendGoal())
c.assistantDialogue.setGoal(c.companionWorkingState.goal)
let id=c.assistantDialogue.userRecords.first!.id
precondition(c.companionWorkingState.allowsLegacyReportMutation)
c.forgetConversationRecord(id:id)
precondition(c.assistantDialogue.userRecords.isEmpty)
precondition(c.companionWorkingState.reports.isEmpty)
precondition(c.companionWorkingState.reportedStepAssociations.isEmpty)
precondition(c.companionWorkingState.resumeGoal())
let resurrected=c.companionWorkingState.reportedCompletedSteps.contains(step)
print("actual_live_native_delete_reached=true; original_reports_removed=true; resumed_deleted_completion=\(resurrected)")
if resurrected { exit(1) }
