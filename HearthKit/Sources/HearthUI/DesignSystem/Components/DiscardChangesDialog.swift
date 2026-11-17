import SwiftUI

extension View {
    /// Asks whether to let go of the changes made in a sheet, as Cancel does in an editor that has been changed:
    /// Discard Changes, drawn as destructive, or Keep Editing.
    func discardChangesDialog(isPresented: Binding<Bool>, discardAction: @escaping @MainActor () -> Void) -> some View {
        confirmationDialog(Strings.discardChangesQuestion, isPresented: isPresented, titleVisibility: .visible) {
            Button(Strings.discardChanges, role: .destructive) {
                Haptics.play(.warning)
                discardAction()
            }
            Button(Strings.keepEditing, role: .cancel) {}
        }
    }
}
