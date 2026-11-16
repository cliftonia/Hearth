import Foundation
import HearthDomain

// What each row of the main list says about the page it leads to, so that most settings can be read without
// opening anything.
extension SettingsPresenter {
    /// "On · 12 saved", or "Off".
    var memoryStatus: String {
        viewModel.isMemoryEnabled ? Strings.memoryOn(number: memories.count) : Strings.settingsOff
    }

    /// "Reads full pages", or "Snippets only".
    var webSearchStatus: String {
        viewModel.isPageReadingEnabled ? Strings.webSearchReadsPages : Strings.webSearchSnippetsOnly
    }

    /// The voice, and whether replies are read aloud in it; without a speech server, that one is needed.
    var voiceStatus: String {
        guard hasSpeechServer else {
            return Strings.voiceNeedsServer
        }
        let voice = viewModel.voice.trimmingCharacters(in: .whitespaces)
        return viewModel.isAutoReadEnabled ? Strings.voiceReadsAloud(voice: voice) : voice
    }

    /// The model pictures are made with, or "Automatic".
    var picturesStatus: String {
        viewModel.imageModel?.title ?? Strings.pictureModelAutomatic
    }

    /// The notifications that are on, by name, or "Off".
    var notificationsStatus: String {
        let names = [
            viewModel.isReplyNotificationsEnabled ? Strings.notifyReplies : nil,
            viewModel.isTaskNotificationsEnabled ? Strings.notifyTasks : nil
        ].compactMap { $0 }
        return names.isEmpty ? Strings.settingsOff : names.joined(separator: ", ")
    }

    /// Whether the chat server answers and how many models it offers. A test run on the servers page is the latest
    /// word; otherwise the chat's own last look at the server is.
    var serversStatus: String {
        switch viewModel.connectionCheck {
        case .succeeded(let modelCount):
            return Strings.connected(modelCount: modelCount)
        case .failed:
            return Strings.serversNotConnected
        case .idle, .checking:
            break
        }
        let modelStore = dependencies.modelStore
        switch modelStore.reachability {
        case .reachable:
            return Strings.connected(modelCount: modelStore.models.count)
        case .unreachable:
            return Strings.serversNotConnected
        case .unknown:
            return Strings.serversNotChecked
        }
    }

    /// "On · synced 2 min ago", "On" before the first sync, or "Off".
    var syncRowStatus: String {
        let store = syncStore
        guard store.settings.isEnabled else {
            return Strings.settingsOff
        }
        guard let date = store.lastSyncedAt else {
            return Strings.settingsOn
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return Strings.syncOnSynced(when: formatter.localizedString(for: min(date, dependencies.now()), relativeTo: dependencies.now()))
    }

    /// What VoiceOver reads for a row: its title, then its status with the dots read as pauses.
    static func accessibilityLabel(title: String, status: String) -> String {
        "\(title), \(status.replacingOccurrences(of: " · ", with: ", "))"
    }
}
