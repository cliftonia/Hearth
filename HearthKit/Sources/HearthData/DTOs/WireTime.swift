import Foundation

/// Times as the hub's wire format writes them: ISO-8601 in UTC with exactly three fractional digits,
/// `2026-11-16T09:30:12.345Z`. Worked out from whole milliseconds, so a time is never rounded differently on the way
/// out than on the way back in.
public enum WireTime {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// Whole milliseconds since 1970, rounded to the nearest.
    public static func milliseconds(of date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    /// The date at a whole number of milliseconds since 1970.
    public static func date(milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    public static func string(from date: Date) -> String {
        let total = milliseconds(of: date)
        let millisecond = Int(((total % 1000) + 1000) % 1000)
        let seconds = Date(timeIntervalSince1970: Double((total - Int64(millisecond)) / 1000))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: seconds)
        return String(
            format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
            parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1, parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, millisecond
        )
    }

    /// Reads a UTC time written `YYYY-MM-DDTHH:MM:SS`, with or without a fraction of a second, ending in `Z`.
    /// Digits past the millisecond are dropped. `nil` for anything else.
    public static func date(from text: String) -> Date? {
        guard text.hasSuffix("Z") else {
            return nil
        }
        let halves = text.dropLast().split(separator: "T", omittingEmptySubsequences: false)
        guard halves.count == 2 else {
            return nil
        }
        let clock = halves[1].split(separator: ".", omittingEmptySubsequences: false)
        let day = numbers(in: halves[0], separator: "-", widths: [4, 2, 2])
        let time = numbers(in: clock[0], separator: ":", widths: [2, 2, 2])
        let fraction = clock.count == 2 ? clock[1] : "000"
        guard let day, let time, clock.count <= 2, (1...9).contains(fraction.count), fraction.allSatisfy(\.isASCIIDigit) else {
            return nil
        }
        let parts = DateComponents(year: day[0], month: day[1], day: day[2], hour: time[0], minute: time[1], second: time[2])
        guard let seconds = calendar.date(from: parts) else {
            return nil
        }
        let millisecond = Int64(String(fraction.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0
        return date(milliseconds: Int64(seconds.timeIntervalSince1970.rounded()) * 1000 + millisecond)
    }

    /// The numbers between the separators, each of exactly its width in digits; `nil` if the text is not so.
    private static func numbers(in text: Substring, separator: Character, widths: [Int]) -> [Int]? {
        let fields = text.split(separator: separator, omittingEmptySubsequences: false)
        guard fields.count == widths.count,
              zip(fields, widths).allSatisfy({ $0.count == $1 && $0.allSatisfy(\.isASCIIDigit) }) else {
            return nil
        }
        return fields.compactMap { Int($0) }
    }

    /// A JSON encoder that writes dates in the wire form and data as standard Base64.
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(string(from: date))
        }
        encoder.dataEncodingStrategy = .base64
        return encoder
    }

    /// A JSON decoder that reads dates in the wire form, and data as standard Base64.
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO-8601 UTC time")
            }
            return date
        }
        decoder.dataDecodingStrategy = .base64
        return decoder
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
