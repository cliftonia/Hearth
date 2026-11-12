# Architecture

Hearth is a thin app target around a local Swift package, `HearthKit`. The package is split into four
modules, and each may import only the ones beneath it.

```
App/            The @main entry point and the App Intent. Builds one AppCoordinator and shows its root view.

HearthUI        Coordinator, Presenters, ViewModels, SwiftUI views, design system   @MainActor
   │
HearthDomain    Models, Interactors, Stores, DataProviders, Transformers             Sendable
   │
HearthData      Services and DTOs: Ollama, SearXNG, Kokoro, files, audio, speech     Sendable
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
| **Model** | An immutable, `Sendable` value type in the domain. Changed by making a copy (`updating(...)`). | `Conversation`, `Message`, `ServerSettings` |
| **View** | A SwiftUI view that holds its Presenter, reads the ViewModel and calls `...Action` methods. No logic beyond layout. | `ChatView` |
| **ViewModel** | An `@Observable`, `@MainActor` class of plain state for one screen. No logic beyond small derived values. | `ChatViewModel` |
| **ViewConfiguration** | An immutable `Hashable` struct of display-ready values for one component. | `ErrorViewConfiguration`, `SidebarRowViewConfiguration` |
| **Presenter** | A `@MainActor` class that owns the ViewModel, handles the View's actions, catches errors, and asks the coordinator for navigation through a weak delegate. | `ChatPresenter` |
| **Coordinator** | `AppCoordinator`. Builds every Presenter, conforms to their delegate protocols in extensions, and changes the `AppRouter`. | `AppCoordinator` |
| **Store** | An `@Observable`, `@MainActor` class of state shared by more than one screen, with `private(set)` properties and methods that change them. | `SettingsStore`, `ConversationStore`, `MemoryStore`, `ModelStore` |
| **Interactor** | A concrete `Sendable` class that carries out a piece of business logic through the providers it is given. | `ChatInteractor`, `SpeechInteractor` |
| **DataProvider** | A struct of `@Sendable` closures, a "protocol witness", with a `.live()` version that calls the services. Tests pass their own closures. | `ChatDataProvider`, `DictationProvider` |
| **Transformer** | Pure logic from one value to another, with no state beyond what it is fed. | `MarkdownTransformer`, `PromptBuilder`, `SentenceChunker` |
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
   Settings as a sheet, the voice conversation as a full-screen cover, and the lock over everything.
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
  AppCoordinator.swift          Builds and connects the screens
  AppRouter.swift               What is presented besides the chat
  AppDependencies.swift         Everything the screens are built from, and its live version
  AppDefaults.swift             The addresses the app starts with
  Screens/
    Root/                       RootView, DrawerContainer
    Chat/                       ChatView, ChatPresenter (+Replying, +Editing, +FollowUps, +Voice), ChatViewModel
      Components/               The header, a message, the composer and the other sections of the chat
      Attachments/              The camera, and loading photos and files
    Sidebar/                    SidebarView, SidebarPresenter, SidebarViewModel, its configurations, ConversationGrouper
    Settings/                   SettingsView, SettingsPresenter, SettingsViewModel, MemorySection
    Voice/                      VoiceView, VoicePresenter, VoiceViewModel, VoiceOrb
    Lock/                       LockView, LockPresenter, LockViewModel, LockWindowController
  Components/                   Views shared between screens that know about the domain: Markdown, the error configuration
  DesignSystem/
    Tokens/                     HearthColor, HearthFont, HearthSpacing, HearthRadius, HearthSize, HearthShadow
    Components/                 HearthMark, IconButton, OptionChip, Hairline and the surface modifiers
  Extensions/                   How domain values are named and shown: AppearanceKind, ThinkingLevelKind
  Localization/Strings.swift    Every user-facing string
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

## Conventions

- **Actions are named for intent**: `sendAction`, `saveAction`, never `didTapSendButton`.
- **`Kind`, not `Type`**, for enums of cases: `VoiceStateKind`, `AppearanceKind`.
- **Identifiers are `Tagged`**, so a conversation's identifier cannot be passed where a message's is wanted.
- **Protocol conformances go in extensions**: `extension AppCoordinator: ChatPresenterDelegate`.
- **Switches over our own enums list every case**, with no `default`, so a new case fails to compile until it is handled.
- **Concurrency is async/await throughout**, with strict checking on. Presenters, ViewModels and Stores are
  `@MainActor`; everything in the domain and data layers that crosses a boundary is `Sendable`.
- **Logging is `os.Logger`** through `Logger(for: Self.self)`, never `print`, and never anything personal.
- **Every user-facing string** is a constant in `Strings.swift`. After changing one, run
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
