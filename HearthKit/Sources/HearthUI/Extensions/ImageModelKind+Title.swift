import HearthDomain

extension ImageModelKind {
    /// The model's name with a word on what it is best at.
    var title: String {
        switch self {
        case .zImageTurbo:
            Strings.pictureModelZImage
        case .krea2Turbo:
            Strings.pictureModelKrea
        case .juggernautXL:
            Strings.pictureModelJuggernaut
        }
    }

    /// The model's name alone, as it is known.
    var name: String {
        switch self {
        case .zImageTurbo:
            "Z-Image Turbo"
        case .krea2Turbo:
            "Krea 2 Turbo"
        case .juggernautXL:
            "Juggernaut XL"
        }
    }

    /// A few words on what the model is best at.
    var blurb: String {
        switch self {
        case .zImageTurbo:
            Strings.pictureBlurbZImage
        case .krea2Turbo:
            Strings.pictureBlurbKrea
        case .juggernautXL:
            Strings.pictureBlurbJuggernaut
        }
    }
}
