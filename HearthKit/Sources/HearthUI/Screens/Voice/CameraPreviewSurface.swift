import QuartzCore
import SwiftUI
import UIKit

/// Shows the camera's live picture, by holding the layer it is drawn in and keeping that layer the view's own size.
struct CameraPreviewSurface: UIViewRepresentable {
    let layer: CALayer

    func makeUIView(context: Context) -> CameraPreviewHostView {
        let view = CameraPreviewHostView()
        view.hostedLayer = layer
        return view
    }

    func updateUIView(_ view: CameraPreviewHostView, context: Context) {
        view.hostedLayer = layer
    }
}

/// A plain view with one layer laid over the whole of it.
final class CameraPreviewHostView: UIView {
    var hostedLayer: CALayer? {
        didSet {
            guard hostedLayer !== oldValue else {
                return
            }
            oldValue?.removeFromSuperlayer()
            if let hostedLayer {
                layer.addSublayer(hostedLayer)
            }
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The layer follows the view at once; left to itself it would slide to its new size a moment behind.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hostedLayer?.frame = bounds
        CATransaction.commit()
    }
}
