import HearthDomain
import SwiftUI

/// The chat list: the brand beside the search button, the projects, the chats grouped by day, and Settings and New
/// chat floating at the foot.
///
/// The projects, and the heading of a project whose chats are being looked at, are drawn in `SidebarView+Projects`;
/// the search field and its button in `SidebarView+Search`.
struct SidebarView: View {
    /// The gap beneath the settings and new chat buttons, the same as beneath the composer.
    #if targetEnvironment(macCatalyst)
    private static let footerBottomGap = HearthSpacing.macBottomEdge
    #else
    private static let footerBottomGap = HearthSpacing.s10
    #endif
    /// The vertical padding that gives each chat and each project its height.
    static let rowVerticalPadding: CGFloat = 11
    /// Room for the last chat to be scrolled clear of the floating controls, which grow with the text.
    @ScaledMetric(relativeTo: .subheadline) private var listBottomClearance: CGFloat = 74
    /// How far down the floating controls the list has faded out completely.
    private static let fadeEnd = UnitPoint(x: 0.5, y: 0.4)

    let presenter: SidebarPresenter

    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    /// The sections folded away beneath their headings, as `SidebarFolds` writes them, kept between launches.
    @AppStorage(SidebarFolds.storageKey) var foldedSections = ""
    /// The column a row's leading symbol sits in, which grows with the text so the symbol never runs into the name.
    @ScaledMetric(relativeTo: .footnote) var rowSymbolWidth: CGFloat = 20
    @FocusState var isSearchFocused: Bool

    /// How many lines a chat's or a project's name may take: one, and up to three at the accessibility sizes, where
    /// one line would hold only a word or two.
    var titleLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 3 : 1
    }

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let groups = presenter.groups
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: HearthSpacing.s10) {
                HearthMark(sideLength: 26)
                Text(Strings.brand)
                    .font(HearthFont.brand)
                    .foregroundStyle(HearthColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                searchButton
            }
            .padding(.leading, HearthSpacing.s18)
            .padding(.trailing, HearthSpacing.s14)
            .padding(.top, HearthSpacing.s4)
            .padding(.bottom, HearthSpacing.s8)
            searchField(text: $viewModel.query)
            conversationList(groups: groups)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) { floatingControls }
        }
        .background(HearthColor.paper.ignoresSafeArea())
        // Find on the keyboard, or Search Chats in the menu bar, puts the cursor in the search field.
        .onChange(of: viewModel.searchFocusRequestCount) {
            viewModel.isSearchOpen = true
            isSearchFocused = true
        }
        .alert(Strings.renameChat, isPresented: $viewModel.isRenaming) {
            TextField(Strings.chatTitle, text: $viewModel.renameDraft)
            Button(Strings.cancel, role: .cancel) {}
            Button(Strings.save) { Task { await presenter.commitRenameAction() } }
        }
        .alert(Strings.errorChangeFailed, isPresented: $viewModel.isShowingSaveFailure) {
            Button(Strings.ok, role: .cancel) {}
        }
        // The chat is handed to the dialog as it opens, so the answer deletes the one that was asked about.
        .confirmationDialog(
            Strings.deleteChatQuestion,
            isPresented: $viewModel.isConfirmingDelete,
            titleVisibility: .visible,
            presenting: viewModel.deletingID
        ) { id in
            Button(Strings.deleteChat, role: .destructive) {
                Haptics.play(.warning)
                Task { await presenter.confirmDeleteAction(id) }
            }
            Button(Strings.cancel, role: .cancel) {}
        } message: { id in
            Text(presenter.deleteDetail(for: id))
        }
    }

    // MARK: The list

    private func conversationList(groups: [SidebarGroupViewConfiguration]) -> some View {
        // Read once for the whole list. Among a project's own chats the project mark would say nothing, so it
        // shows only where every chat is listed.
        let isListingEveryChat = presenter.selectedProject == nil
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: HearthSpacing.s2) {
                projectsSection
                ForEach(groups) { group in
                    if let fold = group.id.foldKind {
                        foldingHeading(group.title, kind: fold, count: group.rows.count)
                    } else {
                        heading(group.title)
                    }
                    // Left out rather than folded, as folded rows would still be spaced apart in the stack.
                    if !(group.id.foldKind.map(isFolded) ?? false) {
                        ForEach(group.rows) { row in
                            // Keyed by everything it shows, so a row changed by another device while it moves between
                            // groups is drawn afresh rather than kept as it was.
                            conversationRow(row, hasProjectMark: row.isInProject && isListingEveryChat)
                                .id(row)
                        }
                    }
                }
                // The note keeps its place in the list when hidden, beneath whatever projects are listed.
                Text(isListingEveryChat ? Strings.noChats : Strings.noProjectChats)
                    .font(.hearth(.subheadline))
                    .foregroundStyle(HearthColor.mute)
                    .frame(maxWidth: .infinity)
                    .padding(.top, HearthSpacing.s32)
                    .folded(!groups.isEmpty)
            }
            .padding(.bottom, listBottomClearance + Self.footerBottomGap)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    /// The words above a group of rows, set in from the list's edge.
    func heading(_ title: String) -> some View {
        SectionHeading(title: title, isQuiet: true)
            .padding(.horizontal, HearthSpacing.s18)
            .padding(.top, HearthSpacing.s14)
            .padding(.bottom, HearthSpacing.s4)
    }

    /// One chat, behind the symbol that says what kind it is. A long press offers to pin or rename it, file it in a
    /// project, share it or delete it.
    private func conversationRow(_ row: SidebarRowViewConfiguration, hasProjectMark: Bool) -> some View {
        let isSelected = row.id == presenter.selectedID
        return Button(action: { presenter.selectAction(row.id) }, label: {
            HStack(spacing: HearthSpacing.s8) {
                // A clock marks the answer a scheduled task filed; every other chat has a speech bubble.
                Image(systemName: row.isFromTask ? "clock" : "bubble.left")
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
                    .frame(width: rowSymbolWidth)
                    .accessibilityHidden(true)
                Text(row.title)
                    .font(HearthFont.listRow)
                    .foregroundStyle(HearthColor.ink)
                    .lineLimit(titleLineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "folder")
                    .font(.hearth(.caption2))
                    .foregroundStyle(HearthColor.mute)
                    .opacity(hasProjectMark ? 1 : 0)
                    .frame(width: hasProjectMark ? nil : 0)
                    .accessibilityHidden(true)
                Image(systemName: "eye.slash")
                    .font(.hearth(.caption2))
                    .foregroundStyle(HearthColor.mute)
                    .opacity(row.isPrivate ? 1 : 0)
                    .frame(width: row.isPrivate ? nil : 0)
                    .accessibilityHidden(true)
                Image(systemName: "pin.fill")
                    .font(.hearth(.caption2))
                    .foregroundStyle(HearthColor.pine)
                    .opacity(row.isPinned ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s10)
            .padding(.vertical, Self.rowVerticalPadding)
            .background(isSelected ? HearthColor.bubble : .clear, in: RoundedRectangle(cornerRadius: HearthRadius.row, style: .continuous))
            .contentShape(Rectangle())
            .hoverHighlight(RoundedRectangle(cornerRadius: HearthRadius.row, style: .continuous))
        })
        .buttonStyle(.plain)
        .padding(.horizontal, HearthSpacing.s8)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(Self.spokenMarks(for: row))
        .contextMenu { conversationMenu(for: row) }
    }

    /// What VoiceOver adds after a chat's title: whether it is pinned, private, in a project, filed by a scheduled
    /// task, or several of these.
    private static func spokenMarks(for row: SidebarRowViewConfiguration) -> String {
        [
            row.isPinned ? Strings.pinned : "", row.isPrivate ? Strings.privateChat : "", row.isInProject ? Strings.inProject : "",
            row.isFromTask ? Strings.scheduledTaskMark : ""
        ]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    // MARK: Floating controls

    /// The settings and the new chat button, floating over the end of the list. While a project's chats are being
    /// looked at, the new chat is begun in that project.
    private var floatingControls: some View {
        HStack(spacing: HearthSpacing.s12) {
            settingsButton
                .frame(maxWidth: .infinity, alignment: .leading)
            newChatButton
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.top, HearthSpacing.s28)
        .padding(.bottom, Self.footerBottomGap)
        .background {
            LinearGradient(colors: [HearthColor.paper.opacity(0), HearthColor.paper], startPoint: .top, endPoint: Self.fadeEnd)
                // The fade runs to the very bottom of the screen, so no chat shows beneath the buttons.
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    /// A new chat; while a project's chats are being looked at, a new chat in that project, which it names.
    private var newChatButton: some View {
        let title = presenter.selectedProject.map { Strings.newChatIn(project: $0.name) } ?? Strings.newChat
        // At the largest text sizes the words wrap and the button grows taller, rather than shrinking to "+ …".
        return Button(action: presenter.newChatAction) {
            Label(title, systemImage: "plus")
                .font(.hearth(.subheadline).weight(.semibold))
                .foregroundStyle(HearthColor.onPine)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, HearthSpacing.s18)
                .padding(.vertical, HearthSpacing.s8)
                .frame(minHeight: HearthSize.floatingButton)
                .background(HearthColor.pine, in: RoundedRectangle(cornerRadius: HearthSize.floatingButton / 2, style: .continuous))
                .hearthShadow(.floatingProminent)
                .hoverHighlight(RoundedRectangle(cornerRadius: HearthSize.floatingButton / 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
    }

    /// Opens the settings. Its dot shows whether the server can be reached.
    private var settingsButton: some View {
        let status = presenter.status
        return Button(action: presenter.settingsAction) {
            Image(systemName: "gearshape")
                .font(.hearth(.body))
                .iconGlyphSize()
                .foregroundStyle(HearthColor.ink)
                .frame(width: HearthSize.floatingButton, height: HearthSize.floatingButton)
                .surface(Circle())
                .overlay(alignment: .topTrailing) { statusDot(isOnline: status.isOnline) }
                .hearthShadow(.floating)
                .hoverHighlight(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.settings)
        .accessibilityValue(Strings.serverStatusValue(host: status.host, detail: status.detail))
        .largeContentLabel(Strings.settings, systemImage: "gearshape")
    }
}
