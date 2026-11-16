import Foundation
import HearthCore
import HearthDomain
import os

// Scheduled tasks: their page in the settings, a task begun from the composer, announcing the answers the hub
// files, and the background refresh that brings those answers in while the app is away.
extension AppCoordinator {
    static func makeTasksPresenter(dependencies: AppDependencies) -> ScheduledTasksPresenter {
        ScheduledTasksPresenter(dependencies: ScheduledTasksPresenter.Dependencies(
            taskStore: dependencies.taskStore,
            syncStore: dependencies.syncStore,
            modelStore: dependencies.modelStore,
            now: { Date() },
            calendar: { Calendar.current }
        ))
    }

    /// Shows the editor over the chat with a new task asking what was being written, or, while sync is off, the
    /// notice that tasks need sync.
    func presentTaskSheet(prompt: String) {
        router.taskSheet = tasksPresenter.beginTaskAction(prompt: prompt) ? .editor : .needsSync
    }

    /// The task sheet over the chat has gone. If it went because Set up sync was chosen, the settings open on the
    /// sync page now, since one sheet cannot be presented while another is still leaving.
    func taskSheetDidDismiss() {
        guard opensSyncAfterTaskSheet else {
            return
        }
        opensSyncAfterTaskSheet = false
        settingsPresenter.viewModel.path = [.sync]
        router.isSettingsPresented = true
    }

    /// Reads the saved tasks. A failure leaves the list empty until the next sync brings them from the hub.
    func loadTasks() async {
        do {
            try await taskStore.load()
        } catch {
            Logger(for: AppCoordinator.self).error("Loading tasks failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Posts a notification for each answer the hub filed that sync has just brought in, when the switch is on and
    /// the app is not in front of the user. A tap opens the chat, as for a reply.
    func announceTaskResults(_ ids: [Conversation.ID]) async {
        let conversationStore = chatPresenter.dependencies.conversationStore
        let conversations = ids.compactMap { conversationStore.conversation(for: $0) }
        let notices = TaskResultNotificationPlanner().notifications(
            for: conversations,
            isEnabled: settingsStore.settings.isTaskNotificationsEnabled,
            isOnScreen: router.isSceneActive
        )
        for notice in notices {
            do {
                try await notifications.post(notice)
            } catch {
                // Most often the system's permission has been withdrawn, which the Notifications page already says.
                Logger(for: AppCoordinator.self).notice("A task notification was not posted: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// One background refresh: asks for the next, then, if sync is on, reads what is saved if the app has not yet,
    /// and runs one sync, which may bring in answers to announce. Nothing asks the chat server for its models.
    public func backgroundRefreshAction() async {
        BackgroundRefresh.schedule()
        let chat = chatPresenter.dependencies
        await syncScheduler.backgroundSync {
            let logger = Logger(for: AppCoordinator.self)
            do {
                try await chat.conversationStore.load()
                try await chat.projectStore.load()
                try await chat.memoryStore.load()
            } catch {
                logger.error("Reading saved data for a background sync failed: \(error.localizedDescription, privacy: .public)")
            }
            await self.loadTasks()
        }
    }
}

// MARK: - ScheduledTasksPresenterDelegate

extension AppCoordinator: ScheduledTasksPresenterDelegate {
    /// The editor over the chat closes with the presenter's; the one on the tasks page closes by itself.
    func scheduledTasksPresenterDidCloseEditor(_ presenter: ScheduledTasksPresenter) {
        if router.taskSheet == .editor {
            router.taskSheet = nil
        }
    }

    func scheduledTasksPresenterDidRequestSync(_ presenter: ScheduledTasksPresenter) {
        opensSyncAfterTaskSheet = true
        router.taskSheet = nil
    }
}
