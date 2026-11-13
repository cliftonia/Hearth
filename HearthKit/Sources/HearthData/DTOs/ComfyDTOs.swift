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
