import Foundation
import HearthDomain

/// One chat in the list.
struct SidebarRowViewConfiguration: Hashable, Identifiable {
    let id: Conversation.ID
    let title: String
    let isPinned: Bool
    let isPrivate: Bool
}

/// The headings chats are sorted under, in the order they appear.
enum SidebarGroupKind: Hashable, CaseIterable {
    case pinned
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
