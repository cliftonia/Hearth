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
    /// A new chat is wanted: in the given project, or in none.
    func sidebarPresenter(_ presenter: SidebarPresenter, didRequestNewChatIn projectID: Project.ID?)
    func sidebarPresenterDidRequestSettings(_ presenter: SidebarPresenter)
    func sidebarPresenterDidRequestNewProject(_ presenter: SidebarPresenter)
    func sidebarPresenter(_ presenter: SidebarPresenter, didRequestEditing projectID: Project.ID)
    /// A project is to be chosen for the chat.
    func sidebarPresenter(_ presenter: SidebarPresenter, didRequestProjectFor id: Conversation.ID)
}

/// Lists the projects and the saved chats, searches them, and pins, renames, files, shares and deletes chats.
///
/// What it does with projects is in `SidebarPresenter+Projects`.
@MainActor
final class SidebarPresenter {
    let viewModel = SidebarViewModel()
    weak var delegate: (any SidebarPresenterDelegate)?

    let conversationStore: ConversationStore
    let projectStore: ProjectStore
    private let modelStore: ModelStore
    private let settingsStore: SettingsStore
    /// The chat that is open, which belongs to the chat screen; the list only highlights it.
    private let selectedConversationID: @MainActor () -> Conversation.ID
    let logger = Logger(for: SidebarPresenter.self)

    init(
        conversationStore: ConversationStore,
        projectStore: ProjectStore,
        modelStore: ModelStore,
        settingsStore: SettingsStore,
        selectedConversationID: @escaping @MainActor () -> Conversation.ID
    ) {
        self.conversationStore = conversationStore
        self.projectStore = projectStore
        self.modelStore = modelStore
        self.settingsStore = settingsStore
        self.selectedConversationID = selectedConversationID
    }

    // MARK: What the list shows

    /// The chats that match the search, sorted into dated groups: every chat, or those of the project being looked at.
    var groups: [SidebarGroupViewConfiguration] {
        ConversationGrouper().groups(
            from: conversationStore.conversations,
            in: selectedProject?.id,
            projects: projectStore.projects,
            query: viewModel.query,
            now: Date()
        )
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

    /// Starts a chat. While a project's chats are being looked at, the new chat belongs to that project.
    func newChatAction() {
        delegate?.sidebarPresenter(self, didRequestNewChatIn: selectedProject?.id)
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
            viewModel.isShowingSaveFailure = true
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
            viewModel.isShowingSaveFailure = true
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
            viewModel.isShowingSaveFailure = true
        }
    }
}
