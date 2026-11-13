import Foundation
import HearthDomain
import UIKit

// Making, changing and enlarging pictures. The picture server does this work; the chat model takes no part.
extension ChatPresenter {
    /// How much a finished picture is compressed for keeping. Enlarged pictures are big, and this keeps them sharp.
    private static let pictureQuality: CGFloat = 0.9

    /// Turns picture mode on or off. While it is on, what is sent asks for a picture, and the menu at the top
    /// offers the picture models in place of the chat models.
    func togglePictureModeAction() {
        viewModel.isPictureMode.toggle()
        guard viewModel.isPictureMode else {
            return
        }
        // Asking what the server offers also wakes it, so the first picture comes sooner.
        Task {
            do {
                viewModel.pictureModels = try await dependencies.image.capabilities(settings: settings).models
            } catch {
                logger.error("Listing the picture models failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// The model new pictures are made with: the one chosen if the server has it, otherwise the first it offers.
    var selectedPictureModel: ImageModelKind? {
        settings.imageModel.flatMap { viewModel.pictureModels.contains($0) ? $0 : nil } ?? viewModel.pictureModels.first
    }

    /// Chooses the model new pictures are made with, and remembers it.
    func selectPictureModelAction(_ model: ImageModelKind) {
        do {
            try dependencies.settingsStore.update(settings.choosing(imageModel: model))
        } catch {
            logger.error("Remembering the picture model failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Adds the user's message and answers it with a picture: a new one from its words, or its photo changed or enlarged.
    func submitPicture(_ message: Message) async {
        await stopDictation()
        await stopSpeaking()
        // Words that carry on from the last picture, like "make it photorealistic", change that picture.
        let previousPicture = viewModel.conversation.messages.last(where: \.isPicture)?.imagesJPEG.first
        let request = ImageRequestPlanner().request(text: message.text, imagesJPEG: message.imagesJPEG, previousPictureJPEG: previousPicture)
        let reply = Message(role: .assistant, text: "")
        let conversation = viewModel.conversation
        // A chat that begins with a photo and no words is still given a name.
        let title = conversation.messages.isEmpty ? (message.text.isEmpty ? Strings.picture : String(message.text.prefix(48))) : nil
        viewModel.conversation = conversation.updating(title: title, messages: conversation.messages + [message, reply], updatedAt: Date())
        viewModel.error = nil
        viewModel.followUps = []
        viewModel.memoryNotice = nil
        viewModel.isStreaming = true
        viewModel.pictureStatus = Self.status(for: request)
        backgroundActivity.begin(named: "Picture")
        let task = Task {
            await self.makePicture(request, replyID: reply.id)
            self.viewModel.isStreaming = false
            self.viewModel.pictureStatus = nil
            await self.save(self.discardingEmptyReply(reply.id))
        }
        turnTask = task
        await task.value
        backgroundActivity.end()
    }

    /// Has the picture made and puts it into the reply, with a line saying how it was made and how long it took.
    private func makePicture(_ request: ImageRequest, replyID: Message.ID) async {
        let startedAt = Date()
        do {
            let png = try await dependencies.image.make(request, settings: settings)
            guard let jpeg = UIImage(data: png)?.jpegData(compressionQuality: Self.pictureQuality) else {
                throw ImageError.failed(message: "")
            }
            let seconds = max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
            guard let reply = viewModel.conversation.messages.first(where: { $0.id == replyID }) else {
                return
            }
            let finished = Message(
                id: reply.id,
                role: .assistant,
                text: Self.caption(for: request, seconds: seconds),
                imagesJPEG: [jpeg],
                createdAt: reply.createdAt
            )
            viewModel.conversation = viewModel.conversation.replacing(finished)
        } catch is CancellationError {
            // Stopped by the user; the empty reply is removed by the caller.
        } catch {
            logger.error("Making a picture failed: \(error.localizedDescription, privacy: .public)")
            viewModel.error = ErrorViewConfiguration(from: error)
        }
    }

    private static func status(for request: ImageRequest) -> String {
        switch request {
        case .create:
            Strings.pictureCreating
        case .edit:
            Strings.pictureChanging
        case .enlarge:
            Strings.pictureEnlarging
        }
    }

    private static func caption(for request: ImageRequest, seconds: Int) -> String {
        switch request {
        case .create:
            Strings.pictureCreated(seconds: seconds)
        case .edit:
            Strings.pictureChanged(seconds: seconds)
        case .enlarge:
            Strings.pictureEnlarged(seconds: seconds)
        }
    }
}

extension Message {
    /// Whether this is a reply that carries a picture the app made.
    var isPicture: Bool {
        role == .assistant && !imagesJPEG.isEmpty
    }
}
