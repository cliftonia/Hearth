import HearthDomain
import SwiftUI

// How the coordinator answers each presenter's requests: by changing the `AppRouter`, or by asking another
// presenter to act. Projects, the canvas and scheduled tasks answer in their own extensions.

// MARK: - ChatPresenterDelegate

extension AppCoordinator: ChatPresenterDelegate {
    func chatPresenterDidRequestNewProject(_ presenter: ChatPresenter) {
        projectPresenter.begin()
        router.projectSheet = .editor
    }

    /// A narrow screen opens the drawer; a wide one shows the chats beside the chat or puts them away.
    func chatPresenterDidRequestSidebar(_ presenter: ChatPresenter) {
        if router.isWide {
            guard !closeCanvasForSidebar() else {
                return
            }
            router.isSidebarPinned.toggle()
        } else {
            router.isSidebarOpen = true
        }
    }

    func chatPresenterDidRequestVoice(_ presenter: ChatPresenter) {
        router.isVoicePresented = true
    }

    func chatPresenterDidRequestSettings(_ presenter: ChatPresenter) {
        router.isSettingsPresented = true
    }

    func chatPresenter(_ presenter: ChatPresenter, didRequestProjectFor id: Conversation.ID) {
        presentProjectPicker(for: id)
    }

    func chatPresenter(_ presenter: ChatPresenter, didRequestCanvasFor reference: CanvasReference) {
        openCanvas(reference)
    }

    func chatPresenter(_ presenter: ChatPresenter, didRequestTaskWith prompt: String) {
        presentTaskSheet(prompt: prompt)
    }
}

// MARK: - SidebarPresenterDelegate

extension AppCoordinator: SidebarPresenterDelegate {
    func sidebarPresenter(_ presenter: SidebarPresenter, didSelect id: Conversation.ID) {
        router.isSidebarOpen = false
        Task { await chatPresenter.selectConversationAction(id) }
    }

    /// Deleting the open chat leaves nothing to show, so a new one takes its place.
    func sidebarPresenter(_ presenter: SidebarPresenter, didDelete id: Conversation.ID) {
        guard chatPresenter.viewModel.conversation.id == id else {
            return
        }
        Task { await chatPresenter.newChatAction() }
    }

    func sidebarPresenter(_ presenter: SidebarPresenter, didRename id: Conversation.ID, to title: String) {
        chatPresenter.conversationWasRenamed(id, to: title)
    }

    func sidebarPresenter(_ presenter: SidebarPresenter, didRequestNewChatIn projectID: Project.ID?) {
        router.isSidebarOpen = false
        Task { await chatPresenter.newChatAction(in: projectID) }
    }

    func sidebarPresenter(_ presenter: SidebarPresenter, didRequestEditing projectID: Project.ID) {
        projectPresenter.begin(editing: projectID)
        router.projectSheet = .editor
    }

    func sidebarPresenter(_ presenter: SidebarPresenter, didRequestProjectFor id: Conversation.ID) {
        presentProjectPicker(for: id)
    }

    func sidebarPresenterDidRequestSettings(_ presenter: SidebarPresenter) {
        router.isSettingsPresented = true
    }
}

// MARK: - SettingsPresenterDelegate

extension AppCoordinator: SettingsPresenterDelegate {
    func settingsPresenterDidFinish(_ presenter: SettingsPresenter) {
        router.isSettingsPresented = false
    }

    /// Another chat server may offer other models, so they are fetched afresh.
    func settingsPresenterDidChangeChatServer(_ presenter: SettingsPresenter) {
        Task { await chatPresenter.refreshModelsAction() }
    }

    /// With everything erased the app goes back to how it first opened: no sheet, every chat list choice
    /// forgotten, an empty chat, and the models of the server it was built to start with.
    func settingsPresenterDidErase(_ presenter: SettingsPresenter) {
        router.isSettingsPresented = false
        router.isSidebarOpen = false
        router.isSidebarPinned = true
        router.forgetSidebarFolds()
        sidebarPresenter.reset()
        Task { await chatPresenter.resetAction() }
    }
}

// MARK: - VoicePresenterDelegate

extension AppCoordinator: VoicePresenterDelegate {
    func voicePresenterDidFinish(_ presenter: VoicePresenter) {
        router.isVoicePresented = false
    }
}

// MARK: - LockPresenterDelegate

extension AppCoordinator: LockPresenterDelegate {
    /// A locked app shows nothing, says nothing and listens to nothing: sheets close and voice and speech stop.
    func lockPresenterDidLock(_ presenter: LockPresenter) {
        let wasInVoice = router.isVoicePresented
        router.isSettingsPresented = false
        router.projectSheet = nil
        router.taskSheet = nil
        router.isVoicePresented = false
        router.isSidebarOpen = false
        router.isCanvasOpen = false
        sidebarPresenter.cancelRenaming()
        Task {
            if wasInVoice {
                await voicePresenter.endAction()
            }
            await chatPresenter.stopSpeaking()
            await chatPresenter.stopDictation()
        }
    }

    /// Begins the voice conversation that was asked for while the app was locked, if there was one.
    func lockPresenterDidUnlock(_ presenter: LockPresenter) {
        if isVoicePending {
            isVoicePending = false
            startVoice()
        }
    }
}
