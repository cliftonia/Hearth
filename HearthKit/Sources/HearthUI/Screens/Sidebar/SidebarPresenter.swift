import Foundation
import HearthCore
import HearthDomain
import os

/// What the chat list asks of the coordinator, and what it reports having done to a chat.
@MainActor
protocol SidebarPresenterDelegate: AnyObject {
    func sidebarPresenter(_ presenter: SidebarPresenter, didSelect id: Conversation.ID)
    func sidebarPresenter(_ presenter: SidebarPresenter, didDelete id: Conversation.ID)
    func sidebarPresenter(_ presenter: SidebarPresenter, didRename id: Conversation.ID, to title: String)
    func sidebarPresenterDidRequestNewChat(_ presenter: SidebarPresenter)
    func sidebarPresenterDidRequestSettings(_ presenter: SidebarPresenter)
}

/// Lists the saved chats, searches them, and pins, renames, shares and deletes them.
@MainActor
final class SidebarPresenter {
    let viewModel = SidebarViewModel()
    weak var delegate: (any SidebarPresenterDelegate)?

    private let conversationStore: ConversationStore
    private let modelStore: ModelStore
    private let settingsStore: SettingsStore
    /// The chat that is open, which belongs to the chat screen; the list only highlights it.
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

    // MARK: What the list shows

    /// The chats that match the search, sorted into dated groups.
    var groups: [SidebarGroupViewConfiguration] {
        ConversationGrouper().groups(from: conversationStore.conversations, query: viewModel.query, now: Date())
    }

    var selectedID: Conversation.ID { selectedConversationID() }

    /// Whether the server answered when the models were last fetched, for the dot on the settings button.
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

    // MARK: Navigation

    func selectAction(_ id: Conversation.ID) {
        delegate?.sidebarPresenter(self, didSelect: id)
    }

    func newChatAction() {
        delegate?.sidebarPresenterDidRequestNewChat(self)
    }

    func settingsAction() {
        delegate?.sidebarPresenterDidRequestSettings(self)
    }

    // MARK: Changing a chat

    /// Pins a chat to the top of the list, or lets it go back among the others.
    func pinAction(_ row: SidebarRowViewConfiguration) async {
        do {
            try await conversationStore.setPinned(!row.isPinned, for: row.id)
        } catch {
            logger.error("Pinning a conversation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Opens the rename alert with the chat's present title in its field.
    func renameAction(_ row: SidebarRowViewConfiguration) {
        viewModel.renamingID = row.id
        viewModel.renameDraft = row.title
        viewModel.isRenaming = true
    }

    /// Saves the title typed into the rename alert. An empty title changes nothing.
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
