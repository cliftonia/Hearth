import HearthDomain
import SwiftUI

/// Builds the screens, wires them together and decides where each request leads.
///
/// The app has one coordinator. Each presenter reports to it through a delegate protocol, which it conforms to in
/// the extensions below; it answers by changing the `AppRouter` or by asking another presenter to act. What it does
/// for projects is in `AppCoordinator+Projects`, and for the canvas in `AppCoordinator+Canvas`.
@MainActor
public final class AppCoordinator {
    let router: AppRouter
    /// Read by the root view for the chosen theme.
    let settingsStore: SettingsStore
    let chatPresenter: ChatPresenter
    let sidebarPresenter: SidebarPresenter
    let settingsPresenter: SettingsPresenter
    let projectPresenter: ProjectPresenter
    let projectPickerPresenter: ProjectPickerPresenter
    let voicePresenter: VoicePresenter
    let lockPresenter: LockPresenter
    let canvasPresenter: CanvasPresenter
    /// Decides when to sync with the hub.
    let syncScheduler: SyncScheduler
    /// A voice conversation asked for while locked, begun once the owner is in.
    private var isVoicePending = false
    private let lockWindowController = LockWindowController()

    public init(dependencies: AppDependencies) {
        let settingsStore = dependencies.settingsStore
        let router = AppRouter()
        let lockPresenter = LockPresenter(authentication: dependencies.authentication) { settingsStore.settings.isLockEnabled }
        let chatPresenter = ChatPresenter(dependencies: ChatPresenter.Dependencies(
            chat: dependencies.chat,
            speech: dependencies.speech,
            image: dependencies.image,
            research: dependencies.research,
            dictation: dependencies.dictation,
            notifications: dependencies.notifications,
            settingsStore: dependencies.settingsStore,
            modelStore: dependencies.modelStore,
            conversationStore: dependencies.conversationStore,
            memoryStore: dependencies.memoryStore,
            projectStore: dependencies.projectStore,
            isLocked: { lockPresenter.viewModel.isLocked },
            isOnScreen: { router.isSceneActive }
        ))
        self.router = router
        self.settingsStore = settingsStore
        self.chatPresenter = chatPresenter
        self.sidebarPresenter = SidebarPresenter(
            conversationStore: dependencies.conversationStore,
            projectStore: dependencies.projectStore,
            modelStore: dependencies.modelStore,
            settingsStore: settingsStore,
            selectedConversationID: { chatPresenter.viewModel.conversation.id }
        )
        self.lockPresenter = lockPresenter
        self.canvasPresenter = Self.makeCanvasPresenter(chatPresenter: chatPresenter)
        self.settingsPresenter = Self.makeSettingsPresenter(dependencies: dependencies, chatPresenter: chatPresenter)
        let (projectStore, conversationStore) = (dependencies.projectStore, dependencies.conversationStore)
        self.projectPresenter = ProjectPresenter(projectStore: projectStore, conversationStore: conversationStore, interactor: dependencies.projects)
        self.projectPickerPresenter = ProjectPickerPresenter(projectStore: projectStore, conversationStore: conversationStore)
        self.voicePresenter = VoicePresenter(dependencies: VoicePresenter.Dependencies(
            dictation: dependencies.dictation,
            speech: dependencies.speech,
            camera: dependencies.camera,
            settings: { settingsStore.settings },
            modelName: { chatPresenter.viewModel.selectedModel?.displayName ?? "" },
            modelCanSee: { chatPresenter.viewModel.selectedModel?.canSee == true },
            // A picture from the camera is prepared exactly as an attached photo is.
            prepareFrame: { PhotoLoader.downscaledJPEG(from: $0) },
            runTurn: { words, frameJPEG, onDelta in
                await chatPresenter.submit(text: words, imagesJPEG: frameJPEG.map { [$0] } ?? [], style: .voice, onDelta: onDelta)
            },
            stopTurn: { await chatPresenter.stopAction() }
        ))
        self.syncScheduler = dependencies.syncScheduler
        connect(dependencies)
    }

    /// Connects what the presenters report to the coordinator, sync to the chat, and notification taps.
    private func connect(_ dependencies: AppDependencies) {
        connectDelegates()
        connectSync(dependencies)
        listenForNotificationTaps(dependencies.notifications)
    }

    /// Lets sync ask the chat whether a chat is being written to, tells the chat of chats another device changed,
    /// and starts syncing once the saved data has been read.
    private func connectSync(_ dependencies: AppDependencies) {
        let chatPresenter = chatPresenter
        let scheduler = syncScheduler
        dependencies.syncHooks.isBusy = { chatPresenter.isWriting($0) }
        dependencies.syncHooks.didApplyRemote = { keys in
            let ids = Set(keys.filter { $0.kind == .conversation }.compactMap(\.uuid).map { Conversation.ID($0) })
            guard !ids.isEmpty else {
                return
            }
            Task { await chatPresenter.conversationsChangedRemotely(ids) }
        }
        chatPresenter.onStoresLoaded = { scheduler.appDidLoad() }
    }

    /// The app has come to the front: sync, if sync is on.
    func sceneDidBecomeActive() {
        syncScheduler.appBecameActive()
    }

    private static func makeSettingsPresenter(dependencies: AppDependencies, chatPresenter: ChatPresenter) -> SettingsPresenter {
        let fetchModels = dependencies.fetchModels
        return SettingsPresenter(dependencies: SettingsPresenter.Dependencies(
            settingsStore: dependencies.settingsStore,
            memoryStore: dependencies.memoryStore,
            profileStore: dependencies.profileStore,
            speech: dependencies.speech,
            image: dependencies.image,
            eraser: dependencies.eraser,
            authentication: dependencies.authentication,
            notifications: dependencies.notifications,
            fetchModels: { settings in
                guard let baseURL = settings.ollamaURL else {
                    throw ChatError.serverNotConfigured
                }
                return try await fetchModels(baseURL).count
            },
            quietChat: { await chatPresenter.quietAction() },
            sync: SettingsPresenter.SyncControls(
                store: dependencies.syncStore,
                syncNow: { await dependencies.syncScheduler.syncNow() },
                check: { url, token in await dependencies.sync.check(url, token: token) }
            )
        ))
    }

    /// Opens the chat of each notification the user taps, for as long as the app runs.
    private func listenForNotificationTaps(_ notifications: NotificationProvider) {
        let taps = notifications.taps()
        Task { [weak self] in
            for await id in taps {
                self?.openConversation(id)
            }
        }
    }

    /// Goes straight to a chat, as a tapped notification asks. While the app is locked the chat opens behind the lock.
    private func openConversation(_ id: Conversation.ID) {
        router.closeOverlays()
        Task { await chatPresenter.openNotifiedConversationAction(id) }
    }

    /// Makes the coordinator the delegate of every presenter, so that each can ask it for what leads off its screen.
    private func connectDelegates() {
        chatPresenter.delegate = self
        sidebarPresenter.delegate = self
        settingsPresenter.delegate = self
        projectPresenter.delegate = self
        projectPickerPresenter.delegate = self
        voicePresenter.delegate = self
        lockPresenter.delegate = self
        canvasPresenter.delegate = self
    }

    /// Follows a link into the app, as a widget sends: `hearth://new` for a fresh chat, `hearth://voice` to talk.
    /// Any other link is ignored.
    public func open(_ url: URL) {
        guard url.scheme?.lowercased() == "hearth" else {
            return
        }
        let destination = url.host()?.lowercased()
        if destination == "new" {
            router.closeOverlays()
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
        router.closeOverlays()
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
            guard !closeCanvasForSidebar() else {
                return
            }
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

    func chatPresenter(_ presenter: ChatPresenter, didRequestProjectFor id: Conversation.ID) {
        presentProjectPicker(for: id)
    }

    func chatPresenter(_ presenter: ChatPresenter, didRequestCanvasFor reference: CanvasReference) {
        openCanvas(reference)
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

    func sidebarPresenter(_ presenter: SidebarPresenter, didRequestNewChatIn projectID: Project.ID?) {
        router.isSidebarOpen = false
        Task { await chatPresenter.newChatAction(in: projectID) }
    }

    func sidebarPresenterDidRequestNewProject(_ presenter: SidebarPresenter) {
        projectPresenter.begin()
        router.projectSheet = .editor
    }

    func sidebarPresenter(_ presenter: SidebarPresenter, didRequestEditing projectID: Project.ID) {
        projectPresenter.begin(editing: projectID)
        router.projectSheet = .editor
    }

    func sidebarPresenter(_ presenter: SidebarPresenter, didRequestProjectFor id: Conversation.ID) {
        presentProjectPicker(for: id)
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

    /// With everything erased the app goes back to how it first opened: no sheet, every chat list choice
    /// forgotten, an empty chat, and the models of the server it was built to start with.
    func settingsPresenterDidErase(_ presenter: SettingsPresenter) {
        router.isSettingsPresented = false
        router.isSidebarOpen = false
        router.isSidebarPinned = true
        sidebarPresenter.viewModel.selectedProjectID = nil
        Task { await chatPresenter.resetAction() }
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
        router.projectSheet = nil
        router.isVoicePresented = false
        router.isSidebarOpen = false
        router.isCanvasOpen = false
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
