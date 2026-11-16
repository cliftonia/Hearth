import Foundation
import HearthDomain

/// Puts a task's schedule and its last run into words: "Every day at 7:30", "Every Friday at 18:00",
/// "Once, 20 Nov at 9:00"; "Ran today at 7:30", "Last run failed", "Not run yet".
///
/// Times follow the locale's clock, 24-hour or 12-hour. A daily or weekly time is the time on the clock it was set
/// for; a moment (a one-off run, the last run) is shown in the device's time zone, which `calendar` carries.
struct TaskScheduleFormatter {
    let calendar: Calendar
    let now: Date

    /// The schedule in words.
    func description(of schedule: TaskSchedule) -> String {
        switch schedule {
        case .daily(let time, _):
            Strings.taskEveryDay(time: text(of: time))
        case .weekly(let time, let weekday, _):
            Strings.taskEveryWeek(weekday: weekdayName(weekday), time: text(of: time))
        case .once(let date):
            Strings.taskOnceAt(date: dayText(of: date), time: timeText(of: date))
        }
    }

    /// How the last run went: failed, when it ran, or that it has not.
    func lastRun(of task: ScheduledTask) -> String {
        if task.lastRunFailed {
            return Strings.taskLastRunFailed
        }
        guard let date = task.lastRunAt else {
            return Strings.taskNotRunYet
        }
        let time = timeText(of: date)
        if calendar.isDate(date, inSameDayAs: now) {
            return Strings.taskRanToday(time: time)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return Strings.taskRanYesterday(time: time)
        }
        return Strings.taskRanOn(date: dayText(of: date), time: time)
    }

    /// The name of a weekday numbered from 1 for Monday to 7 for Sunday, in the calendar's language.
    func weekdayName(_ weekday: Int) -> String {
        // The calendar's own list starts on Sunday.
        let symbols = calendar.standaloneWeekdaySymbols
        return symbols[weekday % 7]
    }

    // MARK: Pieces

    /// A time on the clock, `7:30` on a 24-hour clock or `7:30 AM` on a 12-hour one.
    func text(of time: TaskTimeOfDay) -> String {
        let minute = String(format: "%02d", time.minute)
        guard !usesTwentyFourHourClock else {
            return "\(time.hour):\(minute)"
        }
        let formatter = DateFormatter()
        formatter.locale = calendar.locale
        let hour = time.hour % 12 == 0 ? 12 : time.hour % 12
        return "\(hour):\(minute) \(time.hour < 12 ? formatter.amSymbol ?? "AM" : formatter.pmSymbol ?? "PM")"
    }

    private func timeText(of date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return TaskTimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0).map(text(of:)) ?? ""
    }

    /// A day and a short month, `20 Nov`, in the locale's order, with the year only when it is not this one.
    private func dayText(of date: Date) -> String {
        let isThisYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(isThisYear ? "dMMM" : "dMMMy")
        return formatter.string(from: date)
    }

    private var usesTwentyFourHourClock: Bool {
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: calendar.locale) ?? "H"
        return pattern.contains("H") || pattern.contains("k")
    }
}
