import Foundation

/// A scheduled task's body (docs/WIRE_FORMAT.md, section 7): a question the hub puts to a cloud model on a schedule,
/// filing each answer as a new conversation. The hub writes `lastRunAt` and `lastRunFailed`; the apps write the rest.
///
/// Every field but the schedule is optional here, so a body from an older or newer writer still reads.
public struct TaskBodyDTO: Codable, Sendable, Equatable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case schema, title, prompt, model, schedule, isEnabled, usesWebSearch, lastRunAt, lastRunFailed, createdAt
    }

    public let schema: Int?
    public let title: String?
    public let prompt: String?
    /// The model's name on the chat server, such as `gpt-oss:120b-cloud`.
    public let model: String?
    public let schedule: TaskScheduleDTO
    public let isEnabled: Bool?
    public let usesWebSearch: Bool?
    /// When the hub last ran the task, in seconds since 1970; `nil` before its first run.
    public let lastRunAt: Double?
    public let lastRunFailed: Bool?
    public let createdAt: Date?

    public init(
        schema: Int?, title: String?, prompt: String?, model: String?, schedule: TaskScheduleDTO, isEnabled: Bool?,
        usesWebSearch: Bool?, lastRunAt: Double?, lastRunFailed: Bool?, createdAt: Date?
    ) {
        self.schema = schema
        self.title = title
        self.prompt = prompt
        self.model = model
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.usesWebSearch = usesWebSearch
        self.lastRunAt = lastRunAt
        self.lastRunFailed = lastRunFailed
        self.createdAt = createdAt
    }

    /// Written in full, with `lastRunAt` as `null` before the first run, as the hub's runner expects to find it.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(schema, forKey: .schema)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(prompt, forKey: .prompt)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encode(schedule, forKey: .schedule)
        try container.encodeIfPresent(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(usesWebSearch, forKey: .usesWebSearch)
        if let lastRunAt {
            try container.encode(lastRunAt, forKey: .lastRunAt)
        } else {
            try container.encodeNil(forKey: .lastRunAt)
        }
        try container.encodeIfPresent(lastRunFailed, forKey: .lastRunFailed)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

/// When a task runs: `daily` at a time, `weekly` on a weekday (1 is Monday, 7 Sunday) at a time, both in an IANA
/// time zone, or `once` at a moment in seconds since 1970. It has no `id`, so every client writes it whole.
public struct TaskScheduleDTO: Codable, Sendable, Equatable {
    public let kind: String
    /// `HH:MM`, 24-hour.
    public let time: String?
    public let weekday: Int?
    public let timeZone: String?
    public let at: Double?

    public init(kind: String, time: String? = nil, weekday: Int? = nil, timeZone: String? = nil, at: Double? = nil) {
        self.kind = kind
        self.time = time
        self.weekday = weekday
        self.timeZone = timeZone
        self.at = at
    }
}
