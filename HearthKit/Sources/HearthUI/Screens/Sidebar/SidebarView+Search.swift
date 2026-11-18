import SwiftUI

// Searching the chats: a round button beside the brand, like those at the top of a chat, and the field it opens beneath.
extension SidebarView {
    /// Opens the search field and puts the cursor in it, or closes it and forgets what was searched for.
    func searchButton(isOpen: Binding<Bool>) -> some View {
        let isShowing = isOpen.wrappedValue || !presenter.viewModel.query.isEmpty
        return GlassCircleButton(systemImage: isShowing ? "xmark" : "magnifyingglass", label: isShowing ? Strings.closeSearch : Strings.searchChats) {
            withAnimation(reduceMotion ? nil : .snappy) {
                isOpen.wrappedValue = !isShowing
            }
            if isShowing {
                presenter.viewModel.query = ""
            }
            isSearchFocused = !isShowing
        }
    }

    /// The search field, folded away until it is opened or holds words.
    func searchField(text: Binding<String>, isOpen: Binding<Bool>) -> some View {
        let isShowing = isOpen.wrappedValue || !text.wrappedValue.isEmpty
        return HStack(spacing: HearthSpacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.hearth(.footnote))
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            TextField(Strings.searchChats, text: text)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
        }
        .padding(.horizontal, HearthSpacing.s12)
        .padding(.vertical, HearthSpacing.s10)
        .cardSurface()
        .padding(.horizontal, HearthSpacing.s14)
        .padding(.bottom, HearthSpacing.s4)
        .folded(!isShowing)
    }
}
