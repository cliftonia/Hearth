import Foundation

// The date as every prompt tells it.
extension PromptBuilder {
    /// The date as the model is told it, such as "Monday 16 November 2026": in English, whatever the device's
    /// language and calendar, so that every prompt reads the same, and in the given time zone, the device's by default.
    public static func dateText(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter.string(from: date)
    }
}
