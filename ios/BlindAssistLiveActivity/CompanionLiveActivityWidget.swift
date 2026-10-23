import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island status, readable by VoiceOver: one element with the full
/// status, so a swipe reads it at once. Tapping it opens the assistant.
@main
struct CompanionLiveActivityBundle: WidgetBundle {
    var body: some Widget { CompanionLiveActivityWidget() }
}

struct CompanionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompanionActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.title(stale: context.isStale)).font(.headline)
                Text(context.state.detail(stale: context.isStale)).font(.body)
            }
            .padding()
            .accessibilityElement(children: .combine)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title(stale: context.isStale) + ". " + context.state.detail(stale: context.isStale))
                        .accessibilityElement(children: .combine)
                }
            } compactLeading: {
                Image(systemName: context.state.microphoneSymbol(stale: context.isStale)).accessibilityLabel(context.state.title(stale: context.isStale))
            } compactTrailing: {
                Image(systemName: context.state.cameraSymbol(stale: context.isStale)).accessibilityLabel(context.state.detail(stale: context.isStale))
            } minimal: {
                Image(systemName: context.state.cameraSymbol(stale: context.isStale))
                    .accessibilityLabel(context.state.title(stale: context.isStale) + ". " + context.state.detail(stale: context.isStale))
            }
        }
    }
}
