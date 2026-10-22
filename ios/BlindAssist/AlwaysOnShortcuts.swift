import AppIntents

/// "Hey Siri, open Blind Assist", the Action button or a Shortcut bring the companion to the
/// foreground so the camera runs again (iOS pauses the camera in the background; listening,
/// speech and the belt keep running). Third-party apps cannot use an always-on wake word or keep
/// the camera on in the background, so this is the fastest way back to full sensing.
struct OpenBlindAssistIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Blind Assist"
    static let description = IntentDescription("Opens the assistant so the camera and sensors run again.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { .result() }
}

struct BlindAssistShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenBlindAssistIntent(),
                    phrases: ["Open \(.applicationName)", "Start \(.applicationName)", "Help me with \(.applicationName)"],
                    shortTitle: "Open assistant", systemImageName: "eye")
    }
}
