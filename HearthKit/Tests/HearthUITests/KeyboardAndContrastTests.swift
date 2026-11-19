import SwiftUI
@testable import HearthUI
import Testing
import UIKit

/// Return from a hardware keyboard in the composer, and the colours drawn while Increase Contrast is on.
@MainActor
struct KeyboardAndContrastTests {
    @Test(arguments: [
        (modifiers: EventModifiers(), canSend: true, isStreaming: false, outcome: ComposerReturnKey.OutcomeKind.send),
        (modifiers: EventModifiers.shift, canSend: true, isStreaming: false, outcome: .newLine),
        (modifiers: EventModifiers.shift, canSend: false, isStreaming: false, outcome: .newLine),
        (modifiers: EventModifiers(), canSend: false, isStreaming: false, outcome: .nothing),
        (modifiers: EventModifiers(), canSend: true, isStreaming: true, outcome: .nothing)
    ])
    func `Return sends and Shift-Return starts a new line`(
        _ example: (modifiers: EventModifiers, canSend: Bool, isStreaming: Bool, outcome: ComposerReturnKey.OutcomeKind)
    ) {
        let outcome = ComposerReturnKey.outcome(modifiers: example.modifiers, canSend: example.canSend, isStreaming: example.isStreaming)

        #expect(outcome == example.outcome)
    }

    @Test(arguments: [
        (style: UIUserInterfaceStyle.light, contrast: UIAccessibilityContrast.normal, hex: UInt32(0x111111)),
        (style: .dark, contrast: .normal, hex: 0x222222),
        (style: .light, contrast: .high, hex: 0x333333),
        (style: .dark, contrast: .high, hex: 0x444444)
    ])
    func `a colour with stronger variants draws them while Increase Contrast is on`(
        _ example: (style: UIUserInterfaceStyle, contrast: UIAccessibilityContrast, hex: UInt32)
    ) {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = example.style
            traits.accessibilityContrast = example.contrast
        }

        let hex = Color.hex(for: traits, lightHex: 0x111111, darkHex: 0x222222, highContrast: (light: 0x333333, dark: 0x444444))

        #expect(hex == example.hex)
    }

    @Test func `a colour without stronger variants keeps its own while Increase Contrast is on`() {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = .dark
            traits.accessibilityContrast = .high
        }

        #expect(Color.hex(for: traits, lightHex: 0x111111, darkHex: 0x222222, highContrast: nil) == 0x222222)
    }
}
