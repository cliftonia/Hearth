import Foundation

/// One piece of work for the picture server.
public enum ImageJobDTO: Sendable {
    /// A picture from words alone, at the given size in pixels.
    case create(engine: ImageEngineDTO, prompt: String, width: Int, height: Int)
    /// A picture changed as the instruction asks.
    case edit(image: Data, instruction: String)
    /// A picture made larger, up to the given number of megapixels.
    case enlarge(image: Data, megapixels: Double)
}

/// How a job stands while it is waited for.
public enum ImageProgressDTO: Sendable, Equatable {
    /// The server is busy with other work; this many jobs come first.
    case waiting(ahead: Int)
    /// The server is working on this job now.
    case working
}

/// What the picture server can do, judged by the files it holds.
public struct ImageServerFilesDTO: Sendable, Equatable {
    public let engines: [ImageEngineDTO]
    public let canEdit: Bool
    public let canEnlarge: Bool
}

/// Why a picture could not be made.
public enum ImageServiceError: Error, Sendable, Equatable {
    /// The server ran the work but it failed; the message is the server's own.
    case failed(message: String)
    /// The work finished without leaving a picture.
    case noPicture
    /// The server was still working when the wait ran out.
    case timedOut
}

/// Makes, changes and enlarges pictures through a ComfyUI server.
///
/// ComfyUI takes a graph of nodes, runs it in its queue, and keeps the result until it is fetched. The server starts
/// itself on the first request, which can take a minute, and is asked to free its memory when the work is done.
///
/// The queue is shared with whatever else uses the server, and one job runs at a time. So a job may wait its turn,
/// which is reported and not counted against it, and only ever cancels itself.
public struct ImageService: Sendable {
    /// How often the server is asked whether the work is done.
    private static let pollInterval: Duration = .seconds(1)
    /// The longest a picture is worked on once its turn has come, a cold start and a large model included.
    private static let patience: Duration = .seconds(420)
    /// The longest a picture waits for its turn behind other work.
    private static let waitingPatience: Duration = .seconds(1800)

    private let session: URLSession

    public init(session: URLSession = .hearth) {
        self.session = session
    }

    /// Which models and tools the server has.
    public func fetchFiles(baseURL: URL) async throws -> ImageServerFilesDTO {
        async let diffusion = fileNames(baseURL: baseURL, folder: "diffusion_models")
        async let checkpoints = fileNames(baseURL: baseURL, folder: "checkpoints")
        async let upscalers = fileNames(baseURL: baseURL, folder: "upscale_models")
        let (diffusionFiles, checkpointFiles, upscaleFiles) = try await (diffusion, checkpoints, upscalers)
        let engines = ImageEngineDTO.allCases.filter { engine in
            (engine.isCheckpoint ? checkpointFiles : diffusionFiles).contains(engine.modelFile)
        }
        return ImageServerFilesDTO(
            engines: engines,
            canEdit: diffusionFiles.contains(ImageToolFile.editModel),
            canEnlarge: upscaleFiles.contains(ImageToolFile.enlargeModel)
        )
    }

    /// Runs the job and returns the picture as PNG data. Cancelling the task takes this job, and only this job, off the server.
    ///
    /// - Parameter onProgress: Told whether the job is waiting its turn or being worked on, each time that is checked.
    public func render(
        baseURL: URL,
        job: ImageJobDTO,
        onProgress: @escaping @Sendable (ImageProgressDTO) -> Void = { _ in }
    ) async throws -> Data {
        let seed = Int.random(in: 0..<Int(Int32.max))
        let graph: ImageGraph.Nodes
        switch job {
        case .create(let engine, let prompt, let width, let height):
            graph = ImageGraph.create(engine: engine, prompt: prompt, width: width, height: height, seed: seed)
        case .edit(let image, let instruction):
            graph = ImageGraph.edit(imageName: try await upload(image, baseURL: baseURL), instruction: instruction, seed: seed)
        case .enlarge(let image, let megapixels):
            graph = ImageGraph.enlarge(imageName: try await upload(image, baseURL: baseURL), megapixels: megapixels)
        }
        let promptID = try await queue(graph, baseURL: baseURL)
        do {
            let picture = try await waitForPicture(promptID: promptID, baseURL: baseURL, onProgress: onProgress)
            return try await session.validatedData(for: URLRequest(url: viewURL(for: picture, baseURL: baseURL)))
        } catch is CancellationError {
            await cancelDetached(promptID: promptID, baseURL: baseURL)
            throw CancellationError()
        }
    }

    /// Asks the server to unload its models and give back its memory, unless other work is waiting for them.
    /// Failing to is not worth reporting.
    public func free(baseURL: URL) async {
        // With work in the queue the models are about to be used; whoever goes last frees them.
        if let queue = try? await queueState(baseURL: baseURL), !queue.isEmpty {
            return
        }
        let body: [String: Bool] = ["unload_models": true, "free_memory": true]
        if let request = try? URLRequest.jsonPost(url: baseURL.appending(path: "free"), body: body) {
            _ = try? await session.validatedData(for: request)
        }
    }
}

private extension ImageService {
    func fileNames(baseURL: URL, folder: String) async throws -> Set<String> {
        var request = URLRequest(url: baseURL.appending(path: "models/\(folder)"))
        // The first request wakes the server, which takes longer than an ordinary answer.
        request.timeoutInterval = 90
        return Set(try await session.decoded([String].self, for: request))
    }

    func queue(_ graph: ImageGraph.Nodes, baseURL: URL) async throws -> String {
        var request = URLRequest(url: baseURL.appending(path: "prompt"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["prompt": graph])
        request.timeoutInterval = 90
        return try await session.decoded(ComfyQueueAnswerDTO.self, for: request).promptID
    }

    /// Sends a picture for a graph to load, and returns the name the server gave it.
    func upload(_ image: Data, baseURL: URL) async throws -> String {
        let boundary = "hearth-\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"hearth-\(UUID().uuidString).jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(image)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = URLRequest(url: baseURL.appending(path: "upload/image"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 120
        return try await session.decoded(ComfyUploadAnswerDTO.self, for: request).name
    }

    /// Asks after the run until it has finished, failed, or taken too long. Time spent waiting behind other work
    /// is allowed for separately, so a picture queued behind a long job does not give up before its turn.
    func waitForPicture(
        promptID: String,
        baseURL: URL,
        onProgress: @Sendable (ImageProgressDTO) -> Void
    ) async throws -> ComfyPictureDTO {
        let queuedAt = ContinuousClock.now
        var startedAt: ContinuousClock.Instant?
        while true {
            try await Task.sleep(for: Self.pollInterval)
            let request = URLRequest(url: baseURL.appending(path: "history/\(promptID)"))
            if let history = try await session.decoded([String: ComfyHistoryDTO].self, for: request)[promptID] {
                if let picture = history.outputs?.values.compactMap(\.images).flatMap({ $0 }).first {
                    return picture
                }
                if let message = history.status?.messages?.compactMap(\.errorText).first {
                    throw ImageServiceError.failed(message: message.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                throw ImageServiceError.noPicture
            }
            if let queue = try? await queueState(baseURL: baseURL) {
                if queue.runningIDs.contains(promptID) {
                    startedAt = startedAt ?? ContinuousClock.now
                    onProgress(.working)
                } else if let ahead = queue.jobsAhead(of: promptID) {
                    onProgress(.waiting(ahead: ahead))
                }
            }
            let isOverdue = startedAt.map { ContinuousClock.now - $0 > Self.patience } ?? (ContinuousClock.now - queuedAt > Self.waitingPatience)
            if isOverdue {
                await cancelDetached(promptID: promptID, baseURL: baseURL)
                throw ImageServiceError.timedOut
            }
        }
    }

    /// What the server is running and what is waiting behind it.
    func queueState(baseURL: URL) async throws -> ComfyQueueDTO {
        var request = URLRequest(url: baseURL.appending(path: "queue"))
        request.timeoutInterval = 15
        return try await session.decoded(ComfyQueueDTO.self, for: request)
    }

    func viewURL(for picture: ComfyPictureDTO, baseURL: URL) -> URL {
        baseURL.appending(path: "view").appending(queryItems: [
            URLQueryItem(name: "filename", value: picture.filename),
            URLQueryItem(name: "subfolder", value: picture.subfolder),
            URLQueryItem(name: "type", value: picture.type)
        ])
    }

    /// Cancels from a task of its own. A cancelled task cannot make requests, and cancelling is exactly when this is
    /// called, so the requests would otherwise never be sent and the job would stay on the server.
    func cancelDetached(promptID: String, baseURL: URL) async {
        await Task.detached { await cancel(promptID: promptID, baseURL: baseURL) }.value
    }

    /// Takes one job off the server: out of the queue if it is still waiting, and stopped if it is the one running.
    /// Work that belongs to anyone else is left alone.
    func cancel(promptID: String, baseURL: URL) async {
        if let remove = try? URLRequest.jsonPost(url: baseURL.appending(path: "queue"), body: ["delete": [promptID]]) {
            _ = try? await session.validatedData(for: remove)
        }
        // Naming the job makes the server stop only if that job is the one running.
        if let stop = try? URLRequest.jsonPost(url: baseURL.appending(path: "interrupt"), body: ["prompt_id": promptID]) {
            _ = try? await session.validatedData(for: stop)
        }
    }
}
