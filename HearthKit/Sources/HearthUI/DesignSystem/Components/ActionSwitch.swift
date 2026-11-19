import SwiftUI

/// A switch that shows what it is told is so, and asks for a change when it is thrown.
///
/// The switch keeps its own position while it moves and is set right again by whatever it is told, so a change
/// that is refused, or one made elsewhere, is shown as it is.
struct ActionSwitch<Label: View>: View {
    let isOn: Bool
    let toggleAction: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var position = false

    var body: some View {
        Toggle(isOn: $position, label: label)
            .tint(HearthColor.pine)
            .onAppear { position = isOn }
            .onChange(of: isOn) { position = isOn }
            .onChange(of: position) {
                if position != isOn {
                    toggleAction()
                }
            }
    }
}
