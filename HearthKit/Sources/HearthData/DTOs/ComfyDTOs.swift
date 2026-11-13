import Foundation

/// A finished picture as ComfyUI names it.
struct ComfyPictureDTO: Decodable, Sendable {
    let filename: String
    let subfolder: String
    let type: String
}

/// The answer to queueing a graph: the name the run goes by.
struct ComfyQueueAnswerDTO: Decodable, Sendable {
    let promptID: String

    enum CodingKeys: String, CodingKey {
        case promptID = "prompt_id"
    }
}

/// The answer to uploading a picture: the name the server gave it.
struct ComfyUploadAnswerDTO: Decodable, Sendable {
    let name: String
}

/// The record of one run: whether it worked, what went wrong, and the pictures it left.
struct ComfyHistoryDTO: Decodable, Sendable {
    let status: ComfyStatusDTO?
    let outputs: [String: ComfyOutputDTO]?
}

struct ComfyStatusDTO: Decodable, Sendable {
    let messages: [ComfyMessageDTO]?
}

/// What one node of a run left behind.
struct ComfyOutputDTO: Decodable, Sendable {
    let images: [ComfyPictureDTO]?
}

/// A message is a name followed by details; only an error's own words are wanted.
struct ComfyMessageDTO: Decodable, Sendable {
    let errorText: String?

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let name = try container.decode(String.self)
        let details = try? container.decode(ComfyErrorDetailsDTO.self)
        errorText = name == "execution_error" ? details?.exceptionMessage : nil
    }
}

/// The details of a failed run.
struct ComfyErrorDetailsDTO: Decodable, Sendable {
    let exceptionMessage: String?

    enum CodingKeys: String, CodingKey {
        case exceptionMessage = "exception_message"
    }
}

/// What the server is running and what waits behind it. Each job is a list that begins with its place and its name.
struct ComfyQueueDTO: Decodable, Sendable {
    let runningIDs: [String]
    /// The waiting jobs, soonest first.
    let pendingIDs: [String]

    enum CodingKeys: String, CodingKey {
        case running = "queue_running"
        case pending = "queue_pending"
    }

    init(runningIDs: [String], pendingIDs: [String]) {
        self.runningIDs = runningIDs
        self.pendingIDs = pendingIDs
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runningIDs = try container.decode([ComfyQueueItemDTO].self, forKey: .running).map(\.promptID)
        pendingIDs = try container.decode([ComfyQueueItemDTO].self, forKey: .pending)
            .sorted { $0.number < $1.number }
            .map(\.promptID)
    }

    var isEmpty: Bool { runningIDs.isEmpty && pendingIDs.isEmpty }

    /// How many jobs come before the named one, the one running included; `nil` if it is not waiting.
    func jobsAhead(of promptID: String) -> Int? {
        pendingIDs.firstIndex(of: promptID).map { $0 + runningIDs.count }
    }
}

/// One job in the queue: its place, then its name, then details that are not needed here.
struct ComfyQueueItemDTO: Decodable, Sendable {
    let number: Double
    let promptID: String

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        number = try container.decode(Double.self)
        promptID = try container.decode(String.self)
    }
}
