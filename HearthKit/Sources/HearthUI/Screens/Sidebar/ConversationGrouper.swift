import Foundation
import HearthDomain

/// Sorts conversations into the sidebar's dated groups.
struct ConversationGrouper {
    /// The conversations whose title or messages contain the query, grouped by when they were last changed.
    /// Pinned ones come first, whatever their age, and empty groups are left out.
    func groups(from conversations: [Conversation], query: String, now: Date, calendar: Calendar = .current) -> [SidebarGroupViewConfiguration] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let matching = conversations.filter { conversation in
            needle.isEmpty || conversation.title.localizedCaseInsensitiveContains(needle)
                || conversation.messages.contains { $0.text.localizedCaseInsensitiveContains(needle) }
        }
        let grouped = Dictionary(grouping: matching) { conversation in
            conversation.isPinned ? .pinned : kind(for: conversation.updatedAt, now: now, calendar: calendar)
        }
        return SidebarGroupKind.allCases.compactMap { kind in
            guard let members = grouped[kind], !members.isEmpty else {
                return nil
            }
            let rows = members.map { conversation in
                SidebarRowViewConfiguration(
                    id: conversation.id,
                    title: conversation.title.isEmpty ? Strings.newChat : conversation.title,
                    isPinned: conversation.isPinned,
                    isPrivate: conversation.isPrivate
                )
            }
            return SidebarGroupViewConfiguration(id: kind, title: title(for: kind), rows: rows)
        }
    }

    /// Counts whole calendar days, so a chat from late last night is yesterday's however few hours ago it was.
    private func kind(for date: Date, now: Date, calendar: Calendar) -> SidebarGroupKind {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0:
            return .today
        case 1:
            return .yesterday
        case 2...7:
            return .previousWeek
        default:
            return .earlier
        }
    }

    private func title(for kind: SidebarGroupKind) -> String {
        switch kind {
        case .pinned:
            Strings.pinned
        case .today:
            Strings.today
        case .yesterday:
            Strings.yesterday
        case .previousWeek:
            Strings.previousWeek
        case .earlier:
            Strings.earlier
        }
    }
}
