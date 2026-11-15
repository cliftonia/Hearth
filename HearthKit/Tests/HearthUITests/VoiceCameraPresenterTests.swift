import Foundation
import HearthDomain
@testable import HearthUI
import Testing

/// How a voice conversation works its camera: when it runs, when it stops, and what goes with a spoken turn.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct VoiceCameraPresenterTests {
    typealias Turn = VoiceFixture.Turn

    // MARK: On and off

    @Test func `the camera is off when the conversation opens, and asks nothing of the user until it is turned on`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()

        await subject.startAction()

        #expect(subject.viewModel.camera.phase == .off)
        #expect(subject.viewModel.cameraControl == .enabled)
        #expect(fixture.camera.requestCount == 0)
        #expect(!fixture.camera.isRunning)
        await subject.endAction()
    }

    @Test func `turning the camera on asks for leave and starts it, and turning it off stops it`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()

        await subject.cameraAction()
        #expect(fixture.camera.requestCount == 1)
        #expect(fixture.camera.isRunning)
        #expect(subject.viewModel.camera.phase == .on)
        #expect(subject.viewModel.camera.isPreviewShown)

        await subject.cameraAction()
        #expect(!fixture.camera.isRunning)
        #expect(subject.viewModel.camera.phase == .off)
        await subject.endAction()
    }

    @Test func `the camera is off again each time the conversation opens`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        await subject.cameraAction()
        await subject.endAction()

        await subject.startAction()

        #expect(subject.viewModel.camera == VoiceCamera())
        #expect(!fixture.camera.isRunning)
        await subject.endAction()
    }

    @Test func `a refusal leaves the camera off with a notice, and the conversation carries on without it`() async {
        let fixture = VoiceFixture()
        fixture.camera.allowsWhenAsked = false
        let subject = fixture.makeTestSubject()
        await subject.startAction()

        await subject.cameraAction()

        #expect(subject.viewModel.camera.phase == .off)
        #expect(subject.viewModel.camera.notice == .permissionRefused)
        #expect(fixture.camera.startCount == 0)
        #expect(subject.viewModel.state != .unavailable)

        fixture.dictation.say("Are you still there?")
        let turn = await fixture.nextTurn()
        #expect(turn == Turn(words: "Are you still there?", frameJPEG: nil))
        await subject.endAction()
    }

    @Test func `a camera that will not start is let go of, with a notice`() async {
        let fixture = VoiceFixture()
        fixture.camera.startFails = true
        let subject = fixture.makeTestSubject()
        await subject.startAction()

        await subject.cameraAction()

        #expect(subject.viewModel.camera.phase == .off)
        #expect(subject.viewModel.camera.notice == .unavailable)
        #expect(!fixture.camera.isRunning)
        #expect(subject.viewModel.state != .unavailable)
        await subject.endAction()
    }

    @Test func `the camera stays off for a model that cannot see, and nothing is asked of the user`() async {
        let fixture = VoiceFixture()
        fixture.modelCanSee = false
        let subject = fixture.makeTestSubject()
        await subject.startAction()

        await subject.cameraAction()

        #expect(subject.viewModel.cameraControl == .disabled)
        #expect(subject.viewModel.camera.phase == .off)
        #expect(fixture.camera.requestCount == 0)
        #expect(fixture.camera.startCount == 0)

        fixture.dictation.say("What is this?")
        let turn = await fixture.nextTurn()
        #expect(turn == Turn(words: "What is this?", frameJPEG: nil))
        #expect(fixture.camera.captureCount == 0)
        await subject.endAction()
    }

    @Test func `there is no camera button on a device with no camera`() async {
        let fixture = VoiceFixture()
        fixture.camera.availability = CameraAvailability(hasCamera: false, canFlip: false)
        let subject = fixture.makeTestSubject()

        await subject.startAction()

        #expect(subject.viewModel.cameraControl == .hidden)
        await subject.endAction()
    }

    // MARK: Stopping

    @Test func `ending the conversation stops the camera`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        await subject.cameraAction()

        await subject.endAction()

        #expect(!fixture.camera.isRunning)
        #expect(subject.viewModel.camera.phase == .off)
    }

    @Test func `the screen going away stops the camera, however it went`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        await subject.cameraAction()

        await subject.closedAction()

        #expect(!fixture.camera.isRunning)
        #expect(subject.viewModel.camera.phase == .off)
        await subject.endAction()
    }

    @Test(arguments: [false, true])
    func `leaving the foreground stops the camera, and it stays off`(isOffScreen: Bool) async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        await subject.cameraAction()

        await subject.leftForegroundAction(isOffScreen: isOffScreen)

        #expect(!fixture.camera.isRunning)
        #expect(subject.viewModel.camera.phase == .off)

        fixture.dictation.say("Anything there?")
        let turn = await fixture.nextTurn()
        #expect(turn == Turn(words: "Anything there?", frameJPEG: nil))
        await subject.endAction()
    }

    @Test func `the system's question about the camera does not stop the camera it is asking about`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        // The question covers the app without taking it off the screen.
        fixture.camera.whileAsking = { await subject.leftForegroundAction(isOffScreen: false) }

        await subject.cameraAction()

        #expect(fixture.camera.isRunning)
        #expect(subject.viewModel.camera.phase == .on)
        await subject.endAction()
    }

    @Test func `leaving the screen while being asked means the camera never starts`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        fixture.camera.whileAsking = { await subject.leftForegroundAction(isOffScreen: true) }

        await subject.cameraAction()

        #expect(fixture.camera.startCount == 0)
        #expect(!fixture.camera.isRunning)
        #expect(subject.viewModel.camera.phase == .off)
        await subject.endAction()
    }

    @Test func `a camera turned off while it was starting is not left running`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        fixture.camera.whileStarting = { await subject.closedAction() }

        await subject.cameraAction()

        #expect(fixture.camera.startCount == 1)
        #expect(!fixture.camera.isRunning)
        #expect(subject.viewModel.camera.phase == .off)
        await subject.endAction()
    }

    // MARK: The picture with a turn

    @Test func `a spoken turn carries one prepared picture while the camera is on, and none once it is off`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        await subject.cameraAction()

        fixture.dictation.say("What is this?")
        let seen = await fixture.nextTurn()
        #expect(seen == Turn(words: "What is this?", frameJPEG: fixture.preparedFrame))
        #expect(fixture.camera.captureCount == 1)

        await subject.cameraAction()
        fixture.dictation.say("And now?")
        let unseen = await fixture.nextTurn()
        #expect(unseen == Turn(words: "And now?", frameJPEG: nil))
        #expect(fixture.camera.captureCount == 1)
        await subject.endAction()
    }

    @Test func `nothing is taken from the camera between turns`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()

        await subject.cameraAction()
        await subject.muteAction()
        await subject.muteAction()

        #expect(fixture.camera.captureCount == 0)
        await subject.endAction()
    }

    @Test func `a turn is still sent when the camera hands over no picture`() async {
        let fixture = VoiceFixture()
        fixture.camera.frame = nil
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        await subject.cameraAction()

        fixture.dictation.say("Read that label.")
        let turn = await fixture.nextTurn()

        #expect(turn == Turn(words: "Read that label.", frameJPEG: nil))
        #expect(fixture.camera.captureCount == 1)
        #expect(subject.viewModel.camera.phase == .on)
        await subject.endAction()
    }

    @Test func `a turn is still sent when the picture cannot be prepared`() async {
        let fixture = VoiceFixture()
        fixture.prepareFrame = { _ in nil }
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        await subject.cameraAction()

        fixture.dictation.say("Read that label.")
        let turn = await fixture.nextTurn()

        #expect(turn == Turn(words: "Read that label.", frameJPEG: nil))
        await subject.endAction()
    }

    // MARK: Flipping

    @Test func `flipping changes which way a running camera faces`() async {
        let fixture = VoiceFixture()
        let subject = fixture.makeTestSubject()
        await subject.startAction()
        await subject.cameraAction()

        await subject.flipCameraAction()

        #expect(fixture.camera.position == .front)
        #expect(subject.viewModel.camera.position == .front)
        await subject.endAction()
    }

    @Test func `there is nothing to flip with one camera, or with the camera off`() async {
        let single = VoiceFixture()
        single.camera.availability = CameraAvailability(hasCamera: true, canFlip: false)
        let subject = single.makeTestSubject()
        await subject.startAction()
        await subject.cameraAction()
        await subject.flipCameraAction()
        #expect(single.camera.flipCount == 0)
        await subject.endAction()

        let off = VoiceFixture()
        let idle = off.makeTestSubject()
        await idle.startAction()
        await idle.flipCameraAction()
        #expect(off.camera.flipCount == 0)
        await idle.endAction()
    }
}
