import Foundation

/// The part of the day, for a greeting that suits the hour.
public enum DayPartKind: Hashable, Sendable {
    case morning
    case afternoon
    case evening
    /// The small hours, when "good evening" and "good morning" both ring false.
    case night
}

/// The day of the week, for a greeting that names it.
public enum WeekdayKind: Int, Hashable, Sendable, CaseIterable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    /// The day for a calendar's weekday number, where 1 is Sunday. A number outside 1 to 7 wraps round.
    public init(calendarWeekday: Int) {
        self = Self(rawValue: ((calendarWeekday - 1) % 7 + 7) % 7 + 1) ?? .sunday
    }
}

/// What an empty chat says to invite a message.
public enum GreetingKind: Hashable, Sendable {
    case letsTalk
    case dayPart(DayPartKind)
    case onYourMind
    /// Wishes a happy day, by the day's name.
    case weekday(WeekdayKind)
    /// Only said to someone whose name is known.
    case goodToSeeYou
}

/// A greeting and, when it is known, the name of the person greeted.
public struct Greeting: Hashable, Sendable {
    public let kind: GreetingKind
    public let name: String?

    public init(kind: GreetingKind, name: String?) {
        self.kind = kind
        self.name = name
    }
}

/// Chooses the short line an empty chat opens with, so that it is not the same every time.
///
/// The choice is steady for one chat, so the line does not change while it is being looked at, and varies
/// from one new chat to the next.
public struct GreetingPlanner: Sendable {
    public init() {}

    /// - Parameters:
    ///   - name: The user's name, if the app knows it.
    ///   - hour: The hour of the day, from 0 to 23.
    ///   - weekday: The day of the week.
    ///   - seed: Any number that stays the same for one chat and differs between chats.
    public func greeting(name: String?, hour: Int, weekday: WeekdayKind, seed: Int) -> Greeting {
        let known = name.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        var kinds: [GreetingKind] = [.letsTalk, .dayPart(dayPart(for: hour)), .onYourMind, .weekday(weekday)]
        if known != nil {
            kinds.append(.goodToSeeYou)
        }
        return Greeting(kind: kinds[Int(seed.magnitude % UInt(kinds.count))], name: known)
    }

    private func dayPart(for hour: Int) -> DayPartKind {
        switch hour {
        case 5..<12:
            .morning
        case 12..<18:
            .afternoon
        case 18..<23:
            .evening
        default:
            .night
        }
    }
}

/// Looks for the user's name among what is remembered about them, for when they have not given it in their profile.
public struct UserNameFinder: Sendable {
    /// How a memory is likely to say the name. The name itself is one or two capitalised words.
    private static let patterns = [
        #"(?i:\bmy name is|\bname is|\bis called|\bis named|\bgo(?:es)? by|\bcall (?:me|them|him|her))\s+([A-Z][\p{L}'-]+(?:\s[A-Z][\p{L}'-]+)?)"#,
        #"(?i:\bname:)\s*([A-Z][\p{L}'-]+)"#
    ]

    public init() {}

    /// The first name found, from the memories in the order given; `nil` when none says one.
    public func name(in memories: [Memory]) -> String? {
        for memory in memories {
            for pattern in Self.patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: memory.text, range: NSRange(memory.text.startIndex..., in: memory.text)),
                      let range = Range(match.range(at: 1), in: memory.text) else {
                    continue
                }
                // Only the first name is used: a greeting by full name reads like a form letter.
                return memory.text[range].split(separator: " ").first.map(String.init)
            }
        }
        return nil
    }
}
