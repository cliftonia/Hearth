import SwiftUI

/// Questions the user might ask next; tapping one sends it.
struct FollowUpSection: View {
    private static let rowVerticalPadding: CGFloat = 11

    let questions: [String]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(questions, id: \.self) { question in
                Hairline()
                Button(action: { action(question) }, label: {
                    HStack(alignment: .firstTextBaseline, spacing: HearthSpacing.s10) {
                        Text(question)
                            .font(.subheadline)
                            .foregroundStyle(HearthColor.ink)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.turn.down.right")
                            .font(.footnote)
                            .foregroundStyle(HearthColor.pine)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, Self.rowVerticalPadding)
                    .contentShape(Rectangle())
                })
                .buttonStyle(.plain)
                .accessibilityHint(Strings.followUpHint)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Strings.followUps)
    }
}
