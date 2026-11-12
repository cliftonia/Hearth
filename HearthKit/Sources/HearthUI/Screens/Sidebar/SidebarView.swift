import HearthDomain
import SwiftUI

struct SidebarView: View {
    let presenter: SidebarPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let groups = presenter.groups
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HearthMark(sideLength: 26)
                Text(Strings.brand)
                    .font(HearthFont.brand)
                    .foregroundStyle(HearthColor.ink)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 14)
            searchField(text: $viewModel.query)
            ZStack(alignment: .top) {
                conversationList(groups: groups)
                Text(Strings.noChats)
                    .font(.subheadline)
                    .foregroundStyle(HearthColor.mute)
                    .padding(.top, 32)
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
    }

    private func searchField(text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            TextField(Strings.searchChats, text: text)
                .font(.subheadline)
                .foregroundStyle(HearthColor.ink)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(HearthColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HearthColor.line, lineWidth: 1) }
        .padding(.horizontal, 14)
    }

    private func conversationList(groups: [SidebarGroupViewConfiguration]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(groups) { group in
                    Text(group.title)
                        .font(.caption.weight(.medium))
                        .textCase(.uppercase)
                        .kerning(0.6)
                        .foregroundStyle(HearthColor.mute)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 4)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(group.rows) { row in
                        conversationRow(row)
                    }
                }
            }
            // Room for the last chat to be scrolled clear of the floating controls.
            .padding(.bottom, 84)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func conversationRow(_ row: SidebarRowViewConfiguration) -> some View {
        let isSelected = row.id == presenter.selectedID
        return Button(action: { presenter.selectAction(row.id) }, label: {
            HStack(spacing: 6) {
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
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(isSelected ? HearthColor.bubble : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
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

    /// The settings and the new chat button, floating over the end of the list.
    private var floatingControls: some View {
        HStack(spacing: 12) {
            settingsButton
                .frame(maxWidth: .infinity, alignment: .leading)
            newChatButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 10)
        .background {
            LinearGradient(colors: [HearthColor.paper.opacity(0), HearthColor.paper], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.4))
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
                .padding(.horizontal, 18)
                .frame(height: 48)
                .background(HearthColor.pine, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
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
                .frame(width: 48, height: 48)
                .background(HearthColor.card, in: Circle())
                .overlay { Circle().strokeBorder(HearthColor.line, lineWidth: 1) }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(status.isOnline ? HearthColor.online : HearthColor.mute)
                        .frame(width: 10, height: 10)
                        .overlay { Circle().strokeBorder(HearthColor.paper, lineWidth: 2) }
                        .padding(2)
                        .accessibilityHidden(true)
                }
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.settings)
        .accessibilityValue("\(status.host), \(status.detail)")
    }
}
