import HearthDomain
import Observation
import SwiftUI

/// What is on screen besides the chat itself.
@MainActor
@Observable
final class AppRouter {
    var isSidebarOpen = false
    var isSettingsPresented = false
    var isVoicePresented = false
}

/// Builds the screens, wires them together and decides where each request leads.
@MainActor
public final class AppCoordinator {
    let router = AppRouter()
    let settingsStore: SettingsStore
    let chatPresenter: ChatPresenter
    let sidebarPresenter: SidebarPresenter
    let settingsPresenter: SettingsPresenter
    let voicePresenter: VoicePresenter

    public init(dependencies: AppDependencies) {
        let chatPresenter = ChatPresenter(dependencies: ChatPresenter.Dependencies(
            chat: dependencies.chat,
            speech: dependencies.speech,
            dictation: dependencies.dictation,
            settingsStore: dependencies.settingsStore,
            modelStore: dependencies.modelStore,
            conversationStore: dependencies.conversationStore
        ))
        let settingsStore = dependencies.settingsStore
        let fetchModels = dependencies.fetchModels
        self.settingsStore = settingsStore
        self.chatPresenter = chatPresenter
        self.sidebarPresenter = SidebarPresenter(
            conversationStore: dependencies.conversationStore,
            modelStore: dependencies.modelStore,
            settingsStore: settingsStore,
            selectedConversationID: { chatPresenter.viewModel.conversation.id }
        )
        self.settingsPresenter = SettingsPresenter(settingsStore: settingsStore, speech: dependencies.speech) { settings in
            guard let baseURL = settings.ollamaURL else {
                throw ChatError.serverNotConfigured
            }
            return try await fetchModels(baseURL).count
        }
        self.voicePresenter = VoicePresenter(dependencies: VoicePresenter.Dependencies(
            dictation: dependencies.dictation,
            speech: dependencies.speech,
            settings: { settingsStore.settings },
            modelName: { chatPresenter.viewModel.selectedModel?.displayName ?? "" },
            runTurn: { words, onDelta in await chatPresenter.submit(text: words, style: .voice, onDelta: onDelta) },
            stopTurn: { await chatPresenter.stopAction() }
        ))
        chatPresenter.delegate = self
        sidebarPresenter.delegate = self
        settingsPresenter.delegate = self
        voicePresenter.delegate = self
    }

    /// Goes straight to a voice conversation, as a shortcut or the Action button asks.
    public func startVoice() {
        router.isSidebarOpen = false
        router.isSettingsPresented = false
        router.isVoicePresented = true
    }

    /// The root of the app's interface.
    public func start() -> some View {
        RootView(coordinator: self)
    }
}

extension AppCoordinator: ChatPresenterDelegate {
    func chatPresenterDidRequestSidebar(_ presenter: ChatPresenter) {
        router.isSidebarOpen = true
    }

    func chatPresenterDidRequestVoice(_ presenter: ChatPresenter) {
        router.isVoicePresented = true
    }

    func chatPresenterDidRequestSettings(_ presenter: ChatPresenter) {
        router.isSettingsPresented = true
    }
}

extension AppCoordinator: SidebarPresenterDelegate {
    func sidebarPresenter(_ presenter: SidebarPresenter, didSelect id: Conversation.ID) {
        router.isSidebarOpen = false
        Task { await chatPresenter.selectConversationAction(id) }
    }

    func sidebarPresenter(_ presenter: SidebarPresenter, didDelete id: Conversation.ID) {
        guard chatPresenter.viewModel.conversation.id == id else {
            return
        }
        Task { await chatPresenter.newChatAction() }
    }

    func sidebarPresenter(_ presenter: SidebarPresenter, didRename id: Conversation.ID, to title: String) {
        chatPresenter.conversationWasRenamed(id, to: title)
    }

    func sidebarPresenterDidRequestNewChat(_ presenter: SidebarPresenter) {
        router.isSidebarOpen = false
        Task { await chatPresenter.newChatAction() }
    }

    func sidebarPresenterDidRequestSettings(_ presenter: SidebarPresenter) {
        router.isSettingsPresented = true
    }
}

extension AppCoordinator: SettingsPresenterDelegate {
    func settingsPresenterDidFinish(_ presenter: SettingsPresenter, didSave: Bool) {
        router.isSettingsPresented = false
        if didSave {
            Task { await chatPresenter.refreshModelsAction() }
        }
    }
}

extension AppCoordinator: VoicePresenterDelegate {
    func voicePresenterDidFinish(_ presenter: VoicePresenter) {
        router.isVoicePresented = false
    }
}
