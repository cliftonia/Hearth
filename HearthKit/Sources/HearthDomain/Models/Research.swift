import Foundation

/// How much work goes into the next reply: thinking at one of the levels, or researching the question on the web.
///
/// Research is switched on beside the thinking levels, never a level sent to the model: while it is on, the model
/// still thinks at the level chosen, so a report can be thought about as hard or as lightly as any reply.
public enum EffortChoiceKind: Hashable, Sendable {
    /// An ordinary reply, thought about this hard.
    case thinking(ThinkingLevelKind)
    /// A report written from pages searched for and read.
    case research

    /// The thinking levels on offer for a model, in the order they are listed. Research is not among them: it has
    /// a switch of its own.
    ///
    /// A model that cannot think has one ordinary choice, which stands for the saved level without changing it.
    public static func choices(canThink: Bool, savedLevel: ThinkingLevelKind) -> [EffortChoiceKind] {
        (canThink ? ThinkingLevelKind.allCases : [savedLevel]).map(EffortChoiceKind.thinking)
    }
}

/// The hard bounds of one piece of research. Together they cap how long it runs and how much it asks of the servers.
public enum ResearchLimits {
    /// How many searches the plan may hold.
    public static let maximumQueries = 5
    /// How many more searches may be made, once, to fill a gap.
    public static let maximumFollowUpQueries = 3
    /// How many pages are chosen to be read from the planned searches.
    public static let maximumSources = 12
    /// How many more pages may be chosen from the follow-up searches.
    public static let maximumFollowUpSources = 4
    /// How many of the chosen pages may come from one site.
    public static let maximumSourcesPerSite = 2
    /// How many pages are fetched at once.
    public static let maximumConcurrentPageFetches = 4
    /// How many pages the model takes notes on at once.
    public static let maximumConcurrentNoteRequests = 3
    /// How long one page is waited for before it is passed over.
    public static let pageTimeout = Duration.seconds(12)
    /// How much of one page's text the model is shown.
    public static let maximumPageCharacters = 6000
    /// A page with less text than this has nothing worth reading: an empty shell or a refusal.
    public static let minimumPageCharacters = 200
    /// How long the notes on one page may be.
    public static let maximumNoteCharacters = 1500
    /// How much of the notes, all told, is handed to the model that writes the report.
    public static let maximumNotesCharacters = 24_000
    /// How long a search query may be.
    public static let maximumQueryCharacters = 200
    /// How much of the earlier conversation is given as background, in messages and in characters of each.
    public static let maximumContextMessages = 4
    public static let maximumContextCharacters = 600
}

/// Why research came to nothing, in terms a screen can explain.
public enum ResearchError: Error, Sendable, Equatable {
    /// No usable address has been given for the search server.
    case searchNotConfigured
    /// Not one of the searches could be made.
    case searchFailed
    /// The searches were made and found no page that could be read from.
    case nothingFound
    /// Pages were found, and not one of them could be read.
    case nothingReadable
    /// Pages were read, and not one of them held anything about the question.
    case nothingRelevant
}

/// What research is doing at this moment.
public enum ResearchStepKind: Hashable, Sendable {
    /// Asking the model what to search for.
    case planning
    /// Making one of the searches.
    case searching(number: Int, total: Int)
    /// Reading one of the pages chosen.
    case reading(number: Int, total: Int)
    /// Taking notes on one of the pages read.
    case takingNotes(number: Int, total: Int)
    /// Asking the model whether anything important is still missing.
    case checking
    /// Writing the report.
    case writing
}

/// What one page had to say about the question.
public struct ResearchNote: Hashable, Sendable {
    /// The number the page is cited by.
    public let number: Int
    public let source: SearchSource
    public let text: String

    public init(number: Int, source: SearchSource, text: String) {
        self.number = number
        self.source = source
        self.text = text
    }
}

/// A finished report and the pages it cites, in the order of their numbers: `[1]` is the first source.
public struct ResearchReport: Hashable, Sendable {
    public let text: String
    public let sources: [SearchSource]

    public init(text: String, sources: [SearchSource]) {
        self.text = text
        self.sources = sources
    }
}
