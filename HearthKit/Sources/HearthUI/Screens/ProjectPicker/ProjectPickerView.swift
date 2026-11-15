import HearthDomain
import SwiftUI

/// The sheet that files a chat: the projects to choose from, then a new project and, for a chat already in one,
/// the way out of it.
struct ProjectPickerView: View {
    private static let closeButtonSide: CGFloat = 36

    let presenter: ProjectPickerPresenter

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        let projects = presenter.projects
        VStack(spacing: 0) {
            header(title: presenter.isMoving ? Strings.moveToProject : Strings.addToProject)
            ScrollView {
                VStack(alignment: .leading, spacing: HearthSpacing.s16) {
                    Text(Strings.noProjects)
                        .font(.subheadline)
                        .foregroundStyle(HearthColor.mute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, projects.isEmpty ? HearthSpacing.s8 : 0)
                        .opacity(projects.isEmpty ? 1 : 0)
                        .frame(height: projects.isEmpty ? nil : 0)
                        .accessibilityHidden(!projects.isEmpty)
                    projectRows(projects, currentID: viewModel.currentProjectID)
                        .opacity(projects.isEmpty ? 0 : 1)
                        .frame(height: projects.isEmpty ? 0 : nil)
                        .accessibilityHidden(projects.isEmpty)
                    otherRows
                }
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.bottom, HearthSpacing.s16)
            }
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert(Strings.errorChangeFailed, isPresented: $viewModel.isShowingSaveFailure) {
            Button(Strings.ok, role: .cancel) {}
        }
    }

    private func header(title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(HearthColor.ink)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                Button(action: presenter.closeAction) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HearthColor.ink)
                        .frame(width: Self.closeButtonSide, height: Self.closeButtonSide)
                        .surface(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.close)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.top, HearthSpacing.s24)
            .padding(.bottom, HearthSpacing.s16)
    }

    // MARK: Rows

    /// The saved projects in one card, the chat's present one ticked.
    private func projectRows(_ projects: [ProjectRowViewConfiguration], currentID: Project.ID?) -> some View {
        VStack(spacing: 0) {
            ForEach(projects) { project in
                row(title: project.name, systemImage: "folder", tint: HearthColor.ink, isSelected: project.id == currentID) {
                    Task { await presenter.chooseAction(project.id) }
                }
                Hairline(axis: .horizontal)
                    .padding(.leading, HearthSpacing.s16)
                    .opacity(project.id == projects.last?.id ? 0 : 1)
            }
        }
        .cardSurface(radius: HearthRadius.bubble)
    }

    /// A new project for the chat to go in and, when the chat is in one already, the way out of it.
    private var otherRows: some View {
        VStack(spacing: 0) {
            row(title: Strings.newProjectEllipsis, systemImage: "folder.badge.plus", tint: HearthColor.pine, isSelected: false) {
                presenter.newProjectAction()
            }
            if presenter.isMoving {
                Hairline(axis: .horizontal)
                    .padding(.leading, HearthSpacing.s16)
                row(title: Strings.removeFromProject, systemImage: "folder.badge.minus", tint: HearthColor.danger, isSelected: false) {
                    Task { await presenter.chooseAction(nil) }
                }
            }
        }
        .cardSurface(radius: HearthRadius.bubble)
    }

    /// One choice: a symbol, its words, and a tick if it is how things stand now.
    private func row(title: String, systemImage: String, tint: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: HearthSpacing.s12) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(tint)
                    .frame(width: HearthSpacing.s24)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(HearthColor.pine)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, HearthSpacing.s16)
            .padding(.vertical, HearthSpacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
