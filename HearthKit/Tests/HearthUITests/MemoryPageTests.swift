@testable import HearthUI
import SwiftUI
import Testing

/// Editing the memory list ends by itself once nothing is left to edit.
struct MemoryPageTests {
    @Test func `deleting the last memory while editing ends editing`() {
        #expect(MemoryPage.editMode(.active, whenListIsEmpty: true) == .inactive)
    }

    @Test(arguments: [EditMode.active, .inactive])
    func `a list that still holds memories keeps how it was being edited`(mode: EditMode) {
        #expect(MemoryPage.editMode(mode, whenListIsEmpty: false) == mode)
    }
}
