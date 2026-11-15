import Foundation

/// How far a press on the resting composer has got towards being a recording.
enum HoldToTalkPhaseKind: Hashable, Sendable {
    /// Nothing is held.
    case idle
    /// A finger is down, and leave to listen is being asked or the recogniser is starting.
    case starting
    /// The recogniser is listening.
    case recording
}

/// Talking to the composer by holding it down: what has been pressed, heard and let go.
///
/// It only keeps the account; the presenter does the listening. Keeping the account apart is what makes the
/// awkward orders of events safe: a finger that lifts while leave is still being asked marks the press as no
/// longer wanted, so the recogniser is never left running with nobody holding on.
struct HoldToTalk: Hashable, Sendable {
    private(set) var phase = HoldToTalkPhaseKind.idle
    /// Whether the finger has gone, or dictation was stopped from somewhere else, since the press began.
    private(set) var isStopRequested = false
    /// Everything heard since the recording began.
    private(set) var transcript = ""

    /// Whether the recording row is showing in place of the composer.
    var isActive: Bool {
        phase != .idle
    }

    /// Whether a press that is still starting should go on to listen. Asked again after every wait.
    var isStillWanted: Bool {
        phase == .starting && !isStopRequested
    }

    /// A finger has rested on the composer. Returns whether to start listening.
    ///
    /// - Parameters:
    ///   - isDraftEmpty: Holding is for a composer with nothing written in it.
    ///   - isDictating: The microphone button's dictation is not to be fought with.
    mutating func press(isDraftEmpty: Bool, isDictating: Bool) -> Bool {
        guard phase == .idle, isDraftEmpty, !isDictating else {
            return false
        }
        phase = .starting
        isStopRequested = false
        transcript = ""
        return true
    }

    /// The recogniser is ready. Returns whether to go on and record; false when the finger has already gone,
    /// in which case the caller stops the recogniser again.
    mutating func begin() -> Bool {
        guard isStillWanted else {
            return false
        }
        phase = .recording
        return true
    }

    /// Takes in everything heard so far. Words that arrive when nothing is being recorded are dropped.
    mutating func hear(_ text: String) {
        guard phase == .recording else {
            return
        }
        transcript = text
    }

    /// The finger lifted or slid away, or dictation was stopped from elsewhere.
    /// Returns whether there is a recording to stop.
    @discardableResult
    mutating func release() -> Bool {
        switch phase {
        case .idle:
            return false
        case .starting:
            isStopRequested = true
            return false
        case .recording:
            isStopRequested = true
            return true
        }
    }

    /// Ends the press, however far it got, and returns the words to put in the draft, or `nil` if nothing was heard.
    @discardableResult
    mutating func finish() -> String? {
        let words = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        self = HoldToTalk()
        return words.isEmpty ? nil : words
    }
}
