// Tidy sample data for the README's pictures: a few chats, a project, memories and scheduled tasks for a made-up
// person called Sam. Compiled into debug builds for the simulator only, and never into a build that ships.
#if DEBUG && targetEnvironment(simulator)
import Foundation

/// What the app holds when the simulator launches it to take the README's pictures.
public struct ScreenshotSamples: Sendable {
    public let conversations: [Conversation]
    public let projects: [Project]
    public let memories: [Memory]
    public let tasks: [ScheduledTask]

    /// The models the stand-in server lists: one of its own and two it passes on to the cloud.
    public static let models = [
        ChatModel(id: ChatModel.ID("gemma4"), parameterSize: "12B", canThink: true, canSee: true, canUseTools: true),
        ChatModel(id: ChatModel.ID("deepseek-v4.1-flash:cloud"), isCloud: true, canThink: true, canUseTools: true),
        ChatModel(id: ChatModel.ID("glm-5.3:cloud"), isCloud: true, canThink: true, canUseTools: true)
    ]

    /// The model every sample chat was had with.
    public static let model = ChatModel.ID("gemma4")

    /// The samples, dated back from now so that they fall into every group of the chat list.
    public init(now: Date = Date()) {
        let calendar = Calendar.current
        let ranAt = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now).map { $0 < now ? $0 : $0.addingTimeInterval(-86_400) } ?? now
        let garden = Project(name: "Garden", instructions: "We garden in Adelaide, in raised beds. Keep advice practical.")
        let briefing = ScheduledTask(
            title: "Morning briefing",
            prompt: "What is the weather in Adelaide today, and is there anything I should know before I leave?",
            modelID: ScheduledTask.automaticModelID,
            schedule: .daily(TaskTimeOfDay(hour: 7, minute: 0) ?? Self.fallbackTime, timeZone: TimeZone.current.identifier),
            usesWebSearch: true,
            lastRunAt: ranAt,
            createdAt: now.addingTimeInterval(-9 * 86_400),
            updatedAt: now.addingTimeInterval(-9 * 86_400)
        )
        let reminder = ScheduledTask(
            title: "Weekend garden jobs",
            prompt: "Suggest three garden jobs for this weekend in an Adelaide vegetable garden.",
            modelID: ChatModel.ID("deepseek-v4.1-flash:cloud"),
            schedule: .weekly(TaskTimeOfDay(hour: 8, minute: 30) ?? Self.fallbackTime, weekday: 6, timeZone: TimeZone.current.identifier),
            createdAt: now.addingTimeInterval(-2 * 86_400),
            updatedAt: now.addingTimeInterval(-2 * 86_400)
        )
        projects = [garden]
        tasks = [briefing, reminder]
        memories = ScreenshotSamples.memories(now: now)
        conversations = ScreenshotSamples.chats(now: now, garden: garden, briefing: briefing)
    }

    private static let fallbackTime = TaskTimeOfDay(hour: 9, minute: 0)!

    private static func memories(now: Date) -> [Memory] {
        ["Lives in Adelaide", "Has a dog called Pip", "Prefers metric units", "Is learning Kotlin"]
            .enumerated()
            .map { index, text in
                let date = now.addingTimeInterval(TimeInterval(-86_400 * (10 - index)))
                return Memory(id: Memory.ID("m\(index + 1)"), text: text, isFromUser: index.isMultiple(of: 2), createdAt: date, updatedAt: date)
            }
    }

    // swiftlint:disable:next function_body_length
    private static func chats(now: Date, garden: Project, briefing: ScheduledTask) -> [Conversation] {
        let hour: TimeInterval = 3_600
        let day: TimeInterval = 86_400
        return [
            chat("Rename photos by date", at: now.addingTimeInterval(-hour), [
                ask("How can I rename a folder of photos by the date they were taken?"),
                answer(ScreenshotSampleText.renamePhotos, thinkingSeconds: 4)
            ]),
            chat("Sourdough starter timing", at: now.addingTimeInterval(-2 * hour), [
                ask("How long does a sourdough starter take to become active?"),
                Message(
                    role: .assistant,
                    text: ScreenshotSampleText.sourdoughReport,
                    sources: ScreenshotSampleText.sourdoughSources,
                    isResearch: true,
                    createdAt: now.addingTimeInterval(-2 * hour)
                )
            ]),
            chat("Morning briefing", at: briefing.lastRunAt ?? now, taskID: briefing.id, [
                ask(briefing.prompt),
                answer(ScreenshotSampleText.briefing)
            ]),
            chat("Tomato planting plan", at: now.addingTimeInterval(-4 * hour), projectID: garden.id, [
                ask("When should we plant tomatoes, and how far apart?"),
                answer(ScreenshotSampleText.tomatoes)
            ]),
            chat("Weekly meal plan", at: now.addingTimeInterval(-3 * day), isPinned: true, [
                ask("Plan five quick dinners for this week."),
                answer(ScreenshotSampleText.meals)
            ]),
            chat("Tip calculator page", at: now.addingTimeInterval(-day), [
                ask("Make a small page that works out the tip on a bill."),
                answer(ScreenshotSampleText.tipCalculator)
            ]),
            chat("Birthday gift ideas", at: now.addingTimeInterval(-day - hour), isPrivate: true, [
                ask("Gift ideas for a friend who loves hiking, under $50?"),
                answer("A head torch, a merino buff, a trail guide book for your area, or a lightweight insulated flask.")
            ]),
            chat("Plants for a shady corner", at: now.addingTimeInterval(-5 * day), projectID: garden.id, [
                ask("What can we grow in a shady corner?"),
                answer("Lettuce, silverbeet, mint and parsley all cope with part shade.")
            ]),
            chat("Trip to Tasmania in March", at: now.addingTimeInterval(-4 * day), [
                ask("What should I pack for a week in Tasmania in March?"),
                Message(role: .assistant, text: ScreenshotSampleText.tasmania, sources: ScreenshotSampleText.tasmaniaSources)
            ]),
            chat("Fixing a leaking tap", at: now.addingTimeInterval(-6 * day), [
                ask("My kitchen tap drips. What do I check first?"),
                answer("Turn off the water under the sink, then replace the washer or the cartridge, whichever your tap has.")
            ]),
            chat("Learning Kotlin coroutines", at: now.addingTimeInterval(-20 * day), [
                ask("Explain Kotlin coroutines in one paragraph."),
                answer("Coroutines are functions that can pause without blocking a thread, so waiting code reads like ordinary code.")
            ])
        ]
    }

    private static func chat(
        _ title: String,
        at date: Date,
        isPinned: Bool = false,
        isPrivate: Bool = false,
        projectID: Project.ID? = nil,
        taskID: ScheduledTask.ID? = nil,
        _ messages: [Message]
    ) -> Conversation {
        Conversation(
            title: title,
            modelID: model,
            messages: messages,
            isPinned: isPinned,
            isPrivate: isPrivate,
            projectID: projectID,
            taskID: taskID,
            createdAt: date,
            updatedAt: date,
            modifiedAt: date
        )
    }

    private static func ask(_ text: String) -> Message {
        Message(role: .user, text: text)
    }

    private static func answer(_ text: String, thinkingSeconds: Int? = nil) -> Message {
        Message(
            role: .assistant,
            text: text,
            thinking: thinkingSeconds == nil ? "" : "The user wants the files named by when each photo was taken.",
            thinkingSeconds: thinkingSeconds
        )
    }
}
#endif
