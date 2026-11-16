import Foundation
@testable import HearthDomain
import Testing

/// How the camera of a voice conversation goes on and off, in whatever order things happen.
struct VoiceCameraTests {
    /// A camera that has been asked for and is waiting on the user's answer, with the number of the attempt.
    private func makeAskingSubject() -> (VoiceCamera, Int) {
        var subject = VoiceCamera()
        let attempt = subject.turnOn(modelCanSee: true) ?? 0
        return (subject, attempt)
    }

    /// A camera that has been allowed and is starting.
    private func makeStartingSubject() -> (VoiceCamera, Int) {
        var (subject, attempt) = makeAskingSubject()
        _ = subject.allow(attempt)
        return (subject, attempt)
    }

    /// A camera that is on.
    private func makeRunningSubject() -> VoiceCamera {
        var (subject, attempt) = makeStartingSubject()
        _ = subject.begin(attempt)
        return subject
    }

    @Test func `the camera starts off, facing away, with nothing to say`() {
        let subject = VoiceCamera()

        #expect(subject.phase == .off)
        #expect(subject.position == .back)
        #expect(subject.notice == nil)
        #expect(!subject.attachesFrames)
        #expect(!subject.isPreviewShown)
    }

    @Test func `turning it on asks, then starts, then attaches pictures`() throws {
        var subject = VoiceCamera()

        let asked = subject.turnOn(modelCanSee: true)
        let attempt = try #require(asked)
        #expect(subject.phase == .asking)
        #expect(!subject.isPreviewShown)

        let isAllowed = subject.allow(attempt)
        #expect(isAllowed)
        #expect(subject.phase == .starting)
        #expect(subject.isPreviewShown)
        #expect(!subject.attachesFrames)

        let didBegin = subject.begin(attempt)
        #expect(didBegin)
        #expect(subject.phase == .on)
        #expect(subject.attachesFrames)
    }

    @Test func `it cannot be turned on for a model that cannot see`() {
        var subject = VoiceCamera()

        let attempt = subject.turnOn(modelCanSee: false)

        #expect(attempt == nil)
        #expect(subject.phase == .off)
    }

    @Test func `a second tap while it is on its way or on starts nothing more`() {
        var (asking, _) = makeAskingSubject()
        var running = makeRunningSubject()

        let again = asking.turnOn(modelCanSee: true)
        let over = running.turnOn(modelCanSee: true)

        #expect(again == nil)
        #expect(over == nil)
        #expect(asking.phase == .asking)
        #expect(running.phase == .on)
    }

    @Test func `a refusal leaves it off and says why, and the next try clears that`() {
        var (subject, attempt) = makeAskingSubject()

        subject.fail(attempt, notice: .permissionRefused)
        #expect(subject.phase == .off)
        #expect(subject.notice == .permissionRefused)

        let next = subject.turnOn(modelCanSee: true)
        #expect(next != nil)
        #expect(subject.notice == nil)
    }

    @Test func `a camera that will not start leaves it off and says so`() {
        var (subject, attempt) = makeStartingSubject()

        subject.fail(attempt, notice: .unavailable)

        #expect(subject.phase == .off)
        #expect(subject.notice == .unavailable)
    }

    @Test func `turning it off while it is still being asked for or started stops it from ever running`() {
        var (asking, asked) = makeAskingSubject()
        let hadAsking = asking.turnOff()
        let isAllowed = asking.allow(asked)
        #expect(hadAsking)
        #expect(!isAllowed)
        #expect(asking.phase == .off)

        var (starting, started) = makeStartingSubject()
        let hadStarting = starting.turnOff()
        let didBegin = starting.begin(started)
        #expect(hadStarting)
        #expect(!didBegin)
        #expect(starting.phase == .off)
    }

    @Test func `an attempt overtaken by a later one can neither start the camera nor mark it failed`() throws {
        var (subject, first) = makeStartingSubject()
        _ = subject.turnOff()
        let asked = subject.turnOn(modelCanSee: true)
        let second = try #require(asked)
        _ = subject.allow(second)

        let didBeginFirst = subject.begin(first)
        subject.fail(first, notice: .unavailable)
        #expect(!didBeginFirst)
        #expect(subject.phase == .starting)
        #expect(subject.notice == nil)

        let didBeginSecond = subject.begin(second)
        #expect(didBeginSecond)
        #expect(subject.phase == .on)
    }

    @Test func `turning off a camera that is off is harmless`() {
        var subject = VoiceCamera()

        let hadAnything = subject.turnOff()

        #expect(!hadAnything)
        #expect(subject == VoiceCamera())
    }

    @Test(arguments: [false, true])
    func `leaving the foreground turns a running camera off`(isOffScreen: Bool) {
        var subject = makeRunningSubject()

        let shouldStop = subject.leaveForeground(isOffScreen: isOffScreen)

        #expect(shouldStop)
        #expect(subject.phase == .off)
    }

    @Test func `the system's own question does not cancel the attempt that asked it, but leaving the screen does`() {
        var (covered, attempt) = makeAskingSubject()
        let shouldStopCovered = covered.leaveForeground(isOffScreen: false)
        let isAllowed = covered.allow(attempt)
        #expect(!shouldStopCovered)
        #expect(isAllowed)
        #expect(covered.phase == .starting)

        var (gone, abandoned) = makeAskingSubject()
        let shouldStopGone = gone.leaveForeground(isOffScreen: true)
        let isAllowedAfterwards = gone.allow(abandoned)
        #expect(shouldStopGone)
        #expect(!isAllowedAfterwards)
        #expect(gone.phase == .off)
    }

    @Test func `it faces the other way only while it is on`() {
        var running = makeRunningSubject()
        running.face(.front)
        #expect(running.position == .front)

        var off = VoiceCamera()
        off.face(.front)
        #expect(off.position == .back)
    }

    @Test func `the button is hidden without a camera, disabled for a model that cannot see, and otherwise ready`() {
        let none = CameraAvailability(hasCamera: false, canFlip: false)
        let one = CameraAvailability(hasCamera: true, canFlip: false)

        #expect(VoiceCamera.control(availability: none, modelCanSee: true) == .hidden)
        #expect(VoiceCamera.control(availability: none, modelCanSee: false) == .hidden)
        #expect(VoiceCamera.control(availability: one, modelCanSee: false) == .disabled)
        #expect(VoiceCamera.control(availability: one, modelCanSee: true) == .enabled)
    }
}
