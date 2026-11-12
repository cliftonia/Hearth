import Foundation

/// What can go wrong when talking to one of the user's servers.
public enum HTTPError: Error, Sendable, Equatable {
    /// What came back was not a usable HTTP response.
    case invalidResponse
    /// The server answered with a failure status; the body is the start of what it sent.
    case status(code: Int, body: String)
    /// The server answered with an error message of its own in place of a reply.
    case server(message: String)
}

extension URLSession {
    /// A session with timeouts long enough for a model that must first be loaded into memory.
    public static let hearth: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 1800
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    /// The body of the response. Fails unless the status is in the 200s, keeping the start of the body as a clue.
    func validatedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPError.status(code: http.statusCode, body: String(bytes: data.prefix(500), encoding: .utf8) ?? "")
        }
        return data
    }

    /// The response decoded from JSON, after the same check of its status.
    func decoded<Value: Decodable>(_ type: Value.Type, for request: URLRequest) async throws -> Value {
        try JSONDecoder().decode(type, from: try await validatedData(for: request))
    }
}

extension URLRequest {
    /// A POST request carrying the body as JSON.
    static func jsonPost(url: URL, body: some Encodable) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
