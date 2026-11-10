import Foundation
import HearthCore
import HearthDomain
import Observation
import os

@MainActor
protocol SidebarPresenterDelegate: AnyObject {
    func sidebarPresenter(_ presenter: SidebarPresenter, didSelect id: Conversation.ID)
    func sidebarPresenter(_ presenter: SidebarPresenter, didDelete id: Conversation.ID)
    func sidebarPresenter(_ presenter: SidebarPresenter, didRename id: Conversation.ID, to title: String)
    func sidebarPresenterDidRequestNewChat(_ presenter: SidebarPresenter)
    func sidebarPresenterDidRequestSettings(_ presenter: SidebarPresenter)
}

@MainActor
@Observable
final class SidebarViewModel {
    var query = ""
    var isRenaming = false
    var renameDraft = ""
    var renamingID: Conversation.ID?
}

struct SidebarRowViewConfiguration: Hashable, Identifiable {
    let id: Conversation.ID
    let title: String
    let isPinned: Bool
    let isPrivate: Bool
}

enum SidebarGroupKind: Hashable, CaseIterable {
    case pinned
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

    func pinAction(_ row: SidebarRowViewConfiguration) async {
        do {
            try await conversationStore.setPinned(!row.isPinned, for: row.id)
        } catch {
            logger.error("Pinning a conversation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func renameAction(_ row: SidebarRowViewConfiguration) {
        viewModel.renamingID = row.id
        viewModel.renameDraft = row.title
        viewModel.isRenaming = true
    }

    func commitRenameAction() async {
        let title = viewModel.renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = viewModel.renamingID, !title.isEmpty else {
            return
        }
        viewModel.renamingID = nil
        do {
            try await conversationStore.rename(id, to: title)
            delegate?.sidebarPresenter(self, didRename: id, to: title)
        } catch {
            logger.error("Renaming a conversation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The conversation as Markdown, for sharing.
    func exportText(for id: Conversation.ID) -> String {
        let exporter = ConversationExporter(userLabel: Strings.exportUser, assistantLabel: Strings.brand, untitled: Strings.newChat)
        return conversationStore.conversation(for: id).map(exporter.markdown(for:)) ?? ""
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
        let grouped = Dictionary(grouping: matching) { conversation in
            conversation.isPinned ? .pinned : kind(for: conversation.updatedAt, now: now, calendar: calendar)
        }
        return SidebarGroupKind.allCases.compactMap { kind in
            guard let members = grouped[kind], !members.isEmpty else {
                return nil
            }
            let rows = members.map { conversation in
                SidebarRowViewConfiguration(
                    id: conversation.id,
                    title: conversation.title.isEmpty ? Strings.newChat : conversation.title,
                    isPinned: conversation.isPinned,
                    isPrivate: conversation.isPrivate
                )
            }
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
        case .pinned:
            Strings.pinned
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
