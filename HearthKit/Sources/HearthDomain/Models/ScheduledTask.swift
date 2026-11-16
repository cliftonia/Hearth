import Foundation
import HearthCore

/// A question the user has asked Hearth Hub to put to a cloud model on a schedule. The hub runs it, files each
/// answer as a new chat, and records when it last ran; the app only makes, changes and deletes tasks.
///
/// Tasks live on the hub, so they exist only while sync is on, and are synced like projects and memories.
public struct ScheduledTask: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = Tagged<ScheduledTask, UUID>

    public let id: ID
    public let title: String
    /// What the model is asked each time the task runs.
    public let prompt: String
    /// The cloud model the hub asks.
    public let modelID: ChatModel.ID
    public let schedule: TaskSchedule
    /// Whether the hub runs the task; one switched off is kept but not run.
    public let isEnabled: Bool
    /// Whether the hub searches the web before it asks the model.
    public let usesWebSearch: Bool
    /// When the hub last ran the task; `nil` before its first run. Only the hub writes it.
    public let lastRunAt: Date?
    /// Whether the last run failed. Only the hub writes it.
    public let lastRunFailed: Bool
    public let createdAt: Date
    /// When anything about the task last changed, here or on the hub. Sync compares it; only `TaskStore` stamps it.
    public let updatedAt: Date

    public init(
        id: ID = ID(UUID()),
        title: String,
        prompt: String,
        modelID: ChatModel.ID,
        schedule: TaskSchedule,
        isEnabled: Bool = true,
        usesWebSearch: Bool = false,
        lastRunAt: Date? = nil,
        lastRunFailed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.modelID = modelID
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.usesWebSearch = usesWebSearch
        self.lastRunAt = lastRunAt
        self.lastRunFailed = lastRunFailed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// A copy with what the user can change replaced; anything left `nil` is kept. What the hub writes is kept.
    public func updating(
        title: String? = nil,
        prompt: String? = nil,
        modelID: ChatModel.ID? = nil,
        schedule: TaskSchedule? = nil,
        isEnabled: Bool? = nil,
        usesWebSearch: Bool? = nil
    ) -> ScheduledTask {
        ScheduledTask(
            id: id,
            title: title ?? self.title,
            prompt: prompt ?? self.prompt,
            modelID: modelID ?? self.modelID,
            schedule: schedule ?? self.schedule,
            isEnabled: isEnabled ?? self.isEnabled,
            usesWebSearch: usesWebSearch ?? self.usesWebSearch,
            lastRunAt: lastRunAt,
            lastRunFailed: lastRunFailed,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// A copy stamped as changed at the given moment, for sync.
    public func stamped(at date: Date) -> ScheduledTask {
        ScheduledTask(
            id: id, title: title, prompt: prompt, modelID: modelID, schedule: schedule, isEnabled: isEnabled,
            usesWebSearch: usesWebSearch, lastRunAt: lastRunAt, lastRunFailed: lastRunFailed, createdAt: createdAt, updatedAt: date
        )
    }

    /// The model a task names to leave the choice to the hub, which tries its cloud models in its own order and
    /// falls back to a model of its own when it can. New tasks start with it.
    public static let automaticModelID = ChatModel.ID("auto")

    /// Whether a model is one the hub can run a task with: the hub's own choice (`auto`), or one the chat server
    /// passes on to a cloud host, which it names with a `:cloud` or `-cloud` ending, in any case.
    public static func isCloudModel(_ id: ChatModel.ID) -> Bool {
        let name = id.rawValue.lowercased()
        return id == automaticModelID || name.hasSuffix(":cloud") || name.hasSuffix("-cloud")
    }

    /// The models a task may be given, in the order given.
    public static func cloudModels(from models: [ChatModel]) -> [ChatModel] {
        models.filter { isCloudModel($0.id) }
    }
}

/// When a task runs. A daily or weekly time is a time on the clock in the given time zone, so it stays at 7:30
/// across a change to or from daylight saving time.
public enum TaskSchedule: Hashable, Codable, Sendable {
    case daily(TaskTimeOfDay, timeZone: String)
    /// `weekday` is 1 for Monday through 7 for Sunday.
    case weekly(TaskTimeOfDay, weekday: Int, timeZone: String)
    case once(Date)

    /// The time zone a daily or weekly task is set in; `nil` for one that runs once, at a moment.
    public var timeZoneIdentifier: String? {
        switch self {
        case .daily(_, let timeZone), .weekly(_, _, let timeZone):
            timeZone
        case .once:
            nil
        }
    }
}

/// A time on the clock, to the minute, as the wire writes it: `HH:MM`, 24-hour.
public struct TaskTimeOfDay: Hashable, Codable, Sendable {
    public let hour: Int
    public let minute: Int

    /// The start of the day.
    public static let midnight = TaskTimeOfDay(checkedHour: 0, minute: 0)

    /// - Returns: `nil` for an hour outside 0 to 23 or a minute outside 0 to 59.
    public init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }
        self.init(checkedHour: hour, minute: minute)
    }

    private init(checkedHour hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Reads `HH:MM`; a single-digit hour is read too. `nil` for anything else.
    public init?(text: String) {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        self.init(hour: hour, minute: minute)
    }

    /// `HH:MM`, as the wire writes it.
    public var text: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
