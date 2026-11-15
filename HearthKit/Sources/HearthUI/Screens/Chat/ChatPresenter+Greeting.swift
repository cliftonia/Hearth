import Foundation
import HearthDomain

// The line an empty chat opens with.
extension ChatPresenter {
    /// A short greeting, by name when the name is known. It is steady for one chat and varies between chats.
    ///
    /// The name is the nickname in the user's profile, failing that the first word of their full name, and failing
    /// that a name found in what is remembered about them. A private chat uses no memories, so there it comes
    /// from the profile alone.
    var greeting: String {
        let conversation = viewModel.conversation
        let now = Date()
        let remembered = settings.allowsMemory(in: conversation) ? UserNameFinder().name(in: dependencies.memoryStore.memories) : nil
        let greeting = GreetingPlanner().greeting(
            name: settings.profile.preferredName ?? remembered,
            hour: Calendar.current.component(.hour, from: now),
            weekday: WeekdayKind(calendarWeekday: Calendar.current.component(.weekday, from: now)),
            seed: Self.seed(for: conversation.id)
        )
        return Self.words(for: greeting)
    }

    /// A number that is the same every time for one chat. Swift's own hashes differ from launch to launch.
    private static func seed(for id: Conversation.ID) -> Int {
        id.rawValue.uuidString.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    private static func words(for greeting: Greeting) -> String {
        guard let name = greeting.name else {
            switch greeting.kind {
            case .letsTalk, .goodToSeeYou:
                return Strings.greetLetsTalk
            case .onYourMind:
                return Strings.greetOnYourMind
            case .dayPart(let part):
                return words(for: part)
            case .weekday(let day):
                return words(for: day)
            }
        }
        switch greeting.kind {
        case .letsTalk:
            return Strings.greetLetsTalk(name: name)
        case .goodToSeeYou:
            return Strings.greetGoodToSeeYou(name: name)
        case .onYourMind:
            return Strings.greetOnYourMind(name: name)
        case .dayPart(let part):
            return words(for: part, name: name)
        case .weekday(let day):
            return words(for: day, name: name)
        }
    }

    private static func words(for day: WeekdayKind) -> String {
        switch day {
        case .sunday:
            Strings.greetSunday
        case .monday:
            Strings.greetMonday
        case .tuesday:
            Strings.greetTuesday
        case .wednesday:
            Strings.greetWednesday
        case .thursday:
            Strings.greetThursday
        case .friday:
            Strings.greetFriday
        case .saturday:
            Strings.greetSaturday
        }
    }

    private static func words(for day: WeekdayKind, name: String) -> String {
        switch day {
        case .sunday:
            Strings.greetSunday(name: name)
        case .monday:
            Strings.greetMonday(name: name)
        case .tuesday:
            Strings.greetTuesday(name: name)
        case .wednesday:
            Strings.greetWednesday(name: name)
        case .thursday:
            Strings.greetThursday(name: name)
        case .friday:
            Strings.greetFriday(name: name)
        case .saturday:
            Strings.greetSaturday(name: name)
        }
    }

    private static func words(for part: DayPartKind) -> String {
        switch part {
        case .morning:
            Strings.greetMorning
        case .afternoon:
            Strings.greetAfternoon
        case .evening:
            Strings.greetEvening
        case .night:
            Strings.greetNight
        }
    }

    private static func words(for part: DayPartKind, name: String) -> String {
        switch part {
        case .morning:
            Strings.greetMorning(name: name)
        case .afternoon:
            Strings.greetAfternoon(name: name)
        case .evening:
            Strings.greetEvening(name: name)
        case .night:
            Strings.greetNight(name: name)
        }
    }
}
