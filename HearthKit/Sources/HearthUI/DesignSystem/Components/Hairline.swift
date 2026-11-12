import SwiftUI

/// A one-point divider in the line colour. It fills the length it is offered along its axis.
struct Hairline: View {
    /// The direction the line runs in.
    var axis: Axis = .horizontal

    var body: some View {
        Rectangle()
            .fill(HearthColor.line)
            .frame(
                width: axis == .vertical ? HearthSize.hairline : nil,
                height: axis == .horizontal ? HearthSize.hairline : nil
            )
    }
}
