import Foundation
import HearthDomain

/// Sorts conversations into the sidebar's dated groups, and lists the projects above them.
struct ConversationGrouper {
    /// The conversations whose title or messages contain the query, grouped by when they were last changed.
    /// Pinned ones come first, whatever their age, and empty groups are left out.
    ///
    /// - Parameters:
    ///   - projectID: The project whose chats alone are wanted; `nil` for every chat, in a project or not.
    ///   - projects: The projects that exist. A chat is marked as being in a project only if its project is among
    ///     them, so one left pointing at a project that has gone reads as an ordinary chat.
    func groups(
        from conversations: [Conversation],
        in projectID: Project.ID? = nil,
        projects: [Project] = [],
        query: String,
        now: Date,
        calendar: Calendar = .current
    ) -> [SidebarGroupViewConfiguration] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let known = Set(projects.map(\.id))
        let matching = conversations.filter { conversation in
            guard projectID == nil || conversation.projectID == projectID else {
                return false
            }
            return needle.isEmpty || conversation.title.localizedCaseInsensitiveContains(needle)
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
                    isPrivate: conversation.isPrivate,
                    isInProject: conversation.projectID.map(known.contains) ?? false,
                    isFromTask: conversation.taskID != nil
                )
            }
            return SidebarGroupViewConfiguration(id: kind, title: title(for: kind), rows: rows)
        }
    }

    /// The projects to list above the chats, in the order given: all of them, or while searching those whose name
    /// contains the query.
    func projects(from projects: [Project], query: String) -> [ProjectRowViewConfiguration] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return projects
            .filter { needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) }
            .map { ProjectRowViewConfiguration(id: $0.id, name: $0.name) }
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
