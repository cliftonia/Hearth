import Foundation
@testable import HearthUI
import Testing

/// How a press on the resting composer becomes a recording and then a draft, in whatever order things happen.
struct HoldToTalkTests {
    /// A press on an empty composer with no dictation under way, which is one that may start.
    private func makePressedSubject() -> HoldToTalk {
        var subject = HoldToTalk()
        _ = subject.press(isDraftEmpty: true, isDictating: false)
        return subject
    }

    /// A press that has got as far as recording.
    private func makeRecordingSubject() -> HoldToTalk {
        var subject = makePressedSubject()
        _ = subject.begin()
        return subject
    }

    @Test func `a press on the empty composer starts, records, and leaves its words for the draft`() {
        var subject = HoldToTalk()

        let didStart = subject.press(isDraftEmpty: true, isDictating: false)
        #expect(didStart)
        #expect(subject.phase == .starting)
        #expect(subject.isActive)

        let didBegin = subject.begin()
        #expect(didBegin)
        #expect(subject.phase == .recording)

        subject.hear("What is")
        subject.hear("What is for dinner ")
        let hadRecording = subject.release()
        let words = subject.finish()
        #expect(hadRecording)
        #expect(words == "What is for dinner")
        #expect(subject == HoldToTalk())
    }

    @Test(arguments: ["", "  \n"])
    func `a recording in which nothing was heard returns the composer to rest`(heard: String) {
        var subject = makeRecordingSubject()

        subject.hear(heard)
        subject.release()
        let words = subject.finish()

        #expect(words == nil)
        #expect(!subject.isActive)
    }

    @Test(arguments: [(false, false), (true, true), (false, true)])
    func `holding does nothing when something is written or the microphone button is dictating`(isDraftEmpty: Bool, isDictating: Bool) {
        var subject = HoldToTalk()

        let didStart = subject.press(isDraftEmpty: isDraftEmpty, isDictating: isDictating)

        #expect(!didStart)
        #expect(subject.phase == .idle)
    }

    @Test func `a second press while one is under way is ignored`() {
        var starting = makePressedSubject()
        var recording = makeRecordingSubject()

        let didStartAgain = starting.press(isDraftEmpty: true, isDictating: false)
        let didStartOver = recording.press(isDraftEmpty: true, isDictating: false)

        #expect(!didStartAgain)
        #expect(!didStartOver)
        #expect(starting.phase == .starting)
        #expect(recording.phase == .recording)
    }

    @Test func `a release before the recogniser has started stops it from ever recording`() {
        var subject = makePressedSubject()
        #expect(subject.isStillWanted)

        // Nothing is recording yet, so there is nothing to stop; the press is only marked as unwanted.
        let hadRecording = subject.release()
        #expect(!hadRecording)
        #expect(!subject.isStillWanted)

        let didBegin = subject.begin()
        #expect(!didBegin)
        #expect(subject.phase == .starting)

        let words = subject.finish()
        #expect(words == nil)
        #expect(subject.phase == .idle)
    }

    @Test func `a press that could not start listening goes back to rest, ready for the next`() {
        var subject = makePressedSubject()

        let words = subject.finish()
        #expect(words == nil)
        #expect(subject == HoldToTalk())

        let didStart = subject.press(isDraftEmpty: true, isDictating: false)
        #expect(didStart)
    }

    @Test func `a release with nothing held is harmless`() {
        var subject = HoldToTalk()

        let hadRecording = subject.release()

        #expect(!hadRecording)
        #expect(subject == HoldToTalk())
    }

    @Test func `a second release, as when the finger lifts after sliding off, changes nothing`() {
        var subject = makeRecordingSubject()
        subject.hear("kept")

        subject.release()
        let once = subject
        subject.release()

        #expect(subject == once)
        #expect(subject.phase == .recording)
        #expect(subject.isStopRequested)
    }

    @Test func `words that arrive when nothing is recording are dropped`() {
        var idle = HoldToTalk()
        var starting = makePressedSubject()

        idle.hear("stray")
        starting.hear("early")

        #expect(idle.transcript.isEmpty)
        #expect(starting.transcript.isEmpty)
    }

    @Test func `a new press starts clean after the last one was let go`() {
        var subject = makeRecordingSubject()
        subject.hear("first")
        subject.release()
        subject.finish()

        let didStart = subject.press(isDraftEmpty: true, isDictating: false)

        #expect(didStart)
        #expect(!subject.isStopRequested)
        #expect(subject.transcript.isEmpty)
    }
}
