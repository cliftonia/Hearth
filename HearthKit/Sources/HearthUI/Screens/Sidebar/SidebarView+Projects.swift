import HearthDomain
import SwiftUI

// What stands above the dated groups: the projects, or the heading of the one whose chats are being looked at.
extension SidebarView {
    /// The list of projects while every chat is shown; once one is chosen, the way back, its name and what can be
    /// done with it. The two are different things, so one replaces the other.
    @ViewBuilder var projectsSection: some View {
        if let project = presenter.selectedProject {
            projectHeader(project)
        } else {
            projectList
        }
    }

    /// The projects under their own heading, which is left out while there are none to list. While searching, only
    /// the projects whose names match are listed. New projects are made from the composer's plus menu.
    @ViewBuilder private var projectList: some View {
        let projects = presenter.projects
        if !projects.isEmpty {
            heading(Strings.projects)
        }
        ForEach(projects) { project in
            projectRow(title: project.name, systemImage: "folder", tint: HearthColor.ink, symbolTint: HearthColor.mute) {
                presenter.selectProjectAction(project.id)
            }
        }
    }

    /// The way back to every chat, then the project's name beside the button for its settings, then a new chat in it.
    @ViewBuilder
    private func projectHeader(_ project: ProjectRowViewConfiguration) -> some View {
        projectRow(title: Strings.allChats, systemImage: "chevron.left", tint: HearthColor.mute, symbolTint: HearthColor.mute, action: presenter.allChatsAction)
            .padding(.top, HearthSpacing.s8)
        HStack(spacing: HearthSpacing.s8) {
            Image(systemName: "folder.fill")
                .font(.hearth(.subheadline))
                .foregroundStyle(HearthColor.pine)
                .accessibilityHidden(true)
            Text(project.name)
                .font(.hearth(.headline))
                .foregroundStyle(HearthColor.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            IconButton(systemImage: "slider.horizontal.3", label: Strings.projectSettings, action: presenter.projectSettingsAction)
        }
        .padding(.leading, HearthSpacing.s18)
        .padding(.trailing, HearthSpacing.s8)
        projectRow(
            title: Strings.newChatInProject,
            systemImage: "square.and.pencil",
            tint: HearthColor.pine,
            symbolTint: HearthColor.pine,
            action: presenter.newChatAction
        )
    }

    /// A row the height of a chat's, with a symbol before its words, each in its own colour.
    private func projectRow(title: String, systemImage: String, tint: Color, symbolTint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: HearthSpacing.s8) {
                Image(systemName: systemImage)
                    .font(.hearth(.footnote))
                    .foregroundStyle(symbolTint)
                    .frame(width: HearthSpacing.s20)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.hearth(.subheadline))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, HearthSpacing.s10)
            .padding(.vertical, Self.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, HearthSpacing.s8)
    }
}
