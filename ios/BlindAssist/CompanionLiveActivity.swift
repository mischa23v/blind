#if BLIND_LIVE_ACTIVITY
import ActivityKit

/// Optional Lock Screen / Dynamic Island status (built only with --live-activity). It shows that
/// the assistant is still listening and whether the camera runs, so a helper or the child can tell
/// at a glance or with VoiceOver. Local only: no push token is requested and nothing leaves the phone.
/// Called on the main thread by NavigationModel.
final class CompanionLiveActivity {
    static let shared = CompanionLiveActivity()
    private var activity: Activity<CompanionActivityAttributes>?

    func show(cameraOn: Bool, arabic: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = CompanionActivityAttributes.ContentState(cameraOn: cameraOn, arabic: arabic)
        let content = ActivityContent(state: state, staleDate: nil)
        if activity == nil { activity = Activity<CompanionActivityAttributes>.activities.first }
        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(attributes: CompanionActivityAttributes(), content: content, pushType: nil)
        }
    }
}
#endif
