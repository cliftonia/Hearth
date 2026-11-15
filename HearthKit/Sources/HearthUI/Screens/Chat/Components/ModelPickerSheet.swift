import HearthDomain
import SwiftUI

/// The sheet opened from the composer's model chip: the server's models to choose from, and how hard the chosen
/// one should think. While pictures are being made it lists the picture models instead.
struct ModelPickerSheet: View {
    private static let closeButtonSide: CGFloat = 36

    let presenter: ChatPresenter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let isPictureMode = presenter.viewModel.isPictureMode
        VStack(spacing: 0) {
            header(title: isPictureMode ? Strings.pictureModelSheetTitle : Strings.modelSheetTitle)
            ScrollView {
                VStack(alignment: .leading, spacing: HearthSpacing.s16) {
                    if isPictureMode {
                        pictureModels
                    } else {
                        chatModels
                    }
                }
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.bottom, HearthSpacing.s16)
            }
            // The effort stays in view below the list, however many models the server has.
            if !isPictureMode, presenter.viewModel.selectedModel?.canThink == true {
                effortRow
                    .padding(.horizontal, HearthSpacing.s16)
                    .padding(.top, HearthSpacing.s8)
                    .padding(.bottom, HearthSpacing.s16)
            }
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func header(title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(HearthColor.ink)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                Button(action: { dismiss() }, label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HearthColor.ink)
                        .frame(width: Self.closeButtonSide, height: Self.closeButtonSide)
                        .surface(Circle())
                })
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.close)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.top, HearthSpacing.s24)
            .padding(.bottom, HearthSpacing.s16)
    }

    // MARK: Chat models

    /// The models on the server, then those in the cloud.
    @ViewBuilder private var chatModels: some View {
        let local = presenter.models.filter { !$0.isCloud }
        let cloud = presenter.models.filter(\.isCloud)
        if presenter.models.isEmpty {
            Text(Strings.noModel)
                .font(.subheadline)
                .foregroundStyle(HearthColor.mute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HearthSpacing.s24)
        }
        if !local.isEmpty {
            group(title: Strings.localModels, models: local)
        }
        if !cloud.isEmpty {
            group(title: Strings.cloudModels, models: cloud)
        }
    }

    private func group(title: String, models: [ChatModel]) -> some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s6) {
            Text(title)
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(HearthColor.mute)
                .padding(.horizontal, HearthSpacing.s4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(models) { model in
                    row(
                        title: model.displayName,
                        detail: Self.detail(for: model),
                        isSelected: model == presenter.viewModel.selectedModel,
                        action: { presenter.selectModelAction(model) }
                    )
                    Hairline(axis: .horizontal)
                        .padding(.leading, HearthSpacing.s16)
                        .opacity(model.id == models.last?.id ? 0 : 1)
                }
            }
            .cardSurface(radius: HearthRadius.bubble)
        }
    }

    /// What a model can do beyond answering in words, as a line under its name.
    private static func detail(for model: ChatModel) -> String {
        [
            model.canThink ? Strings.modelThinks : "",
            model.canSee ? Strings.modelSees : "",
            model.canUseTools ? Strings.modelSearches : ""
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }

    /// How hard the chosen model thinks before it replies. A menu, since there are only four levels.
    private var effortRow: some View {
        let level = presenter.thinkingLevel
        return Menu {
            ForEach(ThinkingLevelKind.allCases, id: \.self) { option in
                Button(action: { presenter.selectThinkingLevelAction(option) }, label: {
                    Label(option.title, systemImage: option == level ? "checkmark" : "")
                })
            }
        } label: {
            HStack(spacing: HearthSpacing.s8) {
                Text(Strings.effort)
                    .font(.body)
                    .foregroundStyle(HearthColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(level.title)
                    .font(.body)
                    .foregroundStyle(HearthColor.mute)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote)
                    .foregroundStyle(HearthColor.mute)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s14)
            .cardSurface(radius: HearthRadius.bubble)
        }
        .accessibilityLabel(Strings.effort)
        .accessibilityValue(level.title)
    }

    // MARK: Picture models

    @ViewBuilder private var pictureModels: some View {
        let models = presenter.viewModel.pictureModels
        if models.isEmpty {
            Text(Strings.pictureNoModelsYet)
                .font(.subheadline)
                .foregroundStyle(HearthColor.mute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HearthSpacing.s24)
        } else {
            VStack(spacing: 0) {
                ForEach(models, id: \.self) { model in
                    row(
                        title: model.name,
                        detail: model.blurb,
                        isSelected: model == presenter.selectedPictureModel,
                        action: { presenter.selectPictureModelAction(model) }
                    )
                    Hairline(axis: .horizontal)
                        .padding(.leading, HearthSpacing.s16)
                        .opacity(model == models.last ? 0 : 1)
                }
            }
            .cardSurface(radius: HearthRadius.bubble)
        }
    }

    // MARK: Rows

    /// One model: its name, what it is good for, and a tick if it is the one chosen. Choosing closes the sheet.
    private func row(title: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.play(.selection)
            action()
            dismiss()
        }, label: {
            HStack(spacing: HearthSpacing.s12) {
                VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(HearthColor.ink)
                        .lineLimit(1)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(HearthColor.mute)
                        .lineLimit(1)
                        .frame(height: detail.isEmpty ? 0 : nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(HearthColor.pine)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s12)
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
