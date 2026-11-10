import Foundation
import os

public extension Logger {
    /// A logger whose category is the name of the given type.
    init<Subject>(for type: Subject.Type) {
        self.init(
            subsystem: Bundle.main.bundleIdentifier ?? "Hearth",
            category: String(describing: type)
        )
    }
}
