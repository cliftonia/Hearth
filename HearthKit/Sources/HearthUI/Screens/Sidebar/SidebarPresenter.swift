import Foundation
import HearthCore
import HearthDomain
import Observation
import os

@MainActor
protocol SidebarPresenterDelegate: AnyObject {
    func sidebarPresenter(_ presenter: SidebarPresenter, didSelect id: Conversation.ID)
    func sidebarPresenter(_ presenter: SidebarPresenter, didDelete id: Conversation.ID)
    func sidebarPresenterDidRequestNewChat(_ presenter: SidebarPresenter)
    func sidebarPresenterDidRequestSettings(_ presenter: SidebarPresenter)
}

@MainActor
@Observable
final class SidebarViewModel {
    var query = ""
}

struct SidebarRowViewConfiguration: Hashable, Identifiable {
    let id: Conversation.ID
    let title: String
}

enum SidebarGroupKind: Hashable, CaseIterable {
    case today
    case yesterday
    case previousWeek
    case earlier
}

struct SidebarGroupViewConfiguration: Hashable, Identifiable {
    let id: SidebarGroupKind
    let title: String
    let rows: [SidebarRowViewConfiguration]
}

struct ServerStatusViewConfiguration: Hashable {
    let host: String
    let detail: String
    let isOnline: Bool
}

@MainActor
final class SidebarPresenter {
    let viewModel = SidebarViewModel()
    weak var delegate: (any SidebarPresenterDelegate)?

    private let conversationStore: ConversationStore
    private let modelStore: ModelStore
    private let settingsStore: SettingsStore
    private let selectedConversationID: @MainActor () -> Conversation.ID
    private let logger = Logger(for: SidebarPresenter.self)

    init(
        conversationStore: ConversationStore,
        modelStore: ModelStore,
        settingsStore: SettingsStore,
        selectedConversationID: @escaping @MainActor () -> Conversation.ID
    ) {
        self.conversationStore = conversationStore
        self.modelStore = modelStore
        self.settingsStore = settingsStore
        self.selectedConversationID = selectedConversationID
    }

    var groups: [SidebarGroupViewConfiguration] {
        ConversationGrouper().groups(from: conversationStore.conversations, query: viewModel.query, now: Date())
    }

    var selectedID: Conversation.ID { selectedConversationID() }

    var status: ServerStatusViewConfiguration {
        let host = settingsStore.settings.ollamaHost
        switch modelStore.reachability {
        case .reachable:
            return ServerStatusViewConfiguration(
                host: host ?? Strings.noServer,
                detail: Strings.connected(modelCount: modelStore.models.count),
                isOnline: true
            )
        case .unreachable:
            return ServerStatusViewConfiguration(host: host ?? Strings.noServer, detail: Strings.notConnected, isOnline: false)
        case .unknown:
            return ServerStatusViewConfiguration(host: host ?? Strings.noServer, detail: Strings.settings, isOnline: false)
        }
    }

    func selectAction(_ id: Conversation.ID) {
        delegate?.sidebarPresenter(self, didSelect: id)
    }

    func newChatAction() {
        delegate?.sidebarPresenterDidRequestNewChat(self)
    }

    func settingsAction() {
        delegate?.sidebarPresenterDidRequestSettings(self)
    }

    func deleteAction(_ id: Conversation.ID) async {
        do {
            try await conversationStore.delete(id)
            delegate?.sidebarPresenter(self, didDelete: id)
        } catch {
            logger.error("Deleting a conversation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Sorts conversations into the sidebar's dated groups.
struct ConversationGrouper {
    func groups(from conversations: [Conversation], query: String, now: Date, calendar: Calendar = .current) -> [SidebarGroupViewConfiguration] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let matching = conversations.filter { conversation in
            needle.isEmpty || conversation.title.localizedCaseInsensitiveContains(needle)
                || conversation.messages.contains { $0.text.localizedCaseInsensitiveContains(needle) }
        }
        let grouped = Dictionary(grouping: matching) { kind(for: $0.updatedAt, now: now, calendar: calendar) }
        return SidebarGroupKind.allCases.compactMap { kind in
            guard let members = grouped[kind], !members.isEmpty else {
                return nil
            }
            let rows = members.map { SidebarRowViewConfiguration(id: $0.id, title: $0.title.isEmpty ? Strings.newChat : $0.title) }
            return SidebarGroupViewConfiguration(id: kind, title: title(for: kind), rows: rows)
        }
    }

    private func kind(for date: Date, now: Date, calendar: Calendar) -> SidebarGroupKind {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0:
            return .today
        case 1:
            return .yesterday
        case 2...7:
            return .previousWeek
        default:
            return .earlier
        }
    }

    private func title(for kind: SidebarGroupKind) -> String {
        switch kind {
        case .today:
            Strings.today
        case .yesterday:
            Strings.yesterday
        case .previousWeek:
            Strings.previousWeek
        case .earlier:
            Strings.earlier
        }
    }
}
