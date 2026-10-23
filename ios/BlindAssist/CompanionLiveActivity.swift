#if BLIND_LIVE_ACTIVITY
import ActivityKit
import Foundation

/// Optional, local-only status. No reply, location, person or push token is included.
/// The controller supplies actual capture state, never just a requested session.
@MainActor
final class CompanionLiveActivity {
    static let shared = CompanionLiveActivity()
    private var activity: Activity<CompanionActivityAttributes>?
    private struct Update {
        let state: CompanionActivityAttributes.ContentState
        let observedAt: Date
    }
    private var pending: Update?
    private var worker: Task<Void, Never>?
    private var lastSubmitted: Update?
    /// This is status freshness, not a guarantee of uninterrupted capture.
    private static let freshness: TimeInterval = 30

    func show(cameraOn: Bool, listening: Bool, arabic: Bool) {
        let state = CompanionActivityAttributes.ContentState(cameraOn: cameraOn, listening: listening, arabic: arabic)
        let now = Date()
        // Coalesce high-frequency camera notifications; never delay a state change.
        if let previous = lastSubmitted, previous.state == state,
           now.timeIntervalSince(previous.observedAt) >= 0,
           now.timeIntervalSince(previous.observedAt) < 10 { return }
        let update = Update(state: state, observedAt: now)
        pending = update; lastSubmitted = update
        guard worker == nil else { return }
        worker = Task { @MainActor [weak self] in await self?.drain() }
    }

    /// One worker serializes update/end/request. A newer pending state replaces an
    /// older pending state, never an in-flight operation that might already execute.
    private func drain() async {
        while let update = pending {
            pending = nil
            if let current = activity, current.activityState != .active && current.activityState != .stale {
                activity = nil
            }
            if activity == nil {
                activity = Activity<CompanionActivityAttributes>.activities.first {
                    $0.activityState == .active || $0.activityState == .stale
                }
            }
            let content = ActivityContent(state: update.state,
                staleDate: update.observedAt.addingTimeInterval(Self.freshness))
            if !update.state.cameraOn && !update.state.listening {
                if let current = activity {
                    await current.end(content, dismissalPolicy: .immediate)
                    activity = nil
                }
                continue
            }
            // Waiting for a platform update must not make an old observation new.
            guard Date().timeIntervalSince(update.observedAt) < Self.freshness,
                  ActivityAuthorizationInfo().areActivitiesEnabled else { continue }
            if let current = activity {
                await current.update(content)
            } else {
                activity = try? Activity.request(attributes: CompanionActivityAttributes(), content: content, pushType: nil)
            }
        }
        worker = nil
    }
}
#endif
