import Foundation
import HearthDomain

// Deep research: switching it on, running it, and keeping the report it writes.
extension ChatPresenter {
    // MARK: Choosing

    /// Whether what is sent next is researched. Research needs a search server, and gives way to picture mode.
    var isResearchChosen: Bool {
        viewModel.isResearchMode && isSearchAvailable && !viewModel.isPictureMode
    }

    /// What the next message will be given: research, or thought at the level saved in the settings.
    var effortChoice: EffortChoiceKind {
        isResearchChosen ? .research : .thinking(thinkingLevel)
    }

    /// The choices the effort menu offers for the chosen model.
    var effortChoices: [EffortChoiceKind] {
        EffortChoiceKind.choices(canThink: viewModel.selectedModel?.canThink == true, savedLevel: thinkingLevel)
    }

    /// The effort as the composer's model chip names it: research always, a thinking level only for a model that thinks.
    var effortChipTitle: String {
        let canThink = viewModel.selectedModel?.canThink == true
        switch effortChoice {
        case .thinking:
            return canThink ? effortChoice.title(canThink: canThink) : ""
        case .research:
            return effortChoice.title(canThink: canThink)
        }
    }

    /// Chooses how hard the model thinks, for every chat. Research, if it is switched on, stays on: its report is
    /// thought about at the level chosen here.
    func selectEffortAction(_ choice: EffortChoiceKind) {
        switch choice {
        case .thinking(let level):
            if level != thinkingLevel {
                selectThinkingLevelAction(level)
            }
        case .research:
            setResearch(true)
        }
    }

    /// Switches research on or off for this chat. It needs a search address, and takes the place of picture mode.
    func toggleResearchAction() {
        setResearch(!isResearchChosen)
    }

    private func setResearch(_ isOn: Bool) {
        viewModel.isResearchMode = isOn && isSearchAvailable
        // A message asks for a picture or for research, never both.
        if viewModel.isResearchMode {
            viewModel.isPictureMode = false
        }
    }

    // MARK: Running

    /// Adds the user's question and answers it with a researched report.
    func submitResearch(_ message: Message) async {
        guard let model = viewModel.selectedModel else {
            showError(ErrorViewConfiguration(from: ChatError.noModelSelected))
            return
        }
        await stopDictation()
        let conversation = viewModel.conversation
        let isFirstMessage = conversation.messages.isEmpty
        viewModel.conversation = conversation.updating(
            title: isFirstMessage ? Conversation.provisionalTitle(from: message.text) : nil,
            modelID: model.id,
            messages: conversation.messages + [message]
        )
        await research(model: model)
        if isFirstMessage {
            await nameConversation(conversation.id, from: message.text, model: model)
        }
    }

    /// Researches the last message of the conversation and fills a new reply with the report. Returns once the
    /// run is over, whether it finished, failed or was stopped, with what there is saved.
    ///
    /// - Parameter previous: The report this one is another attempt at, whose versions it keeps behind it.
    func research(model: ChatModel, replacing previous: Message? = nil) async {
        let history = viewModel.conversation.messages
        guard let asked = history.last, asked.role == .user else {
            return
        }
        let reply = previous?.startingNewVersion() ?? Message(role: .assistant, text: "", isResearch: true)
        let request = ResearchInteractor.Request(question: asked.text, context: Array(history.dropLast()), model: model, settings: settings)
        viewModel.conversation = viewModel.conversation.updating(messages: history + [reply], updatedAt: Date())
        beginTurn()
        viewModel.researchStatus = Self.status(for: .planning)
        let events = dependencies.research.run(request)
        // Research takes minutes; it should outlive a glance at another app, for as long as iOS allows.
        backgroundActivity.begin(named: "Research")
        await stopSpeaking()
        await runTurn(replyID: reply.id) {
            await self.consume(events, reportID: reply.id)
        } settle: {
            self.viewModel.researchStatus = nil
        }
        await suggestFollowUps(model: model)
    }

    /// Applies each event of the run to the report, and turns a failure into an error the user can read.
    private func consume(_ events: AsyncThrowingStream<ResearchInteractor.Event, any Error>, reportID: Message.ID) async {
        let startedAt = Date()
        var isFinished = false
        do {
            for try await event in events {
                apply(event, to: reportID, startedAt: startedAt)
                if case .finished = event {
                    isFinished = true
                }
            }
        } catch is CancellationError {
            // Stopped by the user; what has been written so far is kept.
        } catch {
            logger.error("Research failed: \(error.localizedDescription, privacy: .public)")
            // A connection lost while the app was off screen is iOS suspending it, not the server or the VPN.
            showError(backgroundActivity.wasBackgrounded
                ? ErrorViewConfiguration(title: Strings.interruptedTitle, message: Strings.interruptedMessage)
                : ErrorViewConfiguration(from: error))
        }
        if !isFinished {
            tidyUnfinishedReport(reportID)
        }
    }

    /// Folds one event into the report or into the view model's passing state.
    private func apply(_ event: ResearchInteractor.Event, to reportID: Message.ID, startedAt: Date) {
        guard let message = viewModel.conversation.messages.first(where: { $0.id == reportID }) else {
            return
        }
        let updated: Message
        switch event {
        case .step(let step):
            viewModel.researchStatus = Self.status(for: step)
            return
        case .sources(let sources):
            updated = message.updating(sources: sources)
        case .thinking(let delta):
            updated = message.updating(thinking: message.thinking + delta)
        case .text(let delta):
            let isFirstText = message.text.isEmpty && !message.thinking.isEmpty
            updated = message.updating(
                text: message.text + delta,
                thinkingSeconds: isFirstText ? Int(Date().timeIntervalSince(startedAt).rounded()) : nil
            )
        case .finished(let report):
            updated = message.updating(text: report.text, sources: report.sources)
        }
        viewModel.conversation = viewModel.conversation.replacing(updated)
    }

    /// A report that was stopped or failed part of the way through is kept as far as it got, with its citations
    /// and its sources made to agree just as a finished one's are. One with no words yet keeps no sources either.
    private func tidyUnfinishedReport(_ reportID: Message.ID) {
        guard let message = viewModel.conversation.messages.first(where: { $0.id == reportID }) else {
            return
        }
        let report = ResearchCitationTransformer().tidy(message.text, sources: message.sources)
        let sources = report.text.isEmpty ? [] : report.sources
        viewModel.conversation = viewModel.conversation.replacing(message.updating(text: report.text, sources: sources))
    }

    /// The line shown under the report while it is on its way.
    static func status(for step: ResearchStepKind) -> String {
        switch step {
        case .planning:
            Strings.researchPlanning
        case .searching(let number, let total):
            Strings.researchSearching(number: number, total: total)
        case .reading(let number, let total):
            Strings.researchReading(number: number, total: total)
        case .takingNotes(let number, let total):
            Strings.researchTakingNotes(number: number, total: total)
        case .checking:
            Strings.researchChecking
        case .writing:
            Strings.researchWriting
        }
    }
}
