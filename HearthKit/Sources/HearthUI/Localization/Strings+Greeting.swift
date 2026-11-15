import Foundation

// The short lines an empty chat opens with, with and without the user's name.
extension Strings {
    static let greetLetsTalk = String(localized: "greet.letsTalk", defaultValue: "Let's talk.", bundle: .module)
    static let greetOnYourMind = String(localized: "greet.onYourMind", defaultValue: "What's on your mind?", bundle: .module)
    static let greetMorning = String(localized: "greet.morning", defaultValue: "Morning.", bundle: .module)
    static let greetAfternoon = String(localized: "greet.afternoon", defaultValue: "Afternoon.", bundle: .module)
    static let greetEvening = String(localized: "greet.evening", defaultValue: "Evening.", bundle: .module)
    static let greetNight = String(localized: "greet.night", defaultValue: "Up late?", bundle: .module)
    static let greetSunday = String(localized: "greet.sunday", defaultValue: "Happy Sunday.", bundle: .module)
    static let greetMonday = String(localized: "greet.monday", defaultValue: "Happy Monday.", bundle: .module)
    static let greetTuesday = String(localized: "greet.tuesday", defaultValue: "Happy Tuesday.", bundle: .module)
    static let greetWednesday = String(localized: "greet.wednesday", defaultValue: "Happy Wednesday.", bundle: .module)
    static let greetThursday = String(localized: "greet.thursday", defaultValue: "Happy Thursday.", bundle: .module)
    static let greetFriday = String(localized: "greet.friday", defaultValue: "Happy Friday.", bundle: .module)
    static let greetSaturday = String(localized: "greet.saturday", defaultValue: "Happy Saturday.", bundle: .module)

    static func greetLetsTalk(name: String) -> String {
        String(localized: "greet.letsTalk.named", defaultValue: "Let's talk, \(name).", bundle: .module)
    }

    static func greetGoodToSeeYou(name: String) -> String {
        String(localized: "greet.goodToSeeYou.named", defaultValue: "Good to see you, \(name).", bundle: .module)
    }

    static func greetOnYourMind(name: String) -> String {
        String(localized: "greet.onYourMind.named", defaultValue: "What's on your mind, \(name)?", bundle: .module)
    }

    static func greetMorning(name: String) -> String {
        String(localized: "greet.morning.named", defaultValue: "Morning, \(name).", bundle: .module)
    }

    static func greetAfternoon(name: String) -> String {
        String(localized: "greet.afternoon.named", defaultValue: "Afternoon, \(name).", bundle: .module)
    }

    static func greetEvening(name: String) -> String {
        String(localized: "greet.evening.named", defaultValue: "Evening, \(name).", bundle: .module)
    }

    static func greetNight(name: String) -> String {
        String(localized: "greet.night.named", defaultValue: "Up late, \(name)?", bundle: .module)
    }

    static func greetSunday(name: String) -> String {
        String(localized: "greet.sunday.named", defaultValue: "Happy Sunday, \(name).", bundle: .module)
    }

    static func greetMonday(name: String) -> String {
        String(localized: "greet.monday.named", defaultValue: "Happy Monday, \(name).", bundle: .module)
    }

    static func greetTuesday(name: String) -> String {
        String(localized: "greet.tuesday.named", defaultValue: "Happy Tuesday, \(name).", bundle: .module)
    }

    static func greetWednesday(name: String) -> String {
        String(localized: "greet.wednesday.named", defaultValue: "Happy Wednesday, \(name).", bundle: .module)
    }

    static func greetThursday(name: String) -> String {
        String(localized: "greet.thursday.named", defaultValue: "Happy Thursday, \(name).", bundle: .module)
    }

    static func greetFriday(name: String) -> String {
        String(localized: "greet.friday.named", defaultValue: "Happy Friday, \(name).", bundle: .module)
    }

    static func greetSaturday(name: String) -> String {
        String(localized: "greet.saturday.named", defaultValue: "Happy Saturday, \(name).", bundle: .module)
    }
}
