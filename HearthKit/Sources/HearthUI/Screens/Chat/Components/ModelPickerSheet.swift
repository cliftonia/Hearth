import HearthDomain
import SwiftUI

/// The sheet opened from the composer's model chip: the server's models to choose from, and the effort that goes
/// into a reply: how hard the chosen model thinks, or deep research. While pictures are being made it lists the
/// picture models instead.
struct ModelPickerSheet: View {
    let presenter: ChatPresenter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let isPictureMode = presenter.viewModel.isPictureMode
        VStack(spacing: 0) {
            SheetHeader(title: isPictureMode ? Strings.pictureModelSheetTitle : Strings.modelSheetTitle) { dismiss() }
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
            if !isPictureMode {
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

    // MARK: Chat models

    /// The models on the server, then those in the cloud.
    @ViewBuilder private var chatModels: some View {
        let local = presenter.models.filter { !$0.isCloud }
        let cloud = presenter.models.filter(\.isCloud)
        if presenter.models.isEmpty {
            Text(Strings.noModel)
                .font(.hearth(.subheadline))
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
                .font(.hearth(.caption).weight(.medium))
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

    /// The mark beside an option in the effort menu: a tick for the chosen one, and nothing for the rest.
    nonisolated static func menuSymbol(isChosen: Bool) -> String? {
        isChosen ? "checkmark" : nil
    }

    /// The effort that goes into a reply: how hard the chosen model thinks before it, for a model that thinks, and
    /// deep research for any model. A menu, since the choices are few. Research is listed but cannot be chosen
    /// until there is a search address, and says so.
    private var effortRow: some View {
        let canThink = presenter.viewModel.selectedModel?.canThink == true
        let chosen = presenter.effortChoice
        let title = chosen.title(canThink: canThink)
        return Menu {
            ForEach(presenter.effortChoices, id: \.self) { option in
                let isAvailable = presenter.isEffortChoiceAvailable(option)
                Button(action: { presenter.selectEffortAction(option) }, label: {
                    // A symbol with no name is a fault in the system's symbol set, so an option not chosen has text alone.
                    if let symbol = Self.menuSymbol(isChosen: option == chosen) {
                        Label(option.title(canThink: canThink), systemImage: symbol)
                    } else {
                        Text(option.title(canThink: canThink))
                    }
                    if option == .research {
                        Text(isAvailable ? Strings.researchDetail : Strings.researchNeedsSearch)
                    }
                })
                .disabled(!isAvailable)
            }
        } label: {
            HStack(spacing: HearthSpacing.s8) {
                Text(Strings.effort)
                    .font(.hearth(.body))
                    .foregroundStyle(HearthColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(title)
                    .font(.hearth(.body))
                    .foregroundStyle(chosen == .research ? HearthColor.pine : HearthColor.mute)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s14)
            .cardSurface(radius: HearthRadius.bubble)
        }
        .accessibilityLabel(Strings.effort)
        .accessibilityValue(title)
        .haptic(.selection, trigger: chosen)
    }

    // MARK: Picture models

    @ViewBuilder private var pictureModels: some View {
        let models = presenter.viewModel.pictureModels
        if models.isEmpty {
            Text(Strings.pictureNoModelsYet)
                .font(.hearth(.subheadline))
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
                        .font(.hearth(.body))
                        .foregroundStyle(HearthColor.ink)
                        .lineLimit(1)
                    Text(detail)
                        .font(.hearth(.footnote))
                        .foregroundStyle(HearthColor.mute)
                        .lineLimit(1)
                        .frame(height: detail.isEmpty ? 0 : nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.hearth(.body).weight(.semibold))
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
