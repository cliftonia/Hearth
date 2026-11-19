import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// The project and task editors cannot lose changes silently: while anything has changed they cannot be swiped
/// away, and Cancel asks first.
@MainActor
struct EditorChangesTests {
    /// Records how the project sheet asked to close.
    @MainActor
    final class ProjectDelegate: ProjectPresenterDelegate {
        private(set) var outcomes: [ProjectOutcomeKind] = []

        func projectPresenter(_ presenter: ProjectPresenter, didFinishWith outcome: ProjectOutcomeKind) {
            outcomes.append(outcome)
        }
    }

    /// Counts the times the task editor asked to close.
    @MainActor
    final class TasksDelegate: ScheduledTasksPresenterDelegate {
        private(set) var closeCount = 0

        func scheduledTasksPresenterDidCloseEditor(_ presenter: ScheduledTasksPresenter) {
            closeCount += 1
        }

        func scheduledTasksPresenterDidRequestSync(_ presenter: ScheduledTasksPresenter) {}
    }

    private func makeProjectSubject(delegate: ProjectDelegate) -> ProjectPresenter {
        let projects = PresenterFixtures.projectStore()
        let conversations = PresenterFixtures.conversationStore()
        let subject = ProjectPresenter(
            projectStore: projects,
            conversationStore: conversations,
            interactor: ProjectInteractor(projectStore: projects, conversationStore: conversations)
        )
        subject.delegate = delegate
        subject.begin()
        return subject
    }

    private func makeTasksSubject(delegate: TasksDelegate) async -> ScheduledTasksPresenter {
        let subject = await ScheduledTasksPresenterTests.Fixture().makeTestSubject()
        subject.delegate = delegate
        subject.addAction()
        return subject
    }

    // MARK: Projects

    @Test func `a project sheet just opened has no changes and closes at once`() {
        let delegate = ProjectDelegate()
        let subject = makeProjectSubject(delegate: delegate)

        subject.cancelAction()

        #expect(!subject.viewModel.hasChanges)
        #expect(delegate.outcomes == [.cancelled])
    }

    @Test(arguments: ["name", "instructions", "file"])
    func `any change to a project asks before cancelling`(_ change: String) {
        let delegate = ProjectDelegate()
        let subject = makeProjectSubject(delegate: delegate)
        switch change {
        case "name":
            subject.viewModel.name = "Garden"
        case "instructions":
            subject.viewModel.instructions = "Be brief"
        default:
            subject.addDocumentsAction([AttachedDocument(name: "plan.txt", text: "Beds")], unreadableCount: 0)
        }

        subject.cancelAction()

        #expect(subject.viewModel.hasChanges)
        #expect(subject.viewModel.isConfirmingDiscard)
        #expect(delegate.outcomes.isEmpty)
    }

    @Test func `discarding a project's changes closes the sheet`() {
        let delegate = ProjectDelegate()
        let subject = makeProjectSubject(delegate: delegate)
        subject.viewModel.name = "Garden"
        subject.cancelAction()

        subject.discardChangesAction()

        #expect(!subject.viewModel.isConfirmingDiscard)
        #expect(delegate.outcomes == [.cancelled])
    }

    @Test func `undoing a change by hand leaves nothing to ask about`() {
        // Held here, as the presenter holds its delegate weakly.
        let delegate = ProjectDelegate()
        let subject = makeProjectSubject(delegate: delegate)
        subject.viewModel.name = "Garden"
        subject.viewModel.name = ""

        #expect(!subject.viewModel.hasChanges)
    }

    // MARK: Tasks

    @Test func `a task editor just opened has no changes and closes at once`() async {
        let delegate = TasksDelegate()
        let subject = await makeTasksSubject(delegate: delegate)

        subject.cancelAction()

        #expect(!subject.hasEditorChanges)
        #expect(delegate.closeCount == 1)
        #expect(!subject.viewModel.isEditorPresented)
    }

    @Test func `a changed task asks before cancelling, and discarding closes it`() async {
        let delegate = TasksDelegate()
        let subject = await makeTasksSubject(delegate: delegate)
        subject.viewModel.scheduleKind = .weekly

        subject.cancelAction()

        #expect(subject.hasEditorChanges)
        #expect(subject.viewModel.isConfirmingDiscard)
        #expect(delegate.closeCount == 0)

        subject.discardChangesAction()

        #expect(delegate.closeCount == 1)
        #expect(!subject.viewModel.isEditorPresented)
    }
}
