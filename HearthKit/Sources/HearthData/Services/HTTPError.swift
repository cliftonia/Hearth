import Foundation

public enum HTTPError: Error, Sendable, Equatable {
    case invalidResponse
    case status(code: Int, body: String)
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

    func decoded<Value: Decodable>(_ type: Value.Type, for request: URLRequest) async throws -> Value {
        try JSONDecoder().decode(type, from: try await validatedData(for: request))
    }
}

extension URLRequest {
    static func jsonPost(url: URL, body: some Encodable) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
