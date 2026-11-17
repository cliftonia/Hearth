import Foundation

// Scheduled tasks: the page that lists them, the sheet that makes or edits one, their notifications, and the mark on
// a chat a task filed.
// swiftlint:disable line_length
extension Strings {
    static let tasks = String(localized: "tasks.title", defaultValue: "Scheduled tasks", bundle: .module)
    static let tasksFooter = String(localized: "tasks.footer", defaultValue: "Your Hearth Hub asks a cloud model each question at its time, and files the answer as a new chat on all your devices.", bundle: .module)
    static let tasksNeedSync = String(localized: "tasks.needSync", defaultValue: "Scheduled tasks run on your Hearth Hub, so they need sync. Turn sync on to add one.", bundle: .module)
    static let tasksOpenSync = String(localized: "tasks.openSync", defaultValue: "Set up sync", bundle: .module)
    static let tasksEmpty = String(localized: "tasks.empty", defaultValue: "No scheduled tasks yet.", bundle: .module)
    static let tasksAdd = String(localized: "tasks.add", defaultValue: "Add task", bundle: .module)
    static let taskEnabled = String(localized: "tasks.enabled", defaultValue: "Run this task", bundle: .module)
    static let taskNotRunYet = String(localized: "tasks.notRunYet", defaultValue: "Not run yet", bundle: .module)
    static let taskLastRunFailed = String(localized: "tasks.lastRunFailed", defaultValue: "Last run failed", bundle: .module)
    static let taskActionFailed = String(localized: "tasks.actionFailed", defaultValue: "The task could not be saved on this device. Try again.", bundle: .module)

    static let newTask = String(localized: "tasks.new", defaultValue: "New task", bundle: .module)
    static let editTask = String(localized: "tasks.edit", defaultValue: "Edit task", bundle: .module)
    static let taskTitle = String(localized: "tasks.titleField", defaultValue: "Title", bundle: .module)
    static let taskTitlePlaceholder = String(localized: "tasks.titlePlaceholder", defaultValue: "Morning briefing", bundle: .module)
    static let taskPrompt = String(localized: "tasks.prompt", defaultValue: "Question", bundle: .module)
    static let taskPromptPlaceholder = String(localized: "tasks.promptPlaceholder", defaultValue: "What should the model be asked each time?", bundle: .module)
    static let taskModel = String(localized: "tasks.model", defaultValue: "Model", bundle: .module)
    static let taskModelAutomatic = String(localized: "tasks.modelAutomatic", defaultValue: "Automatic", bundle: .module)
    static let taskModelAutomaticDetail = String(localized: "tasks.modelAutomaticDetail", defaultValue: "Kimi in the cloud, then your own model if the graphics card is free.", bundle: .module)
    static let taskModelChoose = String(localized: "tasks.modelChoose", defaultValue: "Choose a model", bundle: .module)
    static let taskModelFooter = String(localized: "tasks.modelFooter", defaultValue: "Only cloud models can run a task, since the hub runs it while your devices are away.", bundle: .module)
    static let taskNoCloudModels = String(localized: "tasks.noCloudModels", defaultValue: "No other cloud models are available. Your chat server lists them with names ending in “cloud”.", bundle: .module)
    static let taskSchedule = String(localized: "tasks.schedule", defaultValue: "Schedule", bundle: .module)
    static let taskDaily = String(localized: "tasks.kind.daily", defaultValue: "Daily", bundle: .module)
    static let taskWeekly = String(localized: "tasks.kind.weekly", defaultValue: "Weekly", bundle: .module)
    static let taskOnce = String(localized: "tasks.kind.once", defaultValue: "Once", bundle: .module)
    static let taskTime = String(localized: "tasks.time", defaultValue: "Time", bundle: .module)
    static let taskWeekday = String(localized: "tasks.weekday", defaultValue: "Day", bundle: .module)
    static let taskDate = String(localized: "tasks.date", defaultValue: "Date and time", bundle: .module)
    static let taskWebSearch = String(localized: "tasks.webSearch", defaultValue: "Search the web first", bundle: .module)
    static let taskWebSearchDetail = String(localized: "tasks.webSearchDetail", defaultValue: "The hub looks the question up before asking the model.", bundle: .module)
    static let deleteTask = String(localized: "tasks.delete", defaultValue: "Delete task", bundle: .module)
    static let deleteTaskQuestion = String(localized: "tasks.deleteQuestion", defaultValue: "Delete this task? The hub stops running it. Chats it already made are kept.", bundle: .module)

    static let notifyTasks = String(localized: "notifications.tasks", defaultValue: "Scheduled tasks", bundle: .module)
    static let notifyTasksDetail = String(localized: "notifications.tasksDetail", defaultValue: "When the answer to a scheduled task arrives while Hearth is not on screen.", bundle: .module)

    static let scheduleTask = String(localized: "tasks.fromComposer", defaultValue: "Schedule a task", bundle: .module)

    static let scheduledTaskMark = String(localized: "tasks.mark", defaultValue: "Scheduled task", bundle: .module)

    static func taskEveryDay(time: String) -> String {
        String(localized: "tasks.schedule.daily", defaultValue: "Every day at \(time)", bundle: .module)
    }

    static func taskEveryWeek(weekday: String, time: String) -> String {
        String(localized: "tasks.schedule.weekly", defaultValue: "Every \(weekday) at \(time)", bundle: .module)
    }

    static func taskOnceAt(date: String, time: String) -> String {
        String(localized: "tasks.schedule.once", defaultValue: "Once, \(date) at \(time)", bundle: .module)
    }

    static func taskRanToday(time: String) -> String {
        String(localized: "tasks.ranToday", defaultValue: "Ran today at \(time)", bundle: .module)
    }

    static func taskRanYesterday(time: String) -> String {
        String(localized: "tasks.ranYesterday", defaultValue: "Ran yesterday at \(time)", bundle: .module)
    }

    static func taskRanOn(date: String, time: String) -> String {
        String(localized: "tasks.ranOn", defaultValue: "Ran \(date) at \(time)", bundle: .module)
    }

    static func taskScheduleAndModel(schedule: String, model: String) -> String {
        String(localized: "tasks.scheduleAndModel", defaultValue: "\(schedule) · \(model)", bundle: .module)
    }

    static func taskRowLabel(title: String, schedule: String, model: String, lastRun: String) -> String {
        String(localized: "tasks.rowLabel", defaultValue: "\(title), \(schedule), \(model), \(lastRun)", bundle: .module)
    }

    static func taskEnabledLabel(title: String) -> String {
        String(localized: "tasks.enabledLabel", defaultValue: "Run this task, \(title)", bundle: .module)
    }
}
// swiftlint:enable line_length
