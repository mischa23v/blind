import AppIntents

/// Opens the app; it does not bypass microphone mute/end or turn camera awareness on.
/// iOS camera capture is foreground-only. Existing explicit session controls still apply.
struct OpenBlindAssistIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Blind Assist"
    static let description = IntentDescription("Opens the assistant. Camera and microphone follow your chosen controls.")
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
