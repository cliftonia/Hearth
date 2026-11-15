# Architecture

Hearth is a thin app target around a local Swift package, `HearthKit`. The package is split into four
modules, and each may import only the ones beneath it.

```
App/            The @main entry point and the App Intent. Builds one AppCoordinator and shows its root view.

HearthUI        Coordinator, Presenters, ViewModels, SwiftUI views, design system   @MainActor
   │
HearthDomain    Models, Interactors, Stores, DataProviders, Transformers             Sendable
   │
HearthData      Services and DTOs: Ollama, SearXNG, Kokoro, files, audio, speech, notifications   Sendable
   │
HearthCore      Tagged identifiers, logging
```

CI enforces the direction (`.github/workflows/ci.yml`, "Layers only import downwards"):

- Domain, Data and Core never import SwiftUI, UIKit or HearthUI.
- Data and Core never import HearthDomain.
- HearthUI never imports HearthData. It reaches the data layer only through the domain.

## The roles

The pattern is MVVMP+C: Model, View, ViewModel, Presenter and Coordinator.

| Role | What it is here | Example |
|---|---|---|
| **Model** | An immutable, `Sendable` value type in the domain. Changed by making a copy (`updating(...)`). | `Conversation`, `Project`, `Message`, `ServerSettings` |
| **View** | A SwiftUI view that holds its Presenter, reads the ViewModel and calls `...Action` methods. No logic beyond layout. | `ChatView` |
| **ViewModel** | An `@Observable`, `@MainActor` class of plain state for one screen. No logic beyond small derived values. | `ChatViewModel` |
| **ViewConfiguration** | An immutable `Hashable` struct of display-ready values for one component. | `ErrorViewConfiguration`, `SidebarRowViewConfiguration` |
| **Presenter** | A `@MainActor` class that owns the ViewModel, handles the View's actions, catches errors, and asks the coordinator for navigation through a weak delegate. | `ChatPresenter` |
| **Coordinator** | `AppCoordinator`. Builds every Presenter, conforms to their delegate protocols in extensions, and changes the `AppRouter`. | `AppCoordinator` |
| **Store** | An `@Observable`, `@MainActor` class of state shared by more than one screen, with `private(set)` properties and methods that change them. | `SettingsStore`, `ConversationStore`, `ProjectStore`, `MemoryStore`, `ProfileStore`, `ModelStore` |
| **Interactor** | A concrete `Sendable` class that carries out a piece of business logic through the providers it is given. | `ChatInteractor`, `SpeechInteractor`, `ProjectInteractor`, `EraseInteractor` |
| **DataProvider** | A struct of `@Sendable` closures, a "protocol witness", with a `.live()` version that calls the services. Tests pass their own closures. | `ChatDataProvider`, `ProjectDataProvider`, `DictationProvider`, `NotificationProvider` |
| **Transformer** | Pure logic from one value to another, with no state beyond what it is fed. | `MarkdownTransformer`, `PromptBuilder`, `SentenceChunker`, `ReplyNotificationPlanner` |
| **Service / DTO** | The data layer: a service makes the request or touches the device, a DTO is the shape on the wire. | `OllamaService`, `OllamaChatRequestDTO` |

Rule of thumb for state: if two screens need it, it is a Store; if one screen needs it, it is that
screen's ViewModel; if it is only handed to a component to draw, it is a ViewConfiguration.

## How a screen is wired

```
            builds, sets delegate = self
AppCoordinator ───────────────────────────▶ Presenter ──owns──▶ ViewModel
      ▲                                      ▲    │                 │
      │  delegate call                       │    │ interactors,    │ observed
      │  (navigation)                action   │    ▼ stores          ▼
      └──────────────────────────────────────┴── View ◀─────────────┘
```

1. `HearthApp` builds `AppDependencies.live(defaults:)` and one `AppCoordinator`.
2. The coordinator's initialiser builds every Presenter, passing each only what it needs: stores,
   interactors and closures. One Presenter never holds another; where the voice screen needs the chat
   to run a turn, it is given a closure.
3. The coordinator sets itself as each Presenter's delegate. A Presenter that wants to go somewhere
   calls its delegate (`chatPresenterDidRequestSettings`), and the coordinator changes the `AppRouter`.
4. `RootView` reads the router and presents what it says: the sidebar beside the chat or in a drawer,
   Settings and the project sheets as sheets, the voice conversation as a full-screen cover, and the lock
   over everything.
5. A View takes its Presenter, reads `presenter.viewModel`, and turns each tap into
   `presenter.somethingAction()`, inside a `Task` when the action is `async`.

Errors follow the layers. The data layer throws what it gets, the domain gives the error a meaning
where one is needed (`ChatError`, `SpeechError`), and the Presenter catches it, logs it through
`os.Logger` and sets `viewModel.error` to an `ErrorViewConfiguration`. Only supplementary work, such as
suggesting follow-up questions or naming a chat, fails silently.

## Where things live

```
App/
  HearthApp.swift               The entry point; reads the starting addresses from Info.plist
  StartVoiceIntent.swift        "Start Voice Conversation" for Siri, Shortcuts and the Action button

HearthKit/Sources/HearthUI/
  AppCoordinator.swift          Builds and connects the screens (+Projects: where the project sheets lead)
  AppRouter.swift               What is presented besides the chat
  AppDependencies.swift         Everything the screens are built from, and its live version
  AppDefaults.swift             The addresses the app starts with
  Screens/
    Root/                       RootView, DrawerContainer
    Chat/                       ChatView, ChatPresenter (+Replying, +Editing, +FollowUps, +Notifications, +Voice), ChatViewModel
      Components/               The header, a message, the composer and the other sections of the chat
      Attachments/              The camera, and loading photos and files
    Sidebar/                    SidebarView (+Projects), SidebarPresenter (+Projects), SidebarViewModel, its configurations, ConversationGrouper
    Project/                    ProjectView, ProjectPresenter, ProjectViewModel: the sheet that makes or edits a project
    ProjectPicker/              ProjectPickerView, ProjectPickerPresenter, ProjectPickerViewModel: the sheet that files a chat
    Settings/                   SettingsView, SettingsPresenter (+Profile, +Notifications), SettingsViewModel, and its
                                sections and pushed pages: ProfileSection, MemorySection, NotificationsSection, SettingsCard
    Voice/                      VoiceView, VoicePresenter, VoiceViewModel, VoiceOrb
    Lock/                       LockView, LockPresenter, LockViewModel, LockWindowController
  Components/                   Views shared between screens that know about the domain: Markdown, the error configuration
  DesignSystem/
    Tokens/                     HearthColor, HearthFont, HearthSpacing, HearthRadius, HearthSize, HearthShadow
    Components/                 HearthMark, IconButton, OptionChip, Hairline, Avatar, Haptics and the surface modifiers
  Extensions/                   How domain values are named and shown: AppearanceKind, ThinkingLevelKind
  Localization/                 Every user-facing string: Strings.swift and its Strings+Topic.swift extensions
  Platform/                     Thin wrappers over UIKit: the keyboard, background time
  Resources/                    Localizable.xcstrings

HearthKit/Sources/HearthDomain/
  Models/  Interactors/  Stores/  DataProviders/  Transformers/

HearthKit/Sources/HearthData/
  Services/  DTOs/

HearthKit/Sources/HearthCore/
  Tagged.swift  Logger+Core.swift

HearthKit/Tests/
  HearthDataTests/  HearthDomainTests/  HearthUITests/
```

Every screen folder has the same three files, `XView.swift`, `XPresenter.swift` and `XViewModel.swift`,
with the screen's own sections and helpers beside them. A long Presenter is split by subject into
`XPresenter+Subject.swift` extensions.

## Projects

A `Project` gathers chats around one subject: a name, instructions, and reference files reduced to their text.
A `Conversation` points at its project through `projectID`; the project knows nothing of its chats.

- **Saved** by `ProjectStore` through `ProjectDataProvider`, one JSON file each in a `Projects` folder beside
  `Conversations`. A failed write is rolled back and rethrown, as in `ConversationStore`.
- **Where a chat belongs is the conversation store's to decide** once the chat has been saved
  (`ConversationStore.setProject`), exactly as its pin is, so a copy held open in the chat cannot undo a move
  made from the list. A chat not yet saved carries its project in the open copy until its first save.
  `Conversation.updating(project:)` takes a `ProjectMembership` (`.project(id)` or `.noProject`), because a `nil`
  argument there already means "keep".
- **Deleting a project keeps its chats.** `ProjectInteractor.delete` first takes every chat out of the project
  and only then deletes it, so no chat is left pointing at a project that is gone.
- **In the prompt**, `PromptBuilder` (`PromptBuilder+Project`) adds the project's name and instructions to the
  system message after the user's own standing instructions, then its files, each quoted between markers made
  up afresh for the turn and described as material, never instructions. The files share one allowance of
  60,000 characters, taken in order; the model is told which file was cut short and which were left out.
- **Memory** is read in a project's chats as in any other, and never in a private one. Because reference files
  are text the user did not type, a project that has any closes the memory tools for its chats, just as a file
  attached to a message does; a project with instructions alone leaves them open.
- **On screen**, `SidebarPresenter` lists the projects above the dated groups and narrows the list to one
  (`SidebarViewModel.selectedProjectID`); `ConversationGrouper` does the filtering and stays pure. The two
  sheets are presented from `AppRouter.projectSheet`, one value for both so that the picker can give way to the
  sheet that makes a project.

## Settings, the profile and erasing

Settings is one sheet with one Presenter. Its first page is a form; the profile and the notifications are pages
pushed from it, drawn as cards (`SettingsPage`, `SettingsCard`).

- **One draft.** `SettingsViewModel` holds a draft of every setting, filled as the sheet opens and written by
  Done; Cancel lets it go. The pushed pages take part in the same draft: the names and the instructions typed on
  the profile page are kept by Done like any field on the first page.
- **What takes effect at once**, because it is an act more than a setting or has to be felt to be judged: the
  theme, the memories, the profile photo, the haptics switch, the notification switches, and erasing everything.
  Each is written straight to its store, so Cancel does not undo it.
- **The profile.** The full name and the nickname are fields of `ServerSettings` (`UserProfile` gives the
  initials and the name to call the user by). The nickname took the place of the earlier `userName`, whose saved
  key is still read. The greeting prefers the nickname, then the first word of the full name, then a name found
  among the memories; `PromptBuilder` tells the model the name in one line, in private chats too, since it is a
  setting and not a memory. The photo is cut to a small square JPEG and kept by `ProfileStore` in a `Profile`
  folder beside `Conversations`.
- **Erasing.** There are no accounts, so the profile page offers to erase what the device holds.
  `EraseInteractor` asks each store in turn (`ConversationStore.deleteAll`, `ProjectStore.deleteAll`,
  `MemoryStore.clear`, `ProfileStore.removePhoto`) and last `SettingsStore.reset`, which removes the saved
  settings and goes back to the build-time defaults, as on first launch. The chat is quietened first so that
  nothing is written meanwhile, and a failure part of the way leaves the settings in place to try again.

## Hold to talk

Pressing and holding the resting composer dictates through the same flow as the microphone button
(`ChatPresenter+Voice`). `HoldToTalk` is the pure state of one press (idle, starting, recording), kept on
`ChatViewModel`; a release is recorded before anything is awaited and checked again after each step of starting,
so a finger lifted early can never leave the recorder running. The words are held until the press ends, then put
in the draft with the composer focused; nothing is sent. `DictationService` measures the level of the audio it
already taps (`VoiceLevelMeter`) and `DictationProvider.levels` carries it to the dots in `HoldToTalkRow`.

## Notifications

Local only (`UserNotifications`); nothing goes through a server. `NotificationService` in the data layer posts
them and reports taps, and the domain reaches it through `NotificationProvider`, a struct of closures.

- **When.** As a reply or a picture finishes, `ChatPresenter.notifyReplyFinished` asks `ReplyNotificationPlanner`,
  which says nothing unless the Replies switch is on and the app is not in front of the user at that moment
  (`AppRouter.isSceneActive`, kept current by `RootView`). A turn that failed or came to nothing is not announced.
- **What.** The chat's title and the start of the reply, or "Your picture is ready". A private chat's
  notification carries neither its title nor its words.
- **Permission** is asked for the first time the switch is turned on. If the system refuses, the switch stays
  on and the page says where to allow it.
- **A tap** opens the chat: the coordinator listens to `NotificationProvider.taps` for as long as the app runs.
- **A new kind of notification** gets a switch only once it does something. Its row goes in the card on
  `NotificationsPage`, where a comment marks the place.

## Conventions

- **Actions are named for intent**: `sendAction`, `saveAction`, never `didTapSendButton`.
- **`Kind`, not `Type`**, for enums of cases: `VoiceStateKind`, `AppearanceKind`.
- **Identifiers are `Tagged`**, so a conversation's identifier cannot be passed where a message's is wanted.
- **Protocol conformances go in extensions**: `extension AppCoordinator: ChatPresenterDelegate`.
- **Switches over our own enums list every case**, with no `default`, so a new case fails to compile until it is handled.
- **Concurrency is async/await throughout**, with strict checking on. Presenters, ViewModels and Stores are
  `@MainActor`; everything in the domain and data layers that crosses a boundary is `Sendable`.
- **Logging is `os.Logger`** through `Logger(for: Self.self)`, never `print`, and never anything personal.
- **Haptics go through `Haptics`** (see [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)), from views only, so that the one
  switch in Settings silences them all. `.sensoryFeedback` and the UIKit generators are not used anywhere else.
- **Every user-facing string** is a constant in `Strings.swift` or one of its `Strings+Topic.swift` extensions. After changing one, run
  `python3 Tools/sync_strings.py`, which rebuilds `Localizable.xcstrings`; CI fails if the two differ.
- **Every interactive control has an accessibility label**, and decorative images are hidden from VoiceOver.
- **Views do not use `if`/`else` to swap content that should keep its state**; they keep both in the tree and
  change `opacity`, hiding the unseen one from touches and from VoiceOver.
- **Comments say why, or what something is for**, in plain English. `///` on every type and on any function
  that is not obvious from its name; `// MARK:` to divide a long file.
- **SwiftLint passes with no warnings** (`swiftlint lint --strict`): lines up to 160 characters, files up to
  400 lines, function bodies up to 50, type bodies up to 250, and at most five parameters.

## Adding a screen

1. **Domain first.** Add the models, and an Interactor or DataProvider if the screen needs new work
   done. A provider is a struct of `@Sendable` closures with a `.live()` version. If the state will be
   shared with another screen, add or extend a Store.
2. **ViewModel.** `Screens/Thing/ThingViewModel.swift`: an `@MainActor @Observable final class` of plain
   state, together with any `...Kind` enums that describe it.
3. **Presenter.** `Screens/Thing/ThingPresenter.swift`: a `@MainActor final class` that owns the
   ViewModel and takes its dependencies in `init`. Declare `ThingPresenterDelegate` above it for
   anything that leads off the screen, and hold the delegate weakly. Catch errors here.
4. **View.** `Screens/Thing/ThingView.swift` takes the Presenter. Build it from the design system
   (see [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)), put its strings in `Strings.swift`, and start loading
   with `.task { await presenter.loadAction() }`.
5. **Coordinator.** Build the Presenter in `AppCoordinator.init`, set `delegate = self`, conform to the
   delegate in an extension, and add a flag to `AppRouter` that `RootView` presents the screen from.
6. **Tests.** Swift Testing, with a `makeTestSubject()` helper and closures in place of the providers.
   Test the Presenter's decisions and any pure logic; do not test SwiftUI itself.
7. **Check.** `swiftlint lint --strict`, `python3 Tools/sync_strings.py`, then the tests and the Mac
   Catalyst build, as in the README.

Files added under `HearthKit` are picked up by the package on their own. Files added or moved under
`App/` need `xcodegen generate`.
