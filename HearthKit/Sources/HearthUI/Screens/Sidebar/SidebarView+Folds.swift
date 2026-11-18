import SwiftUI

// The headings of the sections that fold away: Pinned, Scheduled tasks and Projects.
extension SidebarView {
    /// Whether a section's rows are hidden. Nothing is hidden while searching, so a match is never folded out of sight.
    func isFolded(_ kind: SidebarFoldKind) -> Bool {
        presenter.viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty && SidebarFolds(storedValue: foldedSections).isFolded(kind)
    }

    /// A heading that folds its section away when tapped, or opens it again. While folded it says how many rows it
    /// hides. It cannot be tapped while searching, when every section is open.
    func foldingHeading(_ title: String, kind: SidebarFoldKind, count: Int) -> some View {
        let isFolded = isFolded(kind)
        let isSearching = !presenter.viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty
        return Button(action: { toggleFold(kind) }, label: {
            HStack(spacing: HearthSpacing.s6) {
                SectionHeading(title: title, isQuiet: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(count, format: .number)
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
                    .opacity(isFolded ? 1 : 0)
                    .accessibilityHidden(true)
                Image(systemName: "chevron.down")
                    .font(.hearth(.caption2).weight(.semibold))
                    .foregroundStyle(HearthColor.mute)
                    .rotationEffect(.degrees(isFolded ? -90 : 0))
                    .opacity(isSearching ? 0 : 1)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s18)
            .padding(.top, HearthSpacing.s14)
            .padding(.bottom, HearthSpacing.s4)
            .contentShape(Rectangle())
            .minimumHitTarget()
        })
        .buttonStyle(.plain)
        .disabled(isSearching)
        .accessibilityLabel(title)
        .accessibilityValue(isFolded ? "\(Strings.collapsed), \(count.formatted())" : Strings.expanded)
        .accessibilityAddTraits(.isHeader)
    }

    private func toggleFold(_ kind: SidebarFoldKind) {
        var folds = SidebarFolds(storedValue: foldedSections)
        folds.toggle(kind)
        Haptics.play(.light)
        withAnimation(reduceMotion ? nil : .snappy) {
            foldedSections = folds.storedValue
        }
    }
}
