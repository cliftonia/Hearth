import Foundation
@testable import HearthDomain
import Testing

/// How the line on an empty chat is chosen, and how the user's name is found among the memories.
struct GreetingTests {
    private func memory(_ text: String) -> Memory {
        Memory(id: Memory.ID("m1"), text: text, isFromUser: false, createdAt: Date(), updatedAt: Date())
    }

    @Test func `one chat always gets the same greeting, and different chats get different ones`() {
        let planner = GreetingPlanner()

        #expect(planner.greeting(name: "Sam", hour: 9, weekday: .sunday, seed: 7) == planner.greeting(name: "Sam", hour: 9, weekday: .sunday, seed: 7))
        let kinds = Set((0..<10).map { planner.greeting(name: "Sam", hour: 9, weekday: .sunday, seed: $0).kind })
        #expect(kinds == [.letsTalk, .dayPart(.morning), .onYourMind, .weekday(.sunday), .goodToSeeYou])
    }

    @Test func `without a name nobody is told it is good to see them`() {
        let planner = GreetingPlanner()

        let greetings = (0..<12).map { planner.greeting(name: "  ", hour: 20, weekday: .friday, seed: $0) }
        #expect(greetings.allSatisfy { $0.name == nil })
        #expect(Set(greetings.map(\.kind)) == [.letsTalk, .dayPart(.evening), .onYourMind, .weekday(.friday)])
    }

    @Test(arguments: [(6, DayPartKind.morning), (13, .afternoon), (19, .evening), (23, .night), (2, .night)])
    func `the hour decides the part of the day`(hour: Int, part: DayPartKind) {
        #expect(GreetingPlanner().greeting(name: nil, hour: hour, weekday: .monday, seed: 1).kind == .dayPart(part))
    }

    @Test(arguments: WeekdayKind.allCases)
    func `the day of the week is named, with and without the user's name`(day: WeekdayKind) {
        let planner = GreetingPlanner()

        // The day's greeting is the fourth in the rotation.
        #expect(planner.greeting(name: "Sam", hour: 9, weekday: day, seed: 3) == Greeting(kind: .weekday(day), name: "Sam"))
        #expect(planner.greeting(name: nil, hour: 9, weekday: day, seed: 3) == Greeting(kind: .weekday(day), name: nil))
    }

    @Test(arguments: [(1, WeekdayKind.sunday), (2, .monday), (7, .saturday), (8, .sunday), (0, .saturday)])
    func `a calendar's weekday number is read with Sunday first`(number: Int, day: WeekdayKind) {
        #expect(WeekdayKind(calendarWeekday: number) == day)
    }

    @Test(arguments: [
        ("The user's name is Clifton.", "Clifton"),
        ("My name is Mary Jane Watson", "Mary"),
        ("User is called Sam and lives in Brisbane", "Sam"),
        ("Name: Priya", "Priya"),
        ("Likes to go by Alex at work", "Alex")
    ])
    func `a name said in a memory is found, first name only`(text: String, name: String) {
        #expect(UserNameFinder().name(in: [memory("Prefers tea"), memory(text)]) == name)
    }

    @Test func `memories that say no name give none`() {
        let finder = UserNameFinder()

        #expect(finder.name(in: []) == nil)
        #expect(finder.name(in: [memory("Lives in Brisbane"), memory("The dog's name is rex")]) == nil)
    }
}
