@testable import HearthUI
import Testing

/// The effort menu marks the chosen option and asks the system for no symbol it does not have.
struct ModelPickerSheetTests {
    @Test func `the chosen effort is ticked and the others ask for no symbol at all`() {
        #expect(ModelPickerSheet.menuSymbol(isChosen: true) == "checkmark")
        #expect(ModelPickerSheet.menuSymbol(isChosen: false) == nil)
    }
}
