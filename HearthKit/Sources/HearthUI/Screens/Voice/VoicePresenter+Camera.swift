import Foundation
import HearthDomain
import QuartzCore

// The camera of a voice conversation: on and off, which way it faces, and the one picture taken with each spoken turn.
extension VoicePresenter {
    /// The layer the live picture is drawn in, for the view to hold.
    var cameraPreviewLayer: CALayer {
        dependencies.camera.previewLayer()
    }

    /// Turns the camera on, asking the user first if they have never been asked, or turns it off.
    func cameraAction() async {
        guard viewModel.camera.phase == .off else {
            await stopCamera()
            return
        }
        guard let attempt = viewModel.camera.turnOn(modelCanSee: dependencies.modelCanSee()) else {
            return
        }
        let camera = dependencies.camera
        guard await camera.requestAuthorization() else {
            viewModel.camera.fail(attempt, notice: .permissionRefused)
            return
        }
        // While the user was answering, the conversation may have closed or the button been tapped again.
        guard viewModel.camera.allow(attempt) else {
            return
        }
        do {
            try await camera.start(viewModel.camera.position)
        } catch {
            logger.error("The camera could not start: \(error.localizedDescription, privacy: .public)")
            // Anything half started is let go of, unless a later attempt now has the camera.
            if viewModel.camera.phase == .starting {
                await camera.stop()
            }
            viewModel.camera.fail(attempt, notice: .unavailable)
            return
        }
        if !viewModel.camera.begin(attempt), viewModel.camera.phase == .off {
            // Turned off while it was starting: it must not be left running with nothing on screen to show for it.
            await camera.stop()
        }
    }

    /// Changes to the camera on the other side.
    func flipCameraAction() async {
        guard viewModel.camera.phase == .on, viewModel.cameraAvailability.canFlip else {
            return
        }
        do {
            viewModel.camera.face(try await dependencies.camera.flip())
        } catch {
            logger.error("The camera could not be changed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The app is no longer in front of the user, so the camera goes off. It stays off when the app comes back.
    ///
    /// - Parameter isOffScreen: Whether the app has left the screen, and has not merely been covered for a moment.
    func leftForegroundAction(isOffScreen: Bool) async {
        guard viewModel.camera.leaveForeground(isOffScreen: isOffScreen) else {
            return
        }
        await dependencies.camera.stop()
    }

    /// The screen has gone, however it went. Turns the camera off if it is somehow still on.
    func closedAction() async {
        await stopCamera()
    }

    /// Puts the camera back to off, as every voice conversation begins, and reads what this device and model allow.
    func resetCamera() async {
        // Nothing should be running, but a camera left on would be worse than a wasted call.
        await dependencies.camera.stop()
        viewModel.camera = VoiceCamera()
        viewModel.cameraAvailability = dependencies.camera.availability()
        viewModel.modelCanSee = dependencies.modelCanSee()
    }

    /// Turns the camera off. The account is settled before the wait, so the screen shows it off at once.
    func stopCamera() async {
        guard viewModel.camera.turnOff() else {
            return
        }
        await dependencies.camera.stop()
    }

    /// The picture that goes with a spoken turn: what the camera sees now, shrunk as an attached photo is.
    /// `nil` while the camera is off, and when no picture can be had; the turn is then sent without one.
    func captureFrame() async -> Data? {
        guard viewModel.camera.attachesFrames, dependencies.modelCanSee() else {
            return nil
        }
        do {
            let frame = try await dependencies.camera.captureFrame()
            // A picture that arrives after the camera was turned off is not sent.
            guard viewModel.camera.attachesFrames else {
                return nil
            }
            return dependencies.prepareFrame(frame)
        } catch {
            logger.error("No picture could be taken for the turn: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
