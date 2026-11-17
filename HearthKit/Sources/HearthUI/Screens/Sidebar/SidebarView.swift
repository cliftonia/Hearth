import HearthDomain
import SwiftUI

/// The chat list: the brand, a search field, the projects, the chats grouped by day, and Settings and New chat
/// floating at the foot.
///
/// The projects, and the heading of a project whose chats are being looked at, are drawn in `SidebarView+Projects`.
struct SidebarView: View {
    /// The gap beneath the settings and new chat buttons, the same as beneath the composer.
    #if targetEnvironment(macCatalyst)
    private static let footerBottomGap = HearthSpacing.macBottomEdge
    #else
    private static let footerBottomGap = HearthSpacing.s10
    #endif
    /// The vertical padding that gives the search field and each chat their height.
    static let rowVerticalPadding: CGFloat = 9
    /// Room for the last chat to be scrolled clear of the floating controls.
    private static let listBottomClearance: CGFloat = 74 + footerBottomGap
    private static let statusDotRingWidth: CGFloat = 2
    /// The headings above the groups are spaced out a little, to read as labels.
    private static let headingKerning: CGFloat = 0.6
    /// How far down the floating controls the list has faded out completely.
    private static let fadeEnd = UnitPoint(x: 0.5, y: 0.4)

    let presenter: SidebarPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let groups = presenter.groups
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: HearthSpacing.s10) {
                HearthMark(sideLength: 26)
                Text(Strings.brand)
                    .font(HearthFont.brand)
                    .foregroundStyle(HearthColor.ink)
            }
            .padding(.horizontal, HearthSpacing.s18)
            .padding(.top, HearthSpacing.s8)
            .padding(.bottom, HearthSpacing.s14)
            searchField(text: $viewModel.query)
            conversationList(groups: groups)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) { floatingControls }
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .alert(Strings.renameChat, isPresented: $viewModel.isRenaming) {
            TextField(Strings.chatTitle, text: $viewModel.renameDraft)
            Button(Strings.cancel, role: .cancel) {}
            Button(Strings.save) { Task { await presenter.commitRenameAction() } }
        }
        .alert(Strings.errorChangeFailed, isPresented: $viewModel.isShowingSaveFailure) {
            Button(Strings.ok, role: .cancel) {}
        }
    }

    // MARK: Search and list

    private func searchField(text: Binding<String>) -> some View {
        HStack(spacing: HearthSpacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.hearth(.footnote))
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            TextField(Strings.searchChats, text: text)
                .font(.hearth(.subheadline))
                .foregroundStyle(HearthColor.ink)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, HearthSpacing.s12)
        .padding(.vertical, Self.rowVerticalPadding)
        .cardSurface()
        .padding(.horizontal, HearthSpacing.s14)
    }

    private func conversationList(groups: [SidebarGroupViewConfiguration]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: HearthSpacing.s2) {
                projectsSection
                ForEach(groups) { group in
                    heading(group.title)
                    ForEach(group.rows) { row in
                        // Keyed by everything it shows, so a row changed by another device while it moves between
                        // groups is drawn afresh rather than kept as it was.
                        conversationRow(row)
                            .id(row)
                    }
                }
                // The note keeps its place in the list when hidden, beneath the projects, which are always there.
                Text(presenter.selectedProject == nil ? Strings.noChats : Strings.noProjectChats)
                    .font(.hearth(.subheadline))
                    .foregroundStyle(HearthColor.mute)
                    .frame(maxWidth: .infinity)
                    .padding(.top, HearthSpacing.s32)
                    .folded(!groups.isEmpty)
            }
            .padding(.bottom, Self.listBottomClearance)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    /// The small capitals above a group of rows, set in from the list's edge.
    func heading(_ title: String) -> some View {
        SectionHeading(title: title, kerning: Self.headingKerning)
            .padding(.horizontal, HearthSpacing.s18)
            .padding(.top, HearthSpacing.s14)
            .padding(.bottom, HearthSpacing.s4)
    }

    /// One chat. A long press offers to pin or rename it, file it in a project, share it or delete it.
    private func conversationRow(_ row: SidebarRowViewConfiguration) -> some View {
        let isSelected = row.id == presenter.selectedID
        // Among a project's own chats the mark would say nothing, so it shows only where every chat is listed.
        let hasProjectMark = row.isInProject && presenter.selectedProject == nil
        return Button(action: { presenter.selectAction(row.id) }, label: {
            HStack(spacing: HearthSpacing.s6) {
                VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                    Text(row.title)
                        .font(.hearth(.subheadline))
                        .foregroundStyle(HearthColor.ink)
                        .lineLimit(1)
                    Label(row.isFromTask ? Strings.scheduledTaskMark : "", systemImage: "clock")
                        .font(.hearth(.caption2))
                        .foregroundStyle(HearthColor.mute)
                        .lineLimit(1)
                        .folded(!row.isFromTask)
                        .accessibilityHidden(true)
                }
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
        })
        .buttonStyle(.plain)
        .padding(.horizontal, HearthSpacing.s8)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(Self.spokenMarks(for: row))
        .contextMenu { conversationMenu(for: row) }
    }

    /// What a long press on a chat offers: pin, rename, a project to file it in or leave, share and delete.
    @ViewBuilder
    private func conversationMenu(for row: SidebarRowViewConfiguration) -> some View {
        Button(action: {
            Haptics.play(.light)
            Task { await presenter.pinAction(row) }
        }, label: {
            Label(row.isPinned ? Strings.unpin : Strings.pin, systemImage: row.isPinned ? "pin.slash" : "pin")
        })
        Button(action: { presenter.renameAction(row) }, label: {
            Label(Strings.rename, systemImage: "pencil")
        })
        Button(action: { presenter.addToProjectAction(row) }, label: {
            Label(Strings.addToProjectEllipsis, systemImage: "folder.badge.plus")
        })
        if row.isInProject {
            Button(action: { Task { await presenter.removeFromProjectAction(row) } }, label: {
                Label(Strings.removeFromProject, systemImage: "folder.badge.minus")
            })
        }
        ShareLink(item: presenter.exportText(for: row.id)) {
            Label(Strings.share, systemImage: "square.and.arrow.up")
        }
        Button(role: .destructive, action: {
            Haptics.play(.warning)
            Task { await presenter.deleteAction(row.id) }
        }, label: {
            Label(Strings.delete, systemImage: "trash")
        })
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

    private var newChatButton: some View {
        Button(action: presenter.newChatAction) {
            Label(Strings.newChat, systemImage: "plus")
                .font(.hearth(.subheadline).weight(.semibold))
                .foregroundStyle(HearthColor.onPine)
                .padding(.horizontal, HearthSpacing.s18)
                .frame(height: HearthSize.floatingButton)
                .background(HearthColor.pine, in: Capsule())
                .hearthShadow(.floatingProminent)
        }
        .buttonStyle(.plain)
    }

    /// Opens the settings. Its dot shows whether the server can be reached.
    private var settingsButton: some View {
        let status = presenter.status
        return Button(action: presenter.settingsAction) {
            Image(systemName: "gearshape")
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .frame(width: HearthSize.floatingButton, height: HearthSize.floatingButton)
                .surface(Circle())
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(status.isOnline ? HearthColor.online : HearthColor.mute)
                        .frame(width: HearthSize.statusDot, height: HearthSize.statusDot)
                        // A ring of paper sets the dot apart from the button's edge.
                        .overlay { Circle().strokeBorder(HearthColor.paper, lineWidth: Self.statusDotRingWidth) }
                        .padding(HearthSpacing.s2)
                        .accessibilityHidden(true)
                }
                .hearthShadow(.floating)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.settings)
        .accessibilityValue(Strings.serverStatusValue(host: status.host, detail: status.detail))
    }
}
