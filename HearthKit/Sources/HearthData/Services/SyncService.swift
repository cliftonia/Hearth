import Foundation

/// Talks to a Hearth Hub: whether it answers, what has changed on it, and storing one item.
///
/// The access token, when there is one, goes only into the `Authorization` header; nothing here logs a request.
public struct SyncService: Sendable {
    private let session: URLSession

    public init(session: URLSession = .hearthSync) {
        self.session = session
    }

    /// `GET /health`, which needs no token.
    public func health(baseURL: URL) async throws -> SyncHealthDTO {
        var request = URLRequest(url: baseURL.appending(path: "health"))
        request.timeoutInterval = 15
        return try WireTime.decoder().decode(SyncHealthDTO.self, from: try await session.validatedData(for: request))
    }

    /// One page of `GET /v1/changes`, from the given cursor.
    public func changes(baseURL: URL, token: String?, since: Int, limit: Int) async throws -> SyncChangesDTO {
        let url = baseURL.appending(path: "v1/changes").appending(queryItems: [
            URLQueryItem(name: "since", value: String(since)),
            URLQueryItem(name: "limit", value: String(limit))
        ])
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        authorise(&request, token: token)
        return try WireTime.decoder().decode(SyncChangesDTO.self, from: try await session.validatedData(for: request))
    }

    /// `PUT /v1/items/<kind>/<id>`. A body over the hub's limit is not sent at all.
    public func put(baseURL: URL, token: String?, kind: String, id: String, change: SyncPutDTO) async throws -> SyncPutResultDTO {
        let body = try WireTime.encoder().encode(change)
        guard body.count <= SyncWire.maximumItemBytes else {
            return .tooLarge
        }
        var request = URLRequest(url: baseURL.appending(path: "v1/items/\(kind)/\(id)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 120
        authorise(&request, token: token)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            return .accepted(try WireTime.decoder().decode(SyncPutAnswerDTO.self, from: data).item)
        case 409:
            return .conflict(try WireTime.decoder().decode(SyncPutAnswerDTO.self, from: data).item)
        case 413:
            return .tooLarge
        default:
            throw HTTPError.failedStatus(http.statusCode, body: data)
        }
    }

    private func authorise(_ request: inout URLRequest, token: String?) {
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}

extension URLSession {
    /// A session for the hub: requests that give up within two minutes, and no cookies or cache, since nothing it
    /// fetches is worth keeping.
    public static let hearthSync: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 600
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()
}
