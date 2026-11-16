import SwiftUI
import UIKit

/// A round picture of a person: their photo, or their initials, or a person symbol when there is neither.
struct Avatar: View {
    /// How much of the circle's width the initials or the symbol may take.
    private static let contentFraction: CGFloat = 0.5

    /// The photo as JPEG data, if there is one.
    let photoJPEG: Data?
    /// One or two letters, shown when there is no photo. Empty shows the symbol.
    let initials: String
    let diameter: CGFloat

    var body: some View {
        let photo = photoJPEG.flatMap(UIImage.init(data:))
        ZStack {
            Circle()
                .fill(HearthColor.pineSoft)
            // Both stay in the tree, so typing the first letter of a name does not rebuild the circle.
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(HearthColor.pine)
                .frame(width: diameter * Self.contentFraction * 0.8, height: diameter * Self.contentFraction * 0.8)
                .opacity(initials.isEmpty ? 1 : 0)
            Text(initials)
                .font(.hearth(.largeTitle).weight(.semibold))
                .foregroundStyle(HearthColor.pine)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .frame(width: diameter * Self.contentFraction, height: diameter * Self.contentFraction)
                .opacity(initials.isEmpty ? 0 : 1)
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
            }
        }
        .frame(width: diameter, height: diameter)
        .surface(Circle(), fill: .clear)
        .accessibilityHidden(true)
    }
}
