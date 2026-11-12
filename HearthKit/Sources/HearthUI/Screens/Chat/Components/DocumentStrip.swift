import HearthDomain
import SwiftUI

/// The files attached to a message, each a chip with its name.
struct DocumentStrip: View {
    private static let removeButtonSide: CGFloat = 20

    let documents: [AttachedDocument]
    /// Called with a file's identifier when its remove button is tapped. Without it the files cannot be removed.
    let removeAction: ((AttachedDocument.ID) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HearthSpacing.s6) {
                ForEach(documents) { document in
                    HStack(spacing: HearthSpacing.s6) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundStyle(HearthColor.pine)
                            .accessibilityHidden(true)
                        Text(document.name)
                            .font(.caption)
                            .foregroundStyle(HearthColor.ink)
                            .lineLimit(1)
                        if let removeAction {
                            Button(action: { removeAction(document.id) }, label: {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(HearthColor.mute)
                                    .frame(width: Self.removeButtonSide, height: Self.removeButtonSide)
                            })
                            .buttonStyle(.plain)
                            .accessibilityLabel(Strings.removeFile)
                        }
                    }
                    .padding(.horizontal, HearthSpacing.s10)
                    .padding(.vertical, HearthSpacing.s6)
                    .capsuleSurface(fill: HearthColor.paper)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Strings.attachedFile(document.name))
                }
            }
        }
    }
}
