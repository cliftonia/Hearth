import SwiftUI

// What the keyboard shortcuts and the Mac's menu bar ask for. Each one goes through the same presenter action as
// the button that does the same thing, and none acts while the app is locked or while a sheet is over the chat.
extension AppCoordinator {
    /// Whether a command for the chat may act: the app is unlocked and nothing is presented over the chat. Settings
    /// in a window of their own leave the chat free.
    var acceptsChatCommands: Bool {
        !lockPresenter.viewModel.isLocked
            && (router.usesSettingsWindow || !router.isSettingsPresented)
            && router.projectSheet == nil
            && router.taskSheet == nil
            && !router.isVoicePresented
    }

    /// Whether the chat list is showing: beside the chat on a wide screen, as the drawer on a narrow one.
    var isChatListShown: Bool {
        router.isWide ? router.isSidebarPinned : router.isSidebarOpen
    }

    /// Whether the open chat can be deleted from the keyboard: it has begun, and nothing is over it.
    var canDeleteChatCommand: Bool {
        acceptsChatCommands && chatPresenter.canDeleteChat
    }

    /// Starts a fresh chat, as the New chat button does.
    func newChatCommand() {
        guard acceptsChatCommands else {
            return
        }
        router.isSidebarOpen = false
        Task { await chatPresenter.newChatAction() }
    }

    /// Opens the settings, or brings their window forward if it is already open.
    func settingsCommand() {
        guard acceptsChatCommands else {
            return
        }
        router.isSidebarOpen = false
        if router.usesSettingsWindow, router.isSettingsWindowShown {
            SettingsWindow.bringToFront()
        }
        router.isSettingsPresented = true
    }

    /// Shows the chat list if it is put away, and puts the cursor in its search field.
    func searchChatsCommand() {
        guard acceptsChatCommands else {
            return
        }
        if !isChatListShown {
            toggleChatListCommand()
        }
        sidebarPresenter.focusSearchAction()
    }

    /// Shows the chat list or puts it away, as the button at the top of the chat does.
    func toggleChatListCommand() {
        guard acceptsChatCommands else {
            return
        }
        if router.isWide {
            chatPresenterDidRequestSidebar(chatPresenter)
        } else {
            router.isSidebarOpen.toggle()
        }
    }

    /// Asks whether to delete the open chat, through the same confirmation as its menu.
    func deleteChatCommand() {
        guard canDeleteChatCommand else {
            return
        }
        router.isSidebarOpen = false
        chatPresenter.requestDeleteChatAction()
    }
}

/// The app's commands, for the Mac's menu bar and for a hardware keyboard on an iPad, which lists them when Command
/// is held down. Settings, New Chat and the chat list follow the system's own places and keys for them.
public struct HearthCommands: Commands {
    private let coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(Strings.commandSettings, action: coordinator.settingsCommand)
                .keyboardShortcut(",", modifiers: .command)
                .disabled(!coordinator.acceptsChatCommands)
        }
        CommandGroup(replacing: .newItem) {
            Button(Strings.commandNewChat, action: coordinator.newChatCommand)
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!coordinator.acceptsChatCommands)
        }
        // In place of the system's Find, which looks inside text views this app does not have.
        CommandGroup(replacing: .textEditing) {
            Button(Strings.commandSearchChats, action: coordinator.searchChatsCommand)
                .keyboardShortcut("f", modifiers: .command)
                .disabled(!coordinator.acceptsChatCommands)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button(Strings.commandDeleteChat, action: coordinator.deleteChatCommand)
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!coordinator.canDeleteChatCommand)
        }
        CommandGroup(replacing: .sidebar) {
            Button(coordinator.isChatListShown ? Strings.commandHideChatList : Strings.commandShowChatList, action: coordinator.toggleChatListCommand)
                .keyboardShortcut("s", modifiers: [.command, .control])
                .disabled(!coordinator.acceptsChatCommands)
        }
    }
}
