import Foundation

/// The sections of the chat list that fold away beneath their heading. The dated groups never fold.
enum SidebarFoldKind: String, CaseIterable, Sendable {
    case pinned
    case scheduledTasks
    case projects
}

/// Which sections of the chat list are folded, kept as a short line of text so that it lasts between launches.
struct SidebarFolds: Hashable, Sendable {
    private(set) var kinds: Set<SidebarFoldKind>

    /// Reads the folds back from their stored text. Words it does not know, as a later version might write, are
    /// passed over.
    init(storedValue: String) {
        kinds = Set(storedValue.split(separator: ",").compactMap { SidebarFoldKind(rawValue: String($0)) })
    }

    /// The text to store, in a fixed order so that the same folds are always written the same way.
    var storedValue: String {
        SidebarFoldKind.allCases.filter(kinds.contains).map(\.rawValue).joined(separator: ",")
    }

    func isFolded(_ kind: SidebarFoldKind) -> Bool {
        kinds.contains(kind)
    }

    /// Folds an open section, or opens a folded one.
    mutating func toggle(_ kind: SidebarFoldKind) {
        if kinds.contains(kind) {
            kinds.remove(kind)
        } else {
            kinds.insert(kind)
        }
    }
}

extension SidebarGroupKind {
    /// The section this group folds as, or `nil` for a dated group, which is always open.
    var foldKind: SidebarFoldKind? {
        switch self {
        case .pinned:
            .pinned
        case .scheduledTasks:
            .scheduledTasks
        case .today, .yesterday, .previousWeek, .earlier:
            nil
        }
    }
}
