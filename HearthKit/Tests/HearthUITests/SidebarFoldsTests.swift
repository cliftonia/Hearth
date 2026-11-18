@testable import HearthUI
import Testing

/// Which sections of the chat list are folded, and how that is stored between launches.
struct SidebarFoldsTests {
    @Test func `nothing is folded at first`() {
        let folds = SidebarFolds(storedValue: "")

        #expect(SidebarFoldKind.allCases.allSatisfy { !folds.isFolded($0) })
        #expect(folds.storedValue.isEmpty)
    }

    @Test func `toggling folds a section and toggling again opens it`() {
        var folds = SidebarFolds(storedValue: "")

        folds.toggle(.projects)
        #expect(folds.isFolded(.projects))
        #expect(!folds.isFolded(.pinned))

        folds.toggle(.projects)
        #expect(!folds.isFolded(.projects))
    }

    @Test func `folds survive being stored and read back in a fixed order`() {
        var folds = SidebarFolds(storedValue: "")
        folds.toggle(.projects)
        folds.toggle(.pinned)

        #expect(folds.storedValue == "pinned,projects")
        #expect(SidebarFolds(storedValue: folds.storedValue) == folds)
    }

    @Test func `unknown words in the stored text are passed over`() {
        let folds = SidebarFolds(storedValue: "scheduledTasks,somethingNew,,")

        #expect(folds.kinds == [.scheduledTasks])
    }

    @Test func `only the pinned and scheduled task groups fold`() {
        #expect(SidebarGroupKind.pinned.foldKind == .pinned)
        #expect(SidebarGroupKind.scheduledTasks.foldKind == .scheduledTasks)
        #expect([SidebarGroupKind.today, .yesterday, .previousWeek, .earlier].allSatisfy { $0.foldKind == nil })
    }
}
