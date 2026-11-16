import HearthDomain
import SwiftUI

/// Which model new pictures are made with, and what else the picture server can do.
struct PicturesPage: View {
    let presenter: SettingsPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let capabilities = viewModel.imageCapabilities
        SettingsPage(title: Strings.pictures) {
            SettingsCard(footer: Strings.picturesFooter) {
                if capabilities.models.isEmpty {
                    Text(Strings.pictureNoModels)
                        .font(.hearth(.subheadline))
                        .foregroundStyle(HearthColor.mute)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, HearthSpacing.s16)
                        .padding(.vertical, HearthSpacing.s12)
                } else {
                    modelPicker(selection: $viewModel.imageModel, models: capabilities.models)
                    Hairline()
                        .padding(.leading, HearthSpacing.s16)
                    ability(Strings.pictureCanChange, isThere: capabilities.canEdit)
                    ability(Strings.pictureCanEnlarge, isThere: capabilities.canEnlarge)
                }
            }
        }
    }

    /// The model, chosen from a menu of those the server has, with Automatic first.
    private func modelPicker(selection: Binding<ImageModelKind?>, models: [ImageModelKind]) -> some View {
        HStack(spacing: HearthSpacing.s12) {
            Text(Strings.pictureModel)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .accessibilityHidden(true)
            Picker(Strings.pictureModel, selection: selection) {
                Text(Strings.pictureModelAutomatic).tag(ImageModelKind?.none)
                ForEach(models, id: \.self) { kind in
                    Text(kind.title).tag(ImageModelKind?.some(kind))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(Strings.pictureModel)
            .onChange(of: selection.wrappedValue) { presenter.keepAction() }
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s8)
    }

    /// One thing the server can or cannot do, with a tick or a dash.
    private func ability(_ title: String, isThere: Bool) -> some View {
        Label(title, systemImage: isThere ? "checkmark.circle.fill" : "minus.circle")
            .font(.hearth(.subheadline))
            .foregroundStyle(isThere ? HearthColor.ink : HearthColor.mute)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s10)
            .accessibilityValue(isThere ? Strings.pictureAbilityThere : Strings.pictureAbilityMissing)
    }
}
