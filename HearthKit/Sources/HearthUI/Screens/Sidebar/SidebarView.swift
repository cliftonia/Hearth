import HearthDomain
import SwiftUI

/// The chat list: the brand, a search field, the chats grouped by day, and Settings and New chat floating at the foot.
struct SidebarView: View {
    /// The vertical padding that gives the search field and each chat their height.
    private static let rowVerticalPadding: CGFloat = 9
    /// Room for the last chat to be scrolled clear of the floating controls.
    private static let listBottomClearance: CGFloat = 84
    private static let statusDotRingWidth: CGFloat = 2
    /// How far down the floating controls the list has faded out completely.
    private static let fadeEnd = UnitPoint(x: 0.5, y: 0.4)

    let presenter: SidebarPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let groups = presenter.groups
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: HearthSpacing.s10) {
                HearthMark(sideLength: 26)
                Text(Strings.brand)
                    .font(HearthFont.brand)
                    .foregroundStyle(HearthColor.ink)
            }
            .padding(.horizontal, HearthSpacing.s18)
            .padding(.top, HearthSpacing.s8)
            .padding(.bottom, HearthSpacing.s14)
            searchField(text: $viewModel.query)
            ZStack(alignment: .top) {
                conversationList(groups: groups)
                Text(Strings.noChats)
                    .font(.subheadline)
                    .foregroundStyle(HearthColor.mute)
                    .padding(.top, HearthSpacing.s32)
                    .opacity(groups.isEmpty ? 1 : 0)
                    .accessibilityHidden(!groups.isEmpty)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) { floatingControls }
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .alert(Strings.renameChat, isPresented: $viewModel.isRenaming) {
            TextField(Strings.chatTitle, text: $viewModel.renameDraft)
            Button(Strings.cancel, role: .cancel) {}
            Button(Strings.save) { Task { await presenter.commitRenameAction() } }
        }
        .alert(Strings.errorChangeFailed, isPresented: $viewModel.isShowingSaveFailure) {
            Button(Strings.ok, role: .cancel) {}
        }
    }

    // MARK: Search and list

    private func searchField(text: Binding<String>) -> some View {
        HStack(spacing: HearthSpacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            TextField(Strings.searchChats, text: text)
                .font(.subheadline)
                .foregroundStyle(HearthColor.ink)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, HearthSpacing.s12)
        .padding(.vertical, Self.rowVerticalPadding)
        .cardSurface()
        .padding(.horizontal, HearthSpacing.s14)
    }

    private func conversationList(groups: [SidebarGroupViewConfiguration]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: HearthSpacing.s2) {
                ForEach(groups) { group in
                    Text(group.title)
                        .font(.caption.weight(.medium))
                        .textCase(.uppercase)
                        .kerning(0.6)
                        .foregroundStyle(HearthColor.mute)
                        .padding(.horizontal, HearthSpacing.s18)
                        .padding(.top, HearthSpacing.s14)
                        .padding(.bottom, HearthSpacing.s4)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(group.rows) { row in
                        conversationRow(row)
                    }
                }
            }
            .padding(.bottom, Self.listBottomClearance)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    /// One chat. A long press offers to pin, rename, share or delete it.
    private func conversationRow(_ row: SidebarRowViewConfiguration) -> some View {
        let isSelected = row.id == presenter.selectedID
        return Button(action: { presenter.selectAction(row.id) }, label: {
            HStack(spacing: HearthSpacing.s6) {
                Text(row.title)
                    .font(.subheadline)
                    .foregroundStyle(HearthColor.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(HearthColor.mute)
                    .opacity(row.isPrivate ? 1 : 0)
                    .frame(width: row.isPrivate ? nil : 0)
                    .accessibilityHidden(true)
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(HearthColor.pine)
                    .opacity(row.isPinned ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s10)
            .padding(.vertical, Self.rowVerticalPadding)
            .background(isSelected ? HearthColor.bubble : .clear, in: RoundedRectangle(cornerRadius: HearthRadius.row, style: .continuous))
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .padding(.horizontal, HearthSpacing.s8)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(Self.spokenMarks(for: row))
        .contextMenu {
            Button(action: { Task { await presenter.pinAction(row) } }, label: {
                Label(row.isPinned ? Strings.unpin : Strings.pin, systemImage: row.isPinned ? "pin.slash" : "pin")
            })
            Button(action: { presenter.renameAction(row) }, label: {
                Label(Strings.rename, systemImage: "pencil")
            })
            ShareLink(item: presenter.exportText(for: row.id)) {
                Label(Strings.share, systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive, action: { Task { await presenter.deleteAction(row.id) } }, label: {
                Label(Strings.delete, systemImage: "trash")
            })
        }
    }

    /// What VoiceOver adds after a chat's title: whether it is pinned, private, or both.
    private static func spokenMarks(for row: SidebarRowViewConfiguration) -> String {
        [row.isPinned ? Strings.pinned : "", row.isPrivate ? Strings.privateChat : ""].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    // MARK: Floating controls

    /// The settings and the new chat button, floating over the end of the list.
    private var floatingControls: some View {
        HStack(spacing: HearthSpacing.s12) {
            settingsButton
                .frame(maxWidth: .infinity, alignment: .leading)
            newChatButton
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.top, HearthSpacing.s28)
        .padding(.bottom, HearthSpacing.s10)
        .background {
            LinearGradient(colors: [HearthColor.paper.opacity(0), HearthColor.paper], startPoint: .top, endPoint: Self.fadeEnd)
                // The fade runs to the very bottom of the screen, so no chat shows beneath the buttons.
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    private var newChatButton: some View {
        Button(action: presenter.newChatAction) {
            Label(Strings.newChat, systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HearthColor.onPine)
                .padding(.horizontal, HearthSpacing.s18)
                .frame(height: HearthSize.floatingButton)
                .background(HearthColor.pine, in: Capsule())
                .hearthShadow(.floatingProminent)
        }
        .buttonStyle(.plain)
    }

    /// Opens the settings. Its dot shows whether the server can be reached.
    private var settingsButton: some View {
        let status = presenter.status
        return Button(action: presenter.settingsAction) {
            Image(systemName: "gearshape")
                .font(.body)
                .foregroundStyle(HearthColor.ink)
                .frame(width: HearthSize.floatingButton, height: HearthSize.floatingButton)
                .surface(Circle())
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(status.isOnline ? HearthColor.online : HearthColor.mute)
                        .frame(width: HearthSize.statusDot, height: HearthSize.statusDot)
                        // A ring of paper sets the dot apart from the button's edge.
                        .overlay { Circle().strokeBorder(HearthColor.paper, lineWidth: Self.statusDotRingWidth) }
                        .padding(HearthSpacing.s2)
                        .accessibilityHidden(true)
                }
                .hearthShadow(.floating)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.settings)
        .accessibilityValue("\(status.host), \(status.detail)")
    }
}
