import Accessibility
import HearthDomain
import SwiftUI
import UIKit

/// Builds the screens, wires them together and decides where each request leads.
///
/// The app has one coordinator. Each presenter reports to it through a delegate protocol, which it conforms to in
/// `AppCoordinator+Delegates`; it answers by changing the `AppRouter` or by asking another presenter to act. What it does
/// for projects is in `AppCoordinator+Projects`, for the canvas in `AppCoordinator+Canvas`, and for scheduled tasks
/// and background refresh in `AppCoordinator+Tasks`.
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
    let tasksPresenter: ScheduledTasksPresenter
    /// Decides when to sync with the hub.
    let syncScheduler: SyncScheduler
    let taskStore: TaskStore
    /// Read for the chats whose answers a scheduled task filed.
    let conversationStore: ConversationStore
    let notifications: NotificationProvider
    /// A voice conversation asked for while locked, begun once the owner is in.
    var isVoicePending = false
    /// Settings are to open on the sync page once the task sheet over the chat has gone.
    var opensSyncAfterTaskSheet = false
    private let lockWindowController = LockWindowController()

    public init(dependencies: AppDependencies) {
        let settingsStore = dependencies.settingsStore
        let router = AppRouter()
        let lockPresenter = LockPresenter(authentication: dependencies.authentication) { settingsStore.settings.isLockEnabled }
        let chatPresenter = Self.makeChatPresenter(dependencies: dependencies, router: router, lockPresenter: lockPresenter)
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
        self.tasksPresenter = Self.makeTasksPresenter(dependencies: dependencies)
        (syncScheduler, taskStore, notifications) = (dependencies.syncScheduler, dependencies.taskStore, dependencies.notifications)
        self.conversationStore = dependencies.conversationStore
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
        dependencies.syncHooks.didReceiveTaskResults = { [weak self] ids in
            Task { await self?.announceTaskResults(ids) }
        }
        chatPresenter.onStoresLoaded = { [weak self] in
            Task {
                // Tasks are read before the first sync, so that what arrives is weighed against them.
                await self?.loadTasks()
                scheduler.appDidLoad()
            }
        }
    }

    /// The app has come to the front, stepped back from it, or gone to the background.
    ///
    /// At the front it syncs, if sync is on, and keeps syncing while it stays; in the background the regular syncs
    /// stop and a background refresh is asked for. The lock hides or locks the app at once, before the system
    /// pictures it for the app switcher, and asks the owner to unlock when the app comes forward locked; the lock
    /// window follows the lock as the root view sees it change.
    func sceneAction(_ phase: ScenePhase) async {
        router.isSceneActive = phase == .active
        switch phase {
        case .active:
            syncScheduler.appBecameActive()
        case .background:
            syncScheduler.appBecameInactive()
            BackgroundRefresh.schedule()
        case .inactive:
            break
        @unknown default:
            break
        }
        await lockPresenter.sceneAction(phase)
    }

    private static func makeChatPresenter(dependencies: AppDependencies, router: AppRouter, lockPresenter: LockPresenter) -> ChatPresenter {
        ChatPresenter(dependencies: ChatPresenter.Dependencies(
            chat: dependencies.chat,
            speech: dependencies.speech,
            image: dependencies.image,
            research: dependencies.research,
            dictation: dependencies.dictation,
            notifications: dependencies.notifications,
            photoLibrary: dependencies.photoLibrary,
            settingsStore: dependencies.settingsStore,
            modelStore: dependencies.modelStore,
            conversationStore: dependencies.conversationStore,
            memoryStore: dependencies.memoryStore,
            projectStore: dependencies.projectStore,
            isLocked: { lockPresenter.viewModel.isLocked },
            isOnScreen: { router.isSceneActive },
            announce: { AccessibilityNotification.Announcement($0).post() },
            isVoiceOverRunning: { UIAccessibility.isVoiceOverRunning }
        ))
    }

    private static func makeSettingsPresenter(dependencies: AppDependencies, chatPresenter: ChatPresenter) -> SettingsPresenter {
        let fetchModels = dependencies.fetchModels
        return SettingsPresenter(dependencies: SettingsPresenter.Dependencies(
            settingsStore: dependencies.settingsStore,
            memoryStore: dependencies.memoryStore,
            profileStore: dependencies.profileStore,
            modelStore: dependencies.modelStore,
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
                check: { url, token in await dependencies.sync.check(url, token: token) },
                settingsChanged: { dependencies.syncScheduler.settingsChanged() }
            ),
            announce: { AccessibilityNotification.Announcement($0).post() },
            now: { Date() }
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
        tasksPresenter.delegate = self
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

    /// The settings sheet has gone, by Close or by a swipe: what was being typed in it is kept.
    func settingsSheetDidDismiss() {
        Task { await settingsPresenter.sheetDidDismissAction() }
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
