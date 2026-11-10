import AppIntents

/// Opens the app straight into a voice conversation, from Siri, Shortcuts, Spotlight or the Action button.
struct StartVoiceIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Voice Conversation"
    static let description = IntentDescription("Opens Hearth and starts listening.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        HearthApp.coordinator.startVoice()
        return .result()
    }
}

struct HearthShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartVoiceIntent(),
            phrases: [
                "Talk to \(.applicationName)",
                "Start a voice conversation in \(.applicationName)"
            ],
            shortTitle: "Voice Conversation",
            systemImageName: "waveform"
        )
    }
}
