import SwiftUI

extension View {
    /// Lets a control's symbol follow Dynamic Type only as far as the largest of the standard sizes, so that it keeps
    /// inside the fixed frame drawn around it at the accessibility sizes.
    ///
    /// Put it on the symbol itself, not on the control, so that any words beside it still grow in full. A control
    /// held back this way should also offer the large content viewer, through `largeContentLabel(_:systemImage:)`.
    func iconGlyphSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// Shows the control's name and symbol, enlarged, when it is touched and held at an accessibility text size, as
    /// the Human Interface Guidelines ask of a control that does not grow with the text.
    func largeContentLabel(_ label: String, systemImage: String) -> some View {
        accessibilityShowsLargeContentViewer {
            Label(label, systemImage: systemImage)
        }
    }
}
