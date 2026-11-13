import HearthDomain
import SwiftUI

/// The bar above the chat: the chat list, the model picker and the private chat switch.
struct ChatHeader: View {
    let presenter: ChatPresenter

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        // A narrow screen opens the chats as a drawer; a wide one shows them beside the chat or puts them away.
        let isWide = horizontalSizeClass == .regular
        HStack(spacing: HearthSpacing.s8) {
            IconButton(
                systemImage: isWide ? "sidebar.left" : "line.3.horizontal",
                label: isWide ? Strings.sidebarToggle : Strings.menuLabel,
                action: presenter.sidebarAction
            )
            // While pictures are being made the chat model takes no part, so the picture models are offered in its place.
            ZStack {
                modelMenu
                    .opacity(presenter.viewModel.isPictureMode ? 0 : 1)
                    .allowsHitTesting(!presenter.viewModel.isPictureMode)
                    .accessibilityHidden(presenter.viewModel.isPictureMode)
                pictureModelMenu
                    .opacity(presenter.viewModel.isPictureMode ? 1 : 0)
                    .allowsHitTesting(presenter.viewModel.isPictureMode)
                    .accessibilityHidden(!presenter.viewModel.isPictureMode)
            }
            .frame(maxWidth: .infinity)
            privateToggle
        }
        .padding(.horizontal, HearthSpacing.s8)
        .padding(.vertical, HearthSpacing.s4)
    }

    /// Makes a chat that has not yet begun private. Once the chat has begun it only shows that the chat is private.
    private var privateToggle: some View {
        let conversation = presenter.viewModel.conversation
        let isPrivate = conversation.isPrivate
        let canChange = conversation.messages.isEmpty && presenter.isServerConfigured
        let isShown = canChange || isPrivate
        return Button(action: presenter.togglePrivateAction) {
            Image(systemName: isPrivate ? "eye.slash.fill" : "eye.slash")
                .font(HearthFont.icon)
                .foregroundStyle(isPrivate ? HearthColor.pine : HearthColor.ink)
                .frame(width: HearthSize.iconButton, height: HearthSize.iconButton)
                .background(isPrivate ? HearthColor.pineSoft : .clear, in: Circle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.privateChat)
        .accessibilityAddTraits(isPrivate ? .isSelected : [])
        .opacity(isShown ? 1 : 0)
        .allowsHitTesting(canChange)
        .accessibilityHidden(!isShown)
        .animation(.snappy, value: isPrivate)
    }

    /// The chosen model in a pill; tapping it lists the server's models, local ones first.
    private var modelMenu: some View {
        let selected = presenter.viewModel.selectedModel
        return Menu {
            modelSection(title: Strings.localModels, models: presenter.models.filter { !$0.isCloud })
            modelSection(title: Strings.cloudModels, models: presenter.models.filter(\.isCloud))
        } label: {
            HStack(spacing: HearthSpacing.s6) {
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
            .padding(.horizontal, HearthSpacing.s14)
            .padding(.vertical, HearthSpacing.s8)
            .capsuleSurface()
        }
        .accessibilityLabel(Strings.modelPickerLabel)
        .accessibilityValue(selected?.displayName ?? Strings.noModel)
    }

    /// The model pictures are made with, in the same pill; tapping it lists the picture models the server has.
    private var pictureModelMenu: some View {
        let selected = presenter.selectedPictureModel
        return Menu {
            Section(Strings.pictureModels) {
                ForEach(presenter.viewModel.pictureModels, id: \.self) { model in
                    Button(action: { presenter.selectPictureModelAction(model) }, label: {
                        Label(model.title, systemImage: model == selected ? "checkmark" : "")
                    })
                }
            }
        } label: {
            HStack(spacing: HearthSpacing.s6) {
                Image(systemName: "paintbrush.fill")
                    .font(.caption)
                    .foregroundStyle(HearthColor.pine)
                    .accessibilityHidden(true)
                Text(selected?.name ?? Strings.pictures)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HearthColor.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(HearthColor.mute)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s14)
            .padding(.vertical, HearthSpacing.s8)
            .capsuleSurface()
        }
        .accessibilityLabel(Strings.pictureModelPickerLabel)
        .accessibilityValue(selected?.name ?? "")
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
