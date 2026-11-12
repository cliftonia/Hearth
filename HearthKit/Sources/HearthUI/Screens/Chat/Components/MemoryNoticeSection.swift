import SwiftUI

/// Says what was just remembered, changed or forgotten.
struct MemoryNoticeSection: View {
    let notice: String

    var body: some View {
        Label(notice, systemImage: "bookmark.fill")
            .font(.footnote)
            .foregroundStyle(HearthColor.pine)
            .padding(.horizontal, HearthSpacing.s12)
            .padding(.vertical, HearthSpacing.s8)
            .background(HearthColor.pineSoft, in: RoundedRectangle(cornerRadius: HearthRadius.card, style: .continuous))
            .transition(.opacity)
    }
}
