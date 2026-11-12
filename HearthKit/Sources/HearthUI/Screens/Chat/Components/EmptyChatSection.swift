import SwiftUI

/// What an empty chat shows: an invitation to talk, or, with no server set, the way to Settings.
struct EmptyChatSection: View {
    let isServerConfigured: Bool
    let isPrivate: Bool
    let settingsAction: () -> Void

    var body: some View {
        // With little room, as above a keyboard on a short screen, it sheds the mark and then the detail rather than
        // pushing the composer off the screen.
        ViewThatFits(in: .vertical) {
            content(hasMark: true, hasDetail: true, padding: HearthSpacing.s32)
            content(hasMark: false, hasDetail: true, padding: HearthSpacing.s16)
            content(hasMark: false, hasDetail: false, padding: HearthSpacing.s8)
        }
    }

    private func content(hasMark: Bool, hasDetail: Bool, padding: CGFloat) -> some View {
        VStack(spacing: HearthSpacing.s16) {
            if hasMark {
                HearthMark(sideLength: 56)
            }
            Text(isServerConfigured ? Strings.emptyTitle : Strings.connectTitle)
                .font(HearthFont.display)
                .foregroundStyle(HearthColor.ink)
                .multilineTextAlignment(.center)
            // The note keeps its place when hidden, so the title does not jump as a chat is made private.
            if isServerConfigured, hasDetail {
                Text(Strings.privateChatNote)
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .multilineTextAlignment(.center)
                    .opacity(isPrivate ? 1 : 0)
                    .accessibilityHidden(!isPrivate)
            }
            if !isServerConfigured {
                if hasDetail {
                    Text(Strings.connectMessage)
                        .font(.subheadline)
                        .foregroundStyle(HearthColor.mute)
                        .multilineTextAlignment(.center)
                }
                Button(Strings.openSettings, action: settingsAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HearthColor.onPine)
                    .padding(.horizontal, HearthSpacing.s18)
                    .padding(.vertical, HearthSpacing.s10)
                    .background(HearthColor.pine, in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(padding)
    }
}
