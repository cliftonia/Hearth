import HearthDomain

extension EffortChoiceKind {
    /// The name shown in the effort menu and beside it.
    ///
    /// - Parameter canThink: Whether the chosen model thinks. One that does not has a single ordinary choice,
    ///   which is not named after a level it would ignore.
    func title(canThink: Bool) -> String {
        switch self {
        case .thinking(let level):
            canThink ? level.title : Strings.effortStandard
        case .research:
            Strings.research
        }
    }
}
