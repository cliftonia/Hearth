import Foundation
@testable import HearthData
import Testing

/// How the picture server's queue is read: what is running, what waits, and how far back a job stands.
struct ComfyQueueTests {
    /// A queue as ComfyUI reports it: each job is a list of its place, its name, and details the app ignores.
    private let json = Data("""
    {
      "queue_running": [[4, "video", {"1": {"class_type": "KSampler"}}, {}, ["9"]]],
      "queue_pending": [[6, "second", {}, {}, []], [5, "first", {}, {}, []]]
    }
    """.utf8)

    @Test func `the queue is read with the waiting jobs soonest first`() throws {
        let queue = try JSONDecoder().decode(ComfyQueueDTO.self, from: json)

        #expect(queue.runningIDs == ["video"])
        #expect(queue.pendingIDs == ["first", "second"])
        #expect(!queue.isEmpty)
    }

    @Test func `a waiting job counts the one running and those before it`() throws {
        let queue = try JSONDecoder().decode(ComfyQueueDTO.self, from: json)

        #expect(queue.jobsAhead(of: "first") == 1)
        #expect(queue.jobsAhead(of: "second") == 2)
        // The job that is running, and one the server no longer holds, are not waiting.
        #expect(queue.jobsAhead(of: "video") == nil)
        #expect(queue.jobsAhead(of: "gone") == nil)
    }

    @Test func `an idle server has an empty queue`() throws {
        let queue = try JSONDecoder().decode(ComfyQueueDTO.self, from: Data(#"{"queue_running": [], "queue_pending": []}"#.utf8))

        #expect(queue.isEmpty)
    }
}
