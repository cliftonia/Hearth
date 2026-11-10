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
            newChatButton
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
            statusFooter
        }
        .background(HearthColor.paper.ignoresSafeArea())
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

    private var newChatButton: some View {
        Button(action: presenter.newChatAction) {
            Label(Strings.newChat, systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HearthColor.pine)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HearthColor.pineSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
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
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func conversationRow(_ row: SidebarRowViewConfiguration) -> some View {
        let isSelected = row.id == presenter.selectedID
        return Button(action: { presenter.selectAction(row.id) }, label: {
            Text(row.title)
                .font(.subheadline)
                .foregroundStyle(HearthColor.ink)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? HearthColor.bubble : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button(role: .destructive, action: { Task { await presenter.deleteAction(row.id) } }, label: {
                Label(Strings.delete, systemImage: "trash")
            })
        }
    }

    private var statusFooter: some View {
        let status = presenter.status
        return Button(action: presenter.settingsAction) {
            HStack(spacing: 10) {
                Circle()
                    .fill(status.isOnline ? HearthColor.online : HearthColor.mute)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(status.host)
                        .font(.subheadline)
                        .foregroundStyle(HearthColor.ink)
                        .lineLimit(1)
                    Text(status.detail)
                        .font(.caption)
                        .foregroundStyle(HearthColor.mute)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(HearthColor.mute)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Rectangle().fill(HearthColor.line).frame(height: 1) }
        .accessibilityLabel(Strings.settings)
        .accessibilityValue("\(status.host), \(status.detail)")
    }
}
