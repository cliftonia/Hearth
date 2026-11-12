import HearthDomain

extension ThinkingLevelKind {
    /// The name shown in the composer's thinking menu, and read out as the menu's value.
    var title: String {
        switch self {
        case .off:
            Strings.thinkingOff
        case .low:
            Strings.thinkingLight
        case .medium:
            Strings.thinkingMedium
        case .high:
            Strings.thinkingHigh
        }
    }
}
