import Foundation
import HearthDomain

/// One chat in the list.
struct SidebarRowViewConfiguration: Hashable, Identifiable {
    let id: Conversation.ID
    let title: String
    let isPinned: Bool
    let isPrivate: Bool
    /// Whether the chat belongs to a project that still exists.
    let isInProject: Bool
    /// Whether the hub filed the chat as the answer to a scheduled task.
    let isFromTask: Bool
}

/// One project, as a row: in the list above the chats, as the heading while its chats alone are shown, and in
/// the sheet that files a chat.
struct ProjectRowViewConfiguration: Hashable, Identifiable {
    let id: Project.ID
    let name: String
}

/// The headings chats are sorted under, in the order they appear.
enum SidebarGroupKind: Hashable, CaseIterable {
    case pinned
    /// The chats a scheduled task filed, newest first, kept apart from the dated groups.
    case scheduledTasks
    case today
    case yesterday
    case previousWeek
    case earlier
}

/// A heading and the chats beneath it.
struct SidebarGroupViewConfiguration: Hashable, Identifiable {
    let id: SidebarGroupKind
    let title: String
    let rows: [SidebarRowViewConfiguration]
}

/// How the server stands: shown as the dot on the settings button, and read out by VoiceOver.
struct ServerStatusViewConfiguration: Hashable {
    let host: String
    let detail: String
    let isOnline: Bool
}
