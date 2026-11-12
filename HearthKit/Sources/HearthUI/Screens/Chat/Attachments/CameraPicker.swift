import SwiftUI
import UIKit

/// The system camera, handing back one photo already shrunk for a vision model.
struct CameraPicker: UIViewControllerRepresentable {
    /// False where there is no camera to use, as in the simulator; the menu then leaves the camera out.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// Receives the photo as JPEG data. Nothing is called if the camera is dismissed without one.
    let onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onFinish: { dismiss() })
    }

    /// Receives the camera's result on the picker's behalf, then closes it.
    final class Coordinator: NSObject {
        private let onCapture: (Data) -> Void
        private let onFinish: () -> Void

        init(onCapture: @escaping (Data) -> Void, onFinish: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onFinish = onFinish
        }
    }
}

extension CameraPicker.Coordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9), let jpeg = PhotoLoader.downscaledJPEG(from: data) {
            onCapture(jpeg)
        }
        onFinish()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        onFinish()
    }
}
