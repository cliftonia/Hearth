import Foundation

// Deep research: the choice in the model sheet, the steps shown while it runs, its sources and its errors.
// swiftlint:disable line_length
extension Strings {
    static let research = String(localized: "research.title", defaultValue: "Deep research", bundle: .module)
    static let researchDetail = String(localized: "research.detail", defaultValue: "Searches, reads the pages and writes a sourced report", bundle: .module)
    static let researchNeedsSearch = String(localized: "research.needsSearch", defaultValue: "Add a search address in Settings", bundle: .module)
    static let effortStandard = String(localized: "research.effortStandard", defaultValue: "Standard", bundle: .module)
    static let researchPlaceholder = String(localized: "research.placeholder", defaultValue: "Ask a question to research", bundle: .module)
    static let researchPlanning = String(localized: "research.planning", defaultValue: "Planning", bundle: .module)
    static let researchChecking = String(localized: "research.checking", defaultValue: "Checking for gaps", bundle: .module)
    static let researchWriting = String(localized: "research.writing", defaultValue: "Writing", bundle: .module)
    static let researchSources = String(localized: "research.sources", defaultValue: "Sources", bundle: .module)
    static let sourcesHeading = String(localized: "sources.heading", defaultValue: "Sources:", bundle: .module)
    static let sourcesCountOne = String(localized: "sources.count.one", defaultValue: "1 source", bundle: .module)
    static let errorResearchNotConfigured = String(localized: "error.researchNotConfigured", defaultValue: "Add a search address in Settings to research a question.", bundle: .module)
    static let errorResearchSearchFailed = String(localized: "error.researchSearchFailed", defaultValue: "The web could not be searched, so nothing was researched.", bundle: .module)
    static let errorResearchNothingFound = String(localized: "error.researchNothingFound", defaultValue: "The searches found no pages to read, so no report was written.", bundle: .module)
    static let errorResearchNothingReadable = String(localized: "error.researchNothingReadable", defaultValue: "None of the pages found could be read, so no report was written.", bundle: .module)
    static let errorResearchNothingRelevant = String(localized: "error.researchNothingRelevant", defaultValue: "The pages read said nothing about the question, so no report was written.", bundle: .module)

    static func researchSearching(number: Int, total: Int) -> String {
        String(localized: "research.searching", defaultValue: "Searching \(number) of \(total)", bundle: .module)
    }

    static func researchReading(number: Int, total: Int) -> String {
        String(localized: "research.reading", defaultValue: "Reading \(number) of \(total)", bundle: .module)
    }

    static func researchTakingNotes(number: Int, total: Int) -> String {
        String(localized: "research.takingNotes", defaultValue: "Taking notes \(number) of \(total)", bundle: .module)
    }

    static func sourcesCount(_ total: Int) -> String {
        String(localized: "sources.count", defaultValue: "\(total) sources", bundle: .module)
    }

    static func researchSource(number: Int, title: String, host: String) -> String {
        String(localized: "research.source", defaultValue: "Source \(number): \(title), \(host)", bundle: .module)
    }
}
// swiftlint:enable line_length
