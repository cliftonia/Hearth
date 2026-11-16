@testable import HearthUI
import SwiftUI
import Testing

/// The theme is set on the windows, so that following the system again really follows it in every sheet.
struct InterfaceStyleTests {
    @Test func `following the system clears the window's own style`() {
        #expect(InterfaceStyle.style(for: nil) == .unspecified)
    }

    @Test func `light and dark are set as they are chosen`() {
        #expect(InterfaceStyle.style(for: .light) == .light)
        #expect(InterfaceStyle.style(for: .dark) == .dark)
    }
}
