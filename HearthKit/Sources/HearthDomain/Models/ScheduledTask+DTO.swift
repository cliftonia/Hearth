import Foundation
import HearthData

public extension ScheduledTask {
    /// A task from its synced body.
    ///
    /// - Parameters:
    ///   - id: The item's identifier, from its envelope.
    ///   - updatedAt: The envelope's `updatedAt`, which is when the task last changed, here or on the hub.
    /// - Throws: `SyncMappingError.invalidSchedule` for a schedule this app cannot read, and
    ///   `SyncMappingError.missingModel` when no model is named.
    init(from dto: TaskBodyDTO, id: ScheduledTask.ID, updatedAt: Date) throws {
        guard let model = dto.model, !model.isEmpty else {
            throw SyncMappingError.missingModel
        }
        self.init(
            id: id,
            title: dto.title ?? "",
            prompt: dto.prompt ?? "",
            modelID: ChatModel.ID(model),
            schedule: try TaskSchedule(from: dto.schedule),
            isEnabled: dto.isEnabled ?? true,
            usesWebSearch: dto.usesWebSearch ?? false,
            lastRunAt: dto.lastRunAt.map { Date(timeIntervalSince1970: $0) },
            lastRunFailed: dto.lastRunFailed ?? false,
            createdAt: dto.createdAt ?? updatedAt,
            updatedAt: updatedAt
        )
    }
}

public extension TaskSchedule {
    init(from dto: TaskScheduleDTO) throws {
        switch dto.kind {
        case "daily":
            guard let time = dto.time.flatMap(TaskTimeOfDay.init(text:)), let timeZone = dto.timeZone, !timeZone.isEmpty else {
                throw SyncMappingError.invalidSchedule
            }
            self = .daily(time, timeZone: timeZone)
        case "weekly":
            guard let time = dto.time.flatMap(TaskTimeOfDay.init(text:)), let weekday = dto.weekday, (1...7).contains(weekday),
                  let timeZone = dto.timeZone, !timeZone.isEmpty else {
                throw SyncMappingError.invalidSchedule
            }
            self = .weekly(time, weekday: weekday, timeZone: timeZone)
        case "once":
            guard let at = dto.at else {
                throw SyncMappingError.invalidSchedule
            }
            self = .once(Date(timeIntervalSince1970: at))
        default:
            throw SyncMappingError.invalidSchedule
        }
    }
}

public extension TaskBodyDTO {
    init(from task: ScheduledTask) {
        self.init(
            schema: SyncWire.schema,
            title: task.title,
            prompt: task.prompt,
            model: task.modelID.rawValue,
            schedule: TaskScheduleDTO(from: task.schedule),
            isEnabled: task.isEnabled,
            usesWebSearch: task.usesWebSearch,
            lastRunAt: task.lastRunAt?.timeIntervalSince1970,
            lastRunFailed: task.lastRunFailed,
            createdAt: task.createdAt
        )
    }
}

public extension TaskScheduleDTO {
    init(from schedule: TaskSchedule) {
        switch schedule {
        case .daily(let time, let timeZone):
            self.init(kind: "daily", time: time.text, timeZone: timeZone)
        case .weekly(let time, let weekday, let timeZone):
            self.init(kind: "weekly", time: time.text, weekday: weekday, timeZone: timeZone)
        case .once(let date):
            self.init(kind: "once", at: date.timeIntervalSince1970.rounded(.down))
        }
    }
}
