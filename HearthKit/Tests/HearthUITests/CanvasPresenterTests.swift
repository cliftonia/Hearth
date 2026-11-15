import CoreGraphics
import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// What the canvas shows of a chat: the piece opened, its versions, and how it follows a reply being written.
@MainActor
struct CanvasPresenterTests {
    /// A chat the canvas reads, which a test adds to as a model would.
    @MainActor
    final class Fixture {
        var messages: [Message] = []
        var streamingMessageID: Message.ID?
        private(set) var copied: [String] = []
        private(set) var closeCount = 0

        func makeTestSubject() -> CanvasPresenter {
            let subject = CanvasPresenter(
                messages: { self.messages },
                streamingMessageID: { self.streamingMessageID },
                copy: { self.copied.append($0) }
            )
            subject.delegate = self
            return subject
        }

        /// Adds a reply holding one page with the given body, and returns where the page is.
        @discardableResult
        func addPage(_ body: String, title: String = "Stopwatch", isClosed: Bool = true) -> CanvasReference {
            let text = "Here:\n```html\n<title>\(title)</title>\n\(body)" + (isClosed ? "\n```" : "")
            let message = Message(role: .assistant, text: text)
            messages.append(Message(role: .user, text: "Please"))
            messages.append(message)
            return CanvasReference(messageID: message.id, index: 0)
        }

        func noteClose() {
            closeCount += 1
        }
    }

    @Test func `opening a piece shows it with its title, its length and its preview`() throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()

        subject.open(fixture.addPage("<p>One</p>"))
        let content = try #require(subject.content)

        #expect(content.title == "Stopwatch")
        #expect(content.kind == .html)
        #expect(content.text == "<title>Stopwatch</title>\n<p>One</p>")
        #expect(content.mode == .preview)
        #expect(!content.isWriting)
        #expect((content.versionNumber, content.versionCount) == (1, 1))
        #expect(!content.hasEarlier && !content.hasLater)
    }

    @Test func `code has no preview whatever is chosen`() throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        let code = (1...20).map { "line \($0)" }.joined(separator: "\n")
        let message = Message(role: .assistant, text: "```python\n\(code)\n```")
        fixture.messages = [message]

        subject.open(CanvasReference(messageID: message.id, index: 0))
        subject.viewModel.mode = .preview

        #expect(try #require(subject.content).mode == .code)
    }

    @Test func `a later version is followed as it is written and shown as code until it is finished`() throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.open(fixture.addPage("<p>One</p>"))

        let second = fixture.addPage("<p>Tw", isClosed: false)
        fixture.streamingMessageID = second.messageID
        let writing = try #require(subject.content)

        #expect((writing.versionNumber, writing.versionCount) == (2, 2))
        #expect(writing.isWriting)
        #expect(writing.mode == .code)

        fixture.messages[3] = fixture.messages[3].updating(text: fixture.messages[3].text + "o</p>\n```")
        fixture.streamingMessageID = nil
        let finished = try #require(subject.content)

        #expect(finished.text.hasSuffix("<p>Two</p>"))
        #expect(!finished.isWriting)
        #expect(finished.mode == .preview)
    }

    @Test func `a piece left open by a reply that has ended is not being written`() throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()

        subject.open(fixture.addPage("<p>Cut off", isClosed: false))

        #expect(try #require(subject.content).isWriting == false)
        #expect(try #require(subject.content).mode == .preview)
    }

    @Test func `stepping back stays on the earlier version while newer ones arrive`() throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.open(fixture.addPage("<p>One</p>"))
        fixture.addPage("<p>Two</p>")

        subject.stepAction(by: -1)
        fixture.addPage("<p>Three</p>")
        let earlier = try #require(subject.content)

        #expect((earlier.versionNumber, earlier.versionCount) == (1, 3))
        #expect(earlier.text.hasSuffix("<p>One</p>"))
        #expect(earlier.hasLater && !earlier.hasEarlier)

        subject.stepAction(by: -1)
        #expect(try #require(subject.content).versionNumber == 1)

        subject.stepAction(by: 1)
        subject.stepAction(by: 1)
        fixture.addPage("<p>Four</p>")

        #expect(try #require(subject.content).versionNumber == 4)
    }

    @Test func `opening an older version shows that one`() throws {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        let first = fixture.addPage("<p>One</p>")
        fixture.addPage("<p>Two</p>")

        subject.open(first)

        #expect(try #require(subject.content).versionNumber == 1)
        #expect(try #require(subject.content).versionCount == 2)
    }

    @Test func `copy takes the text of the version shown`() {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.open(fixture.addPage("<p>One</p>"))
        fixture.addPage("<p>Two</p>")

        subject.copyAction()
        subject.stepAction(by: -1)
        subject.copyAction()

        #expect(fixture.copied == ["<title>Stopwatch</title>\n<p>Two</p>", "<title>Stopwatch</title>\n<p>One</p>"])
        #expect(subject.viewModel.copyCount == 2)
    }

    @Test func `the canvas closes when its piece is no longer in the chat and not before`() {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.open(fixture.addPage("<p>One</p>"))

        fixture.addPage("<p>Two</p>")
        subject.chatChangedAction()
        #expect(fixture.closeCount == 0)

        fixture.messages = []
        subject.chatChangedAction()
        subject.chatChangedAction()

        #expect(fixture.closeCount == 1)
        #expect(subject.content == nil)
    }

    @Test func `close asks the coordinator to put the canvas away`() {
        let fixture = Fixture()
        let subject = fixture.makeTestSubject()
        subject.open(fixture.addPage("<p>One</p>"))

        subject.closeAction()

        #expect(fixture.closeCount == 1)
    }
}

extension CanvasPresenterTests.Fixture: CanvasPresenterDelegate {
    func canvasPresenterDidClose(_ presenter: CanvasPresenter) {
        noteClose()
    }
}

/// How a wide screen is shared between the chat list, the chat and the canvas.
struct CanvasLayoutTests {
    private func columns(_ width: CGFloat, isPinned: Bool = true, isOpen: Bool = true) -> CanvasLayout.Columns {
        CanvasLayout.columns(totalWidth: width, isSidebarPinned: isPinned, isCanvasOpen: isOpen, sidebarWidth: 320)
    }

    @Test(arguments: [(1_133.0, 320.0, 406.0), (1_366.0, 320.0, 523.0), (1_040.0, 320.0, 360.0), (1_039.0, 0.0, 519.0), (744.0, 0.0, 372.0)])
    func `the chat list stays only where the chat and the canvas both have room beside it`(width: Double, sidebar: Double, canvas: Double) {
        #expect(columns(width) == CanvasLayout.Columns(sidebarWidth: sidebar, canvasWidth: canvas))
    }

    @Test func `with the canvas closed the chat list is as the user left it`() {
        #expect(columns(744, isOpen: false) == CanvasLayout.Columns(sidebarWidth: 320, canvasWidth: 0))
        #expect(columns(744, isPinned: false, isOpen: false) == CanvasLayout.Columns(sidebarWidth: 0, canvasWidth: 0))
    }

    @Test func `a chat list the user put away stays away and the canvas takes half of everything`() {
        #expect(columns(1_366, isPinned: false) == CanvasLayout.Columns(sidebarWidth: 0, canvasWidth: 683))
    }

    @Test func `every line is numbered, each number padded to the width of the last`() {
        let gutter = CanvasCodeSection.gutter(for: (1...10).map { "line \($0)" }.joined(separator: "\n"))

        #expect(gutter.digitCount == 2)
        #expect(gutter.text.hasPrefix(" 1\n 2\n"))
        #expect(gutter.text.hasSuffix(" 9\n10"))
    }

    @Test func `a line with a character taller than the rest carries it before its number, to stay as tall`() {
        let gutter = CanvasCodeSection.gutter(for: "let a = \"café — done\"\nprint(\"▶️ go\")\n// 日本")

        #expect(gutter.text == "1\n▶️2\n日本3")
    }

    @Test func `no code at all is one empty line`() {
        #expect(CanvasCodeSection.gutter(for: "").text == "1")
    }
}

/// Where the canvas shows: beside the chat on a wide screen, in a sheet on a narrow one.
@MainActor
struct CanvasRouterTests {
    private func makeTestSubject(isWide: Bool) throws -> AppRouter {
        let router = AppRouter(defaults: try #require(UserDefaults(suiteName: "CanvasRouterTests-\(UUID().uuidString)")))
        router.isWide = isWide
        return router
    }

    @Test(arguments: [(false, true), (true, false)])
    func `an open canvas is a sheet only on a narrow screen`(isWide: Bool, isSheet: Bool) throws {
        let router = try makeTestSubject(isWide: isWide)

        router.isCanvasOpen = true

        #expect(router.isCanvasSheetPresented == isSheet)
    }

    @Test func `a screen that grows wide or narrow moves the canvas and keeps it open`() throws {
        let router = try makeTestSubject(isWide: false)
        router.isCanvasOpen = true

        router.isWide = true
        #expect(router.isCanvasOpen && !router.isCanvasSheetPresented)

        router.isWide = false
        #expect(router.isCanvasOpen && router.isCanvasSheetPresented)
    }

    @Test func `closing the canvas takes its sheet away`() throws {
        let router = try makeTestSubject(isWide: false)
        router.isCanvasOpen = true

        router.isCanvasOpen = false

        #expect(!router.isCanvasSheetPresented)
    }
}
