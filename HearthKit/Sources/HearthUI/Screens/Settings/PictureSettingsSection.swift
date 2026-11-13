import HearthDomain
import SwiftUI

/// Which model new pictures are made with, and what else the picture server can do.
struct PictureSettingsSection: View {
    @Binding var model: ImageModelKind?
    let capabilities: ImageCapabilities

    var body: some View {
        Section {
            if capabilities.models.isEmpty {
                Text(Strings.pictureNoModels)
                    .font(.subheadline)
                    .foregroundStyle(HearthColor.mute)
            } else {
                Picker(Strings.pictureModel, selection: $model) {
                    Text(Strings.pictureModelAutomatic).tag(ImageModelKind?.none)
                    ForEach(capabilities.models, id: \.self) { kind in
                        Text(kind.title).tag(ImageModelKind?.some(kind))
                    }
                }
                ability(Strings.pictureCanChange, isThere: capabilities.canEdit)
                ability(Strings.pictureCanEnlarge, isThere: capabilities.canEnlarge)
            }
        } header: {
            Text(Strings.pictures)
        } footer: {
            Text(Strings.picturesFooter)
        }
    }

    /// One thing the server can or cannot do, with a tick or a dash.
    private func ability(_ title: String, isThere: Bool) -> some View {
        Label(title, systemImage: isThere ? "checkmark.circle.fill" : "minus.circle")
            .font(.subheadline)
            .foregroundStyle(isThere ? HearthColor.ink : HearthColor.mute)
            .accessibilityValue(isThere ? Strings.pictureAbilityThere : Strings.pictureAbilityMissing)
    }
}
