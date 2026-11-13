import SwiftUI
import WidgetKit

/// One shortcut drawn for the home screen, or as a round button for the lock screen.
struct ShortcutWidgetView: View {
    /// The sizes the shortcuts come in. The Mac has no lock screen widgets.
    static var families: [WidgetFamily] {
        #if targetEnvironment(macCatalyst)
        [.systemSmall]
        #else
        [.systemSmall, .accessoryCircular]
        #endif
    }

    private static let markSide: CGFloat = 40
    private static let spacing: CGFloat = 12

    let shortcut: WidgetShortcut

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(shortcut.url)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(shortcut.title)
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var content: some View {
        if family == .systemSmall {
            homeScreen
        } else {
            lockScreen
        }
    }

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            Image(systemName: shortcut.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(WidgetColor.onPine)
                .frame(width: Self.markSide, height: Self.markSide)
                .background(WidgetColor.pine, in: Circle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text(shortcut.title)
                .font(.headline)
                .foregroundStyle(WidgetColor.ink)
            Text(verbatim: "Hearth")
                .font(.caption)
                .foregroundStyle(WidgetColor.mute)
        }
        .containerBackground(WidgetColor.paper, for: .widget)
    }

    private var lockScreen: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: shortcut.systemImage)
                .font(.title3.weight(.semibold))
        }
        .containerBackground(.clear, for: .widget)
    }
}

/// The app's colours, repeated here because a widget cannot share the app's design system module.
/// They match `HearthColor` in HearthUI.
enum WidgetColor {
    static let paper = adaptive(light: 0xF3F5F1, dark: 0x121715)
    static let ink = adaptive(light: 0x18211E, dark: 0xE9EEEA)
    static let mute = adaptive(light: 0x6C7772, dark: 0x8B9691)
    static let pine = adaptive(light: 0x2C6B5A, dark: 0x6FC2A8)
    static let onPine = adaptive(light: 0xFFFFFF, dark: 0x0E1211)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
