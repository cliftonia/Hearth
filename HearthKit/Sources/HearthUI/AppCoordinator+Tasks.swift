import Foundation
import HearthCore
import HearthDomain
import os

// Scheduled tasks: their page in the settings, announcing the answers the hub files, and the background refresh
// that brings those answers in while the app is away.
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
