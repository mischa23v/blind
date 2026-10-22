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
                Text(context.state.title).font(.headline)
                Text(context.state.detail).font(.body)
            }
            .padding()
            .accessibilityElement(children: .combine)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title + ". " + context.state.detail)
                        .accessibilityElement(children: .combine)
                }
            } compactLeading: {
                Image(systemName: "ear").accessibilityLabel(context.state.title)
            } compactTrailing: {
                Image(systemName: context.state.cameraOn ? "eye" : "eye.slash").accessibilityLabel(context.state.detail)
            } minimal: {
                Image(systemName: context.state.cameraOn ? "eye" : "eye.slash")
                    .accessibilityLabel(context.state.title + ". " + context.state.detail)
            }
        }
    }
}
