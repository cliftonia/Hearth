import Foundation

/// Erases everything the app keeps on the device, leaving it as it was on first launch.
public final class EraseInteractor: Sendable {
    /// Everything that holds something of the user's.
    public struct Stores: Sendable {
        let conversations: ConversationStore
        let projects: ProjectStore
        let memories: MemoryStore
        let profile: ProfileStore
        let settings: SettingsStore

        public init(conversations: ConversationStore, projects: ProjectStore, memories: MemoryStore, profile: ProfileStore, settings: SettingsStore) {
            self.conversations = conversations
            self.projects = projects
            self.memories = memories
            self.profile = profile
            self.settings = settings
        }
    }

    private let stores: Stores
    /// Takes down any notifications the app has posted, which may quote a chat that is about to go.
    private let removeNotifications: @Sendable () async -> Void
    /// Stops any sync under way, turns sync off and forgets everything it knew, so that nothing erased here is
    /// ever deleted from the hub or from another device.
    private let stopSync: @MainActor @Sendable () async -> Void

    public init(
        stores: Stores,
        removeNotifications: @escaping @Sendable () async -> Void = {},
        stopSync: @escaping @MainActor @Sendable () async -> Void = {}
    ) {
        self.stores = stores
        self.removeNotifications = removeNotifications
        self.stopSync = stopSync
    }

    /// Erases the chats, the projects, the memories, the profile photo and the saved settings, server addresses
    /// included, each through the store that keeps it. This device only: sync is stopped and turned off first, and
    /// no deletion is sent anywhere.
    ///
    /// The settings go last: they are the one thing that cannot fail, so if anything before them cannot be
    /// erased the error is passed on with the settings, and whatever else is left, still in place to try again.
    @MainActor
    public func eraseAll() async throws {
        await removeNotifications()
        await stopSync()
        try await stores.conversations.deleteAll()
        try await stores.projects.deleteAll()
        try await stores.memories.eraseAll()
        try await stores.profile.removePhoto()
        stores.settings.reset()
    }
}
