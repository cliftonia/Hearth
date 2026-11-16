import HearthDomain
import SwiftUI

/// The bar above the chat: the chat list at one end; at the other, the private switch until the chat begins, and
/// from then on a new chat and the chat's own menu. Beneath it, for a chat in a project, the project's name, and for
/// a chat a scheduled task filed, a line saying so.
///
/// The model is chosen from the composer, where the message it will answer is written.
struct ChatHeader: View {
    let presenter: ChatPresenter

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        // A narrow screen opens the chats as a drawer; a wide one shows them beside the chat or puts them away.
        let isWide = horizontalSizeClass == .regular
        VStack(spacing: 0) {
            bar(isWide: isWide)
            projectMark
            taskMark
        }
    }

    private func bar(isWide: Bool) -> some View {
        HStack(spacing: HearthSpacing.s8) {
            GlassCircleButton(
                systemImage: isWide ? "sidebar.left" : "line.3.horizontal",
                label: isWide ? Strings.sidebarToggle : Strings.menuLabel,
                action: {
                    // Opening or closing the chats by this button is felt; a drag has the finger's own feedback.
                    Haptics.play(.light)
                    presenter.sidebarAction()
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            privateMark
            // Before a chat has begun there is nothing to pin, share or start afresh, so the private switch stands
            // here alone. Once it has begun, a new chat and the chat's menu take its place.
            ZStack(alignment: .trailing) {
                privateToggle
                    .opacity(hasBegun ? 0 : 1)
                    .allowsHitTesting(!hasBegun)
                    .accessibilityHidden(hasBegun)
                chatControls
                    .opacity(hasBegun ? 1 : 0)
                    .allowsHitTesting(hasBegun)
                    .accessibilityHidden(!hasBegun)
            }
            .animation(.snappy, value: hasBegun)
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s4)
    }

    /// Whether the open chat has a message in it yet.
    private var hasBegun: Bool {
        !presenter.viewModel.conversation.messages.isEmpty
    }

    /// Makes a chat that has not yet begun private, or ordinary again.
    private var privateToggle: some View {
        let isPrivate = presenter.viewModel.conversation.isPrivate
        let canChange = presenter.isServerConfigured
        return GlassCircleButton(
            systemImage: isPrivate ? "eye.slash.fill" : "eye.slash",
            label: Strings.privateChat,
            isSelected: isPrivate,
            action: presenter.togglePrivateAction
        )
        .opacity(canChange ? 1 : 0)
        .allowsHitTesting(canChange)
        .accessibilityHidden(!canChange)
        .animation(.snappy, value: isPrivate)
    }

    /// Shows that a chat that has begun is private. It keeps its place when hidden, so the controls beside it do
    /// not move.
    private var privateMark: some View {
        let isShown = hasBegun && presenter.viewModel.conversation.isPrivate
        return Image(systemName: "eye.slash.fill")
            .font(.hearth(.footnote))
            .foregroundStyle(HearthColor.pine)
            .frame(width: HearthSize.glassButton, height: HearthSize.glassButton)
            .background(HearthColor.pineSoft, in: Circle())
            .opacity(isShown ? 1 : 0)
            .accessibilityLabel(Strings.privateChat)
            .accessibilityHidden(!isShown)
            .animation(.snappy, value: isShown)
    }

    /// The name of the project the chat belongs to, so that it is plain where the next message goes. It takes no
    /// room when the chat is in none.
    private var projectMark: some View {
        let name = presenter.chatProject?.name
        return HStack(spacing: HearthSpacing.s4) {
            Image(systemName: "folder")
                .font(.hearth(.caption2))
            Text(name ?? "")
                .font(.hearth(.caption))
                .lineLimit(1)
        }
        .foregroundStyle(HearthColor.mute)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.bottom, name == nil ? 0 : HearthSpacing.s4)
        .opacity(name == nil ? 0 : 1)
        .frame(height: name == nil ? 0 : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Strings.chatInProject(name ?? ""))
        .accessibilityHidden(name == nil)
        .animation(.snappy, value: name)
    }

    /// Says that the hub filed this chat as the answer to a scheduled task. It takes no room for any other chat.
    private var taskMark: some View {
        let isShown = presenter.viewModel.conversation.taskID != nil
        return Label(isShown ? Strings.scheduledTaskMark : "", systemImage: "clock")
            .font(.hearth(.caption))
            .foregroundStyle(HearthColor.mute)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.bottom, isShown ? HearthSpacing.s4 : 0)
            .opacity(isShown ? 1 : 0)
            .frame(height: isShown ? nil : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Strings.scheduledTaskMark)
            .accessibilityHidden(!isShown)
    }

    /// A new chat, and the menu of what can be done with this one, side by side in one pill.
    private var chatControls: some View {
        HStack(spacing: 0) {
            IconButton(systemImage: "square.and.pencil", label: Strings.newChat) {
                Task { await presenter.newChatAction() }
            }
            Menu {
                chatMenu
            } label: {
                Image(systemName: "ellipsis")
                    .font(HearthFont.icon)
                    .foregroundStyle(HearthColor.ink)
                    .frame(width: HearthSize.iconButton, height: HearthSize.iconButton)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Strings.chatOptions)
        }
        .padding(.horizontal, HearthSpacing.s4)
        .frame(height: HearthSize.glassButton)
        .glassSurface(Capsule())
    }

    /// What can be done with a chat that has begun: pin it; share it, rename it or file it in a project; delete it.
    @ViewBuilder private var chatMenu: some View {
        Section {
            Button(action: {
                Haptics.play(.light)
                Task { await presenter.togglePinAction() }
            }, label: {
                Label(presenter.isChatPinned ? Strings.unpin : Strings.pin, systemImage: presenter.isChatPinned ? "pin.slash" : "pin")
            })
        }
        Section {
            ShareLink(item: presenter.chatExportText) {
                Label(Strings.share, systemImage: "square.and.arrow.up")
            }
            Button(action: presenter.renameChatAction) {
                Label(Strings.rename, systemImage: "pencil")
            }
            Button(action: presenter.projectAction) {
                Label(presenter.chatProject == nil ? Strings.addToProject : Strings.moveToProject, systemImage: "folder")
            }
        }
        Section {
            Button(role: .destructive, action: {
                Haptics.play(.warning)
                Task { await presenter.deleteChatAction() }
            }, label: {
                Label(Strings.delete, systemImage: "trash")
            })
        }
    }
}
