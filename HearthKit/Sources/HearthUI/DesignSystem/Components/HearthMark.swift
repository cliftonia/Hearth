import SwiftUI

/// The app's mark: a ring of embers on pine.
struct HearthMark: View {
    let sideLength: CGFloat

    var body: some View {
        // The mark is drawn in proportion to its side, so it keeps its shape at any size.
        RoundedRectangle(cornerRadius: sideLength * 0.3, style: .continuous)
            .fill(HearthColor.pine)
            .frame(width: sideLength, height: sideLength)
            .overlay {
                Circle()
                    .strokeBorder(HearthColor.onPine, lineWidth: sideLength * 0.09)
                    .padding(sideLength * 0.28)
            }
            .accessibilityHidden(true)
    }
}
