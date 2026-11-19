import CoreGraphics
@testable import HearthUI
import SwiftUI
import Testing

/// A Mac's text follows the system's size while staying larger than an iPad's.
struct MacTextSizeTests {
    @Test func `a Mac with no text size of its own sets text a quarter larger`() {
        let size = Font.macPointSize(base: 17, preferred: 17, standard: 17)

        #expect(abs(size - 21.25) < 0.001)
    }

    @Test(arguments: [(preferred: 20.0, standard: 17.0), (preferred: 14.0, standard: 17.0), (preferred: 13.0, standard: 13.0)])
    func `a Mac follows the system's text size in proportion`(preferred: Double, standard: Double) {
        let size = Font.macPointSize(base: 17, preferred: preferred, standard: standard)

        #expect(abs(size - 17 * Font.macTextScale * preferred / standard) < 0.001)
    }

    @Test func `a missing standard size leaves the Mac's size as it was`() {
        #expect(abs(Font.macPointSize(base: 13, preferred: 15, standard: 0) - 13 * Font.macTextScale) < 0.001)
    }
}
