import HearthDomain
import SwiftUI
import UIKit

extension AppearanceKind {
    /// The colour scheme to force, or `nil` to follow the phone.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var title: String {
        switch self {
        case .system:
            Strings.themeSystem
        case .light:
            Strings.themeLight
        case .dark:
            Strings.themeDark
        }
    }
}

extension Color {
    /// A colour that follows the light or dark appearance.
    init(lightHex: UInt32, darkHex: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum HearthColor {
    static let paper = Color(lightHex: 0xF3F5F1, darkHex: 0x121715)
    static let card = Color(lightHex: 0xFFFFFF, darkHex: 0x1B2220)
    static let ink = Color(lightHex: 0x18211E, darkHex: 0xE9EEEA)
    static let mute = Color(lightHex: 0x6C7772, darkHex: 0x8B9691)
    static let line = Color(lightHex: 0xDDE2DC, darkHex: 0x2A3330)
    static let pine = Color(lightHex: 0x2C6B5A, darkHex: 0x6FC2A8)
    static let pineSoft = Color(lightHex: 0xDCEAE4, darkHex: 0x1F3A32)
    static let bubble = Color(lightHex: 0xE6EBE5, darkHex: 0x232C29)
    static let onPine = Color(lightHex: 0xFFFFFF, darkHex: 0x0E1211)
    static let danger = Color(lightHex: 0xC8553D, darkHex: 0xE0705A)
    static let online = Color(lightHex: 0x3FA66B, darkHex: 0x57C283)
}

enum HearthFont {
    static let brand = Font.system(.title2, design: .serif).weight(.bold)
    static let display = Font.system(.title, design: .serif).weight(.semibold)
    static let spoken = Font.system(.title3, design: .serif)
    static let code = Font.system(.footnote, design: .monospaced)
    static let math = Font.system(.title3, design: .serif)

    static func heading(level: Int) -> Font {
        switch level {
        case 1:
            Font.system(.title2, design: .serif).weight(.semibold)
        case 2:
            Font.system(.title3, design: .serif).weight(.semibold)
        default:
            Font.system(.headline, design: .serif)
        }
    }
}

/// The app's mark: a ring of embers on pine.
struct HearthMark: View {
    let sideLength: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: sideLength * 0.3, style: .continuous)
            .fill(HearthColor.pine)
            .frame(width: sideLength, height: sideLength)
            .overlay {
                Circle()
                    .strokeBorder(HearthColor.onPine, lineWidth: sideLength * 0.09)
                    .padding(sideLength * 0.28)
            }
            .accessibilityHidden(true)
    }
}

/// A round, borderless button holding one symbol.
struct IconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(HearthColor.ink)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
