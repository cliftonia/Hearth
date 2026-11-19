import Foundation
import HearthDomain
@testable import HearthUI
import SwiftUI
import Testing

/// The chat's menu offers what the chat list's does, the canvas names its own buttons, and a Mac's text follows the
/// system's size while staying a little larger.
@MainActor
struct MenusAndTextSizeTests {
    private static let project = Project(name: "Garden")
    private static let filed = Conversation(
        title: "Tomatoes",
        messages: [Message(role: .user, text: "When to plant tomatoes?")],
        projectID: project.id
    )

    // MARK: The chat's menu

    @Test func `removing the open chat from its project files it in none`() async throws {
        let store = PresenterFixtures.conversationStore([Self.filed])
        try await store.load()
        let subject = PresenterFixtures.chatPresenter(conversationStore: store)
        await subject.selectConversationAction(Self.filed.id)

        await subject.removeFromProjectAction()

        #expect(store.conversation(for: Self.filed.id)?.projectID == nil)
        #expect(subject.viewModel.conversation.projectID == nil)
        #expect(subject.viewModel.error == nil)
    }

    // MARK: The canvas

    @Test(arguments: [CanvasKind.html, .svg, .markdown, .code(language: "swift"), .code(language: nil)])
    func `the canvas names its copy and share for what they hold`(kind: CanvasKind) {
        #expect(kind.copyLabel != Strings.copy)
        #expect(kind.shareLabel != Strings.share)
        #expect(kind.copyLabel != kind.shareLabel)
    }

    @Test func `a page and its code are copied under different names`() {
        #expect(CanvasKind.html.copyLabel != CanvasKind.code(language: "html").copyLabel)
    }

    // MARK: Text on a Mac

    @Test func `a Mac with no text size of its own sets text a quarter larger`() {
        let size = Font.macPointSize(base: 17, preferred: 17, standard: 17)

        #expect(abs(size - 21.25) < 0.001)
    }

    @Test(arguments: [(preferred: 20.0, standard: 17.0), (preferred: 14.0, standard: 17.0), (preferred: 13.0, standard: 13.0)])
    func `a Mac follows the system's text size in proportion`(preferred: Double, standard: Double) {
        let size = Font.macPointSize(base: 17, preferred: preferred, standard: standard)

        #expect(abs(size - 17 * Font.macTextScale * preferred / standard) < 0.001)
    }

    @Test func `a missing standard size leaves the Mac's size as it was`() {
        #expect(abs(Font.macPointSize(base: 13, preferred: 15, standard: 0) - 13 * Font.macTextScale) < 0.001)
    }
}
