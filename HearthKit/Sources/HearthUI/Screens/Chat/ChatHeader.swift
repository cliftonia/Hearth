import HearthDomain
import SwiftUI

/// The bar above the chat: the chat list, the model picker and a new chat.
struct ChatHeader: View {
    let presenter: ChatPresenter

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        // On a wide screen the conversations are always in view, so there is no drawer to open.
        let hasDrawer = horizontalSizeClass != .regular
        HStack(spacing: 8) {
            IconButton(systemImage: "line.3.horizontal", label: Strings.menuLabel, action: presenter.sidebarAction)
                .opacity(hasDrawer ? 1 : 0)
                .allowsHitTesting(hasDrawer)
                .accessibilityHidden(!hasDrawer)
            modelMenu
                .frame(maxWidth: .infinity)
            IconButton(systemImage: "square.and.pencil", label: Strings.newChat) {
                Task { await presenter.newChatAction() }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var modelMenu: some View {
        let selected = presenter.viewModel.selectedModel
        return Menu {
            modelSection(title: Strings.localModels, models: presenter.models.filter { !$0.isCloud })
            modelSection(title: Strings.cloudModels, models: presenter.models.filter(\.isCloud))
        } label: {
            HStack(spacing: 6) {
                Text(selected?.displayName ?? Strings.noModel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HearthColor.ink)
                    .lineLimit(1)
                Text(selected.map { $0.isCloud ? Strings.cloudTag : Strings.localTag } ?? "")
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(HearthColor.mute)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(HearthColor.card, in: Capsule())
            .overlay { Capsule().strokeBorder(HearthColor.line, lineWidth: 1) }
        }
        .accessibilityLabel(Strings.modelPickerLabel)
        .accessibilityValue(selected?.displayName ?? Strings.noModel)
    }

    private func modelSection(title: String, models: [ChatModel]) -> some View {
        Section(title) {
            ForEach(models) { model in
                Button(action: { presenter.selectModelAction(model) }, label: {
                    Label(model.displayName, systemImage: model == presenter.viewModel.selectedModel ? "checkmark" : "")
                })
            }
        }
    }
}
