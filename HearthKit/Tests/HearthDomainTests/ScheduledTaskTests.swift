import Foundation
import HearthData
@testable import HearthDomain
import Testing

/// Scheduled tasks as models: the wire examples of the shared `Spec` folder read into them, their schedules written
/// back, and which models may run one.
struct ScheduledTaskTests {
    private struct WireFile: Decodable {
        let kind: String
        let id: String
        let put: Change
        let expect: Expectation
    }

    private struct Change: Decodable {
        let updatedAt: String
        let body: JSONValue?
    }

    private struct Expectation: Decodable {
        let title: String?
        let model: String?
        let timeZone: String?
        let isEnabled: Bool?
        let usesWebSearch: Bool?
        let lastRunAt: Double?
        let lastRunFailed: Bool?
    }

    @Test func `each task example becomes the task it describes`() throws {
        var checked = 0
        for name in try Spec.files(in: "wire") {
            let file = try Spec.load(WireFile.self, "wire/\(name)")
            guard file.kind == "task", let body = file.put.body else {
                continue
            }
            let id = ScheduledTask.ID(try #require(UUID(uuidString: file.id)))
            let task = try ScheduledTask(from: try SyncWire.decode(TaskBodyDTO.self, from: body), id: id, updatedAt: Date())

            #expect(task.title == file.expect.title, "\(name)")
            #expect(task.modelID.rawValue == file.expect.model, "\(name)")
            #expect(task.schedule.timeZoneIdentifier == file.expect.timeZone, "\(name)")
            #expect(task.isEnabled == file.expect.isEnabled, "\(name)")
            #expect(task.usesWebSearch == file.expect.usesWebSearch, "\(name)")
            #expect(task.lastRunAt?.timeIntervalSince1970 == file.expect.lastRunAt, "\(name)")
            #expect(task.lastRunFailed == file.expect.lastRunFailed, "\(name)")
            checked += 1
        }
        #expect(checked == 2)
    }

    @Test func `the weekly example runs on Friday at six in the evening`() throws {
        let file = try Spec.load(WireFile.self, "wire/task-weekly-run.json")
        let dto = try SyncWire.decode(TaskBodyDTO.self, from: try #require(file.put.body))
        let schedule = try TaskSchedule(from: dto.schedule)

        #expect(schedule == .weekly(try #require(TaskTimeOfDay(text: "18:00")), weekday: 5, timeZone: "Australia/Brisbane"))
    }

    @Test(arguments: [
        TaskSchedule.daily(TaskTimeOfDay(hour: 7, minute: 30)!, timeZone: "Australia/Brisbane"),
        TaskSchedule.weekly(TaskTimeOfDay(hour: 18, minute: 0)!, weekday: 7, timeZone: "Europe/London"),
        TaskSchedule.once(Date(timeIntervalSince1970: 1_795_000_000))
    ])
    func `a schedule written to the wire reads back the same`(schedule: TaskSchedule) throws {
        let json = try SyncWire.json(from: TaskScheduleDTO(from: schedule))

        #expect(try TaskSchedule(from: SyncWire.decode(TaskScheduleDTO.self, from: json)) == schedule)
    }

    @Test(arguments: [
        TaskScheduleDTO(kind: "monthly", time: "07:30", timeZone: "UTC"),
        TaskScheduleDTO(kind: "daily", time: "7.30", timeZone: "UTC"),
        TaskScheduleDTO(kind: "daily", time: "24:00", timeZone: "UTC"),
        TaskScheduleDTO(kind: "weekly", time: "07:30", weekday: 8, timeZone: "UTC"),
        TaskScheduleDTO(kind: "daily", time: "07:30"),
        TaskScheduleDTO(kind: "once")
    ])
    func `a schedule this app cannot read is refused rather than guessed at`(dto: TaskScheduleDTO) {
        #expect(throws: SyncMappingError.invalidSchedule) { try TaskSchedule(from: dto) }
    }

    @Test func `a time on the clock is written as two digits each side`() {
        #expect(TaskTimeOfDay(hour: 7, minute: 5)?.text == "07:05")
        #expect(TaskTimeOfDay(text: "7:05") == TaskTimeOfDay(hour: 7, minute: 5))
    }

    @Test(arguments: [
        ("auto", true),
        ("deepseek-v4.1-flash:cloud", true),
        ("gpt-oss:120b-cloud", true),
        ("Qwen3-Coder:480B-CLOUD", true),
        ("llama3.2:latest", false),
        ("cloudy-model:7b", false),
        ("gemma3:12b", false)
    ])
    func `only a model the server passes on to a cloud host can run a task`(name: String, isCloud: Bool) {
        #expect(ScheduledTask.isCloudModel(ChatModel.ID(name)) == isCloud)
    }

    @Test func `the cloud models are picked from the server's list in its order`() {
        let models = ["llama3.2:latest", "gpt-oss:120b-cloud", "gemma3:12b", "kimi-k2:1t-cloud"].map { ChatModel(id: ChatModel.ID($0)) }

        #expect(ScheduledTask.cloudModels(from: models).map(\.id.rawValue) == ["gpt-oss:120b-cloud", "kimi-k2:1t-cloud"])
        #expect(ScheduledTask.cloudModels(from: [ChatModel(id: ChatModel.ID("llama3.2:latest"))]).isEmpty)
    }

    @Test func `a conversation keeps the task it was filed for, and writes it back`() throws {
        let taskID = ScheduledTask.ID(UUID())
        var body = try #require(SyncSamples.body(of: SyncSamples.conversation(title: "Briefing")).objectValue)
        body["taskId"] = .string(taskID.rawValue.uuidString.lowercased())
        let dto = try SyncWire.decode(ConversationBodyDTO.self, from: .object(body))

        let conversation = try Conversation(from: dto, id: Conversation.ID(UUID()), modifiedAt: Date(), taskID: ScheduledTask.ID(referencedBy: .object(body)))

        #expect(conversation.taskID == taskID)
        #expect(conversation.updating(title: "Renamed").taskID == taskID)
        #expect(try conversation.syncBody().objectValue?["taskId"] == .string(taskID.rawValue.uuidString.lowercased()))
        #expect(try Conversation(from: dto, id: conversation.id, modifiedAt: Date()).syncBody().objectValue?["taskId"] == nil)
    }
}

/// Which answers of scheduled tasks are announced, and with what words.
struct TaskResultNotificationPlannerTests {
    private func answer(_ title: String, text: String, isFromTask: Bool = true) -> Conversation {
        let taskID: ScheduledTask.ID? = if isFromTask { ScheduledTask.ID(UUID()) } else { nil }
        return Conversation(
            title: title,
            messages: [Message(role: .user, text: "News?"), Message(role: .assistant, text: text)],
            taskID: taskID
        )
    }

    @Test func `an answer that arrives off screen is announced with its title and its opening words`() {
        let long = String(repeating: "word ", count: 40)
        let notices = TaskResultNotificationPlanner().notifications(for: [answer("Morning briefing", text: long)], isEnabled: true, isOnScreen: false)

        #expect(notices.count == 1)
        #expect(notices[0].title == "Morning briefing")
        #expect(notices[0].body.count <= TaskResultNotificationPlanner.maximumExcerptLength + 1)
        #expect(notices[0].body.hasSuffix("…"))
    }

    @Test func `nothing is announced while the switch is off or the app is on screen, or for a chat no task filed`() {
        let planner = TaskResultNotificationPlanner()
        let chat = answer("Briefing", text: "Three stories.")

        #expect(planner.notifications(for: [chat], isEnabled: false, isOnScreen: false).isEmpty)
        #expect(planner.notifications(for: [chat], isEnabled: true, isOnScreen: true).isEmpty)
        #expect(planner.notifications(for: [answer("Ordinary", text: "Hi", isFromTask: false)], isEnabled: true, isOnScreen: false).isEmpty)
        #expect(planner.notifications(for: [answer("Empty", text: "  ")], isEnabled: true, isOnScreen: false).isEmpty)
    }

    @Test func `after a long time away only the latest few are announced`() {
        let chats = (1...6).map { answer("Run \($0)", text: "Answer \($0)") }

        let notices = TaskResultNotificationPlanner().notifications(for: chats, isEnabled: true, isOnScreen: false)

        #expect(notices.map(\.title) == ["Run 4", "Run 5", "Run 6"])
    }
}
