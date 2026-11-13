import SwiftUI
import WidgetKit

/// The widgets Hearth offers for the home screen and the lock screen.
@main
struct HearthWidgets: WidgetBundle {
    var body: some Widget {
        NewChatWidget()
        VoiceWidget()
    }
}

/// Opens Hearth on a fresh chat.
struct NewChatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NewChat", provider: ShortcutProvider()) { _ in
            ShortcutWidgetView(shortcut: .newChat)
        }
        .configurationDisplayName(String(localized: "widget.newChat.name", defaultValue: "New Chat"))
        .description(String(localized: "widget.newChat.description", defaultValue: "Start a new chat in Hearth."))
        .supportedFamilies(ShortcutWidgetView.families)
    }
}

/// Opens Hearth straight into a voice conversation.
struct VoiceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Voice", provider: ShortcutProvider()) { _ in
            ShortcutWidgetView(shortcut: .voice)
        }
        .configurationDisplayName(String(localized: "widget.voice.name", defaultValue: "Voice Conversation"))
        .description(String(localized: "widget.voice.description", defaultValue: "Start talking to Hearth."))
        .supportedFamilies(ShortcutWidgetView.families)
    }
}

/// What a widget opens in the app. The app reads the link in `AppCoordinator.open(_:)`.
enum WidgetShortcut {
    case newChat
    case voice

    var url: URL? {
        switch self {
        case .newChat:
            URL(string: "hearth://new")
        case .voice:
            URL(string: "hearth://voice")
        }
    }

    var title: String {
        switch self {
        case .newChat:
            String(localized: "widget.newChat.title", defaultValue: "New chat")
        case .voice:
            String(localized: "widget.voice.title", defaultValue: "Talk")
        }
    }

    var systemImage: String {
        switch self {
        case .newChat:
            "plus"
        case .voice:
            "waveform"
        }
    }
}

/// The widgets show nothing that changes, so there is one entry and it never needs replacing.
struct ShortcutEntry: TimelineEntry {
    let date: Date
}

struct ShortcutProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShortcutEntry {
        ShortcutEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShortcutEntry) -> Void) {
        completion(ShortcutEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShortcutEntry>) -> Void) {
        completion(Timeline(entries: [ShortcutEntry(date: .now)], policy: .never))
    }
}
