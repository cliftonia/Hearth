import SwiftUI
import UIKit

extension Font {
    /// How much larger text is set on a Mac, whose window is read from further away than a phone.
    ///
    /// A Mac ignores the Dynamic Type setting and draws every text style at one fixed size, so the size is set here.
    static let macTextScale: CGFloat = 1.1

    /// A system text style. On an iPhone or iPad it follows the reader's text size; on a Mac it is set a little larger.
    static func hearth(_ style: TextStyle, design: Design = .default, weight: Weight? = nil) -> Font {
        #if targetEnvironment(macCatalyst)
        .system(size: pointSize(of: style), weight: weight ?? (style == .headline ? .semibold : .regular), design: design)
        #else
        .system(style, design: design, weight: weight)
        #endif
    }

    /// The size, in points, a text style is drawn at here.
    static func pointSize(of style: TextStyle) -> CGFloat {
        #if targetEnvironment(macCatalyst)
        baseSize(of: style) * macTextScale
        #else
        UIFont.preferredFont(forTextStyle: style.uiTextStyle).pointSize
        #endif
    }

    /// Each text style's size at the default text size.
    private static let baseSizes: [TextStyle: CGFloat] = [
        .largeTitle: 34, .title: 28, .title2: 22, .title3: 20, .headline: 17, .body: 17,
        .callout: 16, .subheadline: 15, .footnote: 13, .caption: 12, .caption2: 11
    ]

    private static func baseSize(of style: TextStyle) -> CGFloat {
        baseSizes[style] ?? 17
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}
