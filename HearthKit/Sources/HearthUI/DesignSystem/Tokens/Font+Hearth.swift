import SwiftUI
import UIKit

extension Font {
    /// How much larger text is set on a Mac, whose window is read from further away than a phone, and which draws an
    /// iPad's layout at about three quarters of its size.
    static let macTextScale: CGFloat = 1.25

    /// A system text style. On an iPhone or iPad it follows the reader's text size; on a Mac it is set a little larger,
    /// and follows the text size chosen for the app in the Mac's settings where the system passes it on.
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
        macPointSize(base: baseSize(of: style), preferred: preferredSize(of: style), standard: standardSize(of: style))
        #else
        preferredSize(of: style)
        #endif
    }

    /// A text style's size on a Mac: its size at the default text size, made larger by `macTextScale`, and grown or
    /// shrunk by as much as the system's preferred size for the style differs from its standard one. A Mac that passes
    /// on no text size reports the two as equal, which leaves the size as it was.
    static func macPointSize(base: CGFloat, preferred: CGFloat, standard: CGFloat) -> CGFloat {
        let ratio = standard > 0 ? preferred / standard : 1
        return base * macTextScale * ratio
    }

    /// The size the system prefers for a text style at the reader's text size.
    private static func preferredSize(of style: TextStyle) -> CGFloat {
        UIFont.preferredFont(forTextStyle: style.uiTextStyle).pointSize
    }

    /// The size the system gives a text style at the default text size, to measure the reader's choice against.
    private static func standardSize(of style: TextStyle) -> CGFloat {
        let standard = UITraitCollection(preferredContentSizeCategory: .large)
        return UIFont.preferredFont(forTextStyle: style.uiTextStyle, compatibleWith: standard).pointSize
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
