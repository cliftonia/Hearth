import HearthDomain
import SwiftUI

/// Builds the screens, wires them together and decides where each request leads.
///
/// The app has one coordinator. Each presenter reports to it through a delegate protocol, which it conforms to in
/// the extensions below; it answers by changing the `AppRouter` or by asking another presenter to act.
@MainActor
public final class AppCoordinator {
    let router = AppRouter()
    /// Read by the root view for the chosen theme.
    let settingsStore: SettingsStore
    let chatPresenter: ChatPresenter
    let sidebarPresenter: SidebarPresenter
    let settingsPresenter: SettingsPresenter
    let voicePresenter: VoicePresenter
    let lockPresenter: LockPresenter
    /// A voice conversation asked for while locked, begun once the owner is in.
    private var isVoicePending = false
    private let lockWindowController = LockWindowController()

    public init(dependencies: AppDependencies) {
        let settingsStore = dependencies.settingsStore
        let lockPresenter = LockPresenter(authentication: dependencies.authentication) { settingsStore.settings.isLockEnabled }
        let chatPresenter = ChatPresenter(dependencies: ChatPresenter.Dependencies(
            chat: dependencies.chat,
            speech: dependencies.speech,
            image: dependencies.image,
            dictation: dependencies.dictation,
            settingsStore: dependencies.settingsStore,
            modelStore: dependencies.modelStore,
            conversationStore: dependencies.conversationStore,
            memoryStore: dependencies.memoryStore,
            isLocked: { lockPresenter.viewModel.isLocked }
        ))
        let fetchModels = dependencies.fetchModels
        self.settingsStore = settingsStore
        self.chatPresenter = chatPresenter
        self.sidebarPresenter = SidebarPresenter(
            conversationStore: dependencies.conversationStore,
            modelStore: dependencies.modelStore,
            settingsStore: settingsStore,
            selectedConversationID: { chatPresenter.viewModel.conversation.id }
        )
        self.lockPresenter = lockPresenter
        self.settingsPresenter = SettingsPresenter(
            settingsStore: settingsStore,
            speech: dependencies.speech,
            image: dependencies.image,
            authentication: dependencies.authentication,
            memoryStore: dependencies.memoryStore
        ) { settings in
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
        lockPresenter.delegate = self
    }

    /// Follows a link into the app, as a widget sends: `hearth://new` for a fresh chat, `hearth://voice` to talk.
    /// Any other link is ignored.
    public func open(_ url: URL) {
        guard url.scheme?.lowercased() == "hearth" else {
            return
        }
        let destination = url.host()?.lowercased()
        if destination == "new" {
            router.isSidebarOpen = false
            router.isSettingsPresented = false
            router.isVoicePresented = false
            Task { await chatPresenter.newChatAction() }
        } else if destination == "voice" {
            startVoice()
        }
    }

    /// Takes in what the share sheet left for the app: text and links go into the message being written, and
    /// pictures and files are attached to it. Nothing is sent until the user sends it.
    public func importShared(from inbox: URL) async {
        let shared = await SharedInbox.take(from: inbox)
        guard !shared.isEmpty else {
            return
        }
        router.isSidebarOpen = false
        chatPresenter.receiveSharedAction(shared)
    }

    /// Goes straight to a voice conversation, as a shortcut or the Action button asks.
    public func startVoice() {
        guard !lockPresenter.viewModel.isLocked else {
            isVoicePending = true
            return
        }
        router.isSidebarOpen = false
        router.isSettingsPresented = false
        router.isVoicePresented = true
    }

    /// Raises or removes the lock window to match whether the conversations should be hidden.
    func showLockWindow(colorScheme: ColorScheme?) {
        let lock = lockPresenter.viewModel
        lockWindowController.setCovered(lock.isLocked || lock.isObscured, presenter: lockPresenter, colorScheme: colorScheme)
    }

    /// The root of the app's interface.
    public func start() -> some View {
        RootView(coordinator: self)
    }
}

// MARK: - ChatPresenterDelegate

extension AppCoordinator: ChatPresenterDelegate {
    /// A narrow screen opens the drawer; a wide one shows the chats beside the chat or puts them away.
    func chatPresenterDidRequestSidebar(_ presenter: ChatPresenter) {
        if router.isWide {
            router.isSidebarPinned.toggle()
        } else {
            router.isSidebarOpen = true
        }
    }

    func chatPresenterDidRequestVoice(_ presenter: ChatPresenter) {
        router.isVoicePresented = true
    }

    func chatPresenterDidRequestSettings(_ presenter: ChatPresenter) {
        router.isSettingsPresented = true
    }
}

// MARK: - SidebarPresenterDelegate

extension AppCoordinator: SidebarPresenterDelegate {
    func sidebarPresenter(_ presenter: SidebarPresenter, didSelect id: Conversation.ID) {
        router.isSidebarOpen = false
        Task { await chatPresenter.selectConversationAction(id) }
    }

    /// Deleting the open chat leaves nothing to show, so a new one takes its place.
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

// MARK: - SettingsPresenterDelegate

extension AppCoordinator: SettingsPresenterDelegate {
    /// Saved settings may point at another server, so the models are fetched afresh.
    func settingsPresenterDidFinish(_ presenter: SettingsPresenter, didSave: Bool) {
        router.isSettingsPresented = false
        if didSave {
            Task { await chatPresenter.refreshModelsAction() }
        }
    }
}

// MARK: - VoicePresenterDelegate

extension AppCoordinator: VoicePresenterDelegate {
    func voicePresenterDidFinish(_ presenter: VoicePresenter) {
        router.isVoicePresented = false
    }
}

// MARK: - LockPresenterDelegate

extension AppCoordinator: LockPresenterDelegate {
    /// A locked app shows nothing, says nothing and listens to nothing: sheets close and voice and speech stop.
    func lockPresenterDidLock(_ presenter: LockPresenter) {
        let wasInVoice = router.isVoicePresented
        router.isSettingsPresented = false
        router.isVoicePresented = false
        router.isSidebarOpen = false
        sidebarPresenter.viewModel.isRenaming = false
        Task {
            if wasInVoice {
                await voicePresenter.endAction()
            }
            await chatPresenter.stopSpeaking()
            await chatPresenter.stopDictation()
        }
    }

    /// Begins the voice conversation that was asked for while the app was locked, if there was one.
    func lockPresenterDidUnlock(_ presenter: LockPresenter) {
        if isVoicePending {
            isVoicePending = false
            startVoice()
        }
    }
}
