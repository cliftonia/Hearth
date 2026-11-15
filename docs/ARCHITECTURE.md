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
| **Interactor** | A concrete `Sendable` class that carries out a piece of business logic through the providers it is given. | `ChatInteractor`, `ResearchInteractor`, `SpeechInteractor`, `ProjectInteractor`, `EraseInteractor` |
| **DataProvider** | A struct of `@Sendable` closures, a "protocol witness", with a `.live()` version that calls the services. Tests pass their own closures. | `ChatDataProvider`, `ProjectDataProvider`, `DictationProvider`, `CameraProvider`, `NotificationProvider` |
| **Transformer** | Pure logic from one value to another, with no state beyond what it is fed. | `MarkdownTransformer`, `PromptBuilder`, `SentenceChunker`, `ReplyNotificationPlanner`, `ResearchSourceSelector`, `CanvasExtractor` |
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
   Settings and the project sheets as sheets, the canvas beside the chat or as a sheet, the voice conversation
   as a full-screen cover, and the lock over everything.
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
  AppCoordinator.swift          Builds and connects the screens (+Projects: where the project sheets lead; +Canvas:
                                opening and closing the canvas)
  AppRouter.swift               What is presented besides the chat
  AppDependencies.swift         Everything the screens are built from, and its live version
  AppDefaults.swift             The addresses the app starts with
  Screens/
    Root/                       RootView, DrawerContainer
    Chat/                       ChatView, ChatPresenter (+Replying, +Pictures, +Research, +Editing, +FollowUps, +Notifications, +Voice, +Canvas), ChatViewModel
      Components/               The header, a message, the composer and the other sections of the chat
      Attachments/              The camera, and loading photos and files
    Sidebar/                    SidebarView (+Projects), SidebarPresenter (+Projects), SidebarViewModel, its configurations, ConversationGrouper
    Project/                    ProjectView, ProjectPresenter, ProjectViewModel: the sheet that makes or edits a project
    ProjectPicker/              ProjectPickerView, ProjectPickerPresenter, ProjectPickerViewModel: the sheet that files a chat
    Settings/                   SettingsView, SettingsPresenter (+Profile, +Notifications), SettingsViewModel, and its
                                sections and pushed pages: ProfileSection, MemorySection, NotificationsSection, SettingsCard
    Voice/                      VoiceView, VoicePresenter (+Camera), VoiceViewModel, VoiceOrb, VoiceControls, and the
                                camera's card: VoiceCameraCard, CameraPreviewSurface, VoiceCameraLayout
    Canvas/                     CanvasView, CanvasPresenter, CanvasViewModel, CanvasCodeSection, CanvasWebPreview (the
                                locked-down web view) and CanvasLayout (how a wide screen is shared)
    Lock/                       LockView, LockPresenter, LockViewModel, LockWindowController
  Components/                   Views shared between screens that know about the domain: Markdown, the error configuration
  DesignSystem/
    Tokens/                     HearthColor, HearthFont, HearthSpacing, HearthRadius, HearthSize, HearthShadow
    Components/                 HearthMark, IconButton, OptionChip, Hairline, Avatar, PermissionNotice, Haptics and the
                                surface modifiers
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

## Deep research

Research answers one question with a report written from pages the app searched for and read. It is a turn like
any other: it runs with the chat's selected model, streams into a reply, and is saved in the conversation.

- **Chosen as an effort.** The model sheet's Effort menu lists the thinking levels and then Deep research.
  `EffortChoiceKind` is that choice: `.thinking(ThinkingLevelKind)` or `.research`. Research is never a thinking
  level and is never sent to the model as one; while it is chosen the model thinks at the level saved in the
  settings. A thinking level is saved for every chat (`ServerSettings.thinkingLevel`); research is only
  `ChatViewModel.isResearchMode`, which belongs to the open chat, is not saved, and is cleared by a new chat, by
  opening another chat and by picture mode. A model that cannot think is offered one ordinary choice and research.
  Without a search address research is listed, disabled, with a line saying why.
- **The run** is `ResearchInteractor.run`, a stream of events, built on the same `ChatDataProvider` and
  `SearchDataProvider` as a reply, so requests go to the same model through the same service and pages are read
  through `PageService` and its `PageAddressPolicy`. In order: plan (one request), search each query, choose the
  pages, read them a few at a time, take notes on each (one request a page), ask once whether anything important is
  missing (one request) and, if so, search, read and note once more, then write (one streamed request).
- **What is pure** sits in transformers: `ResearchQueryParser` reads queries out of JSON, fenced JSON, objects or
  plain lines, and falls back to the question; `ResearchSourceSelector` drops repeats by normalised address, lets
  the searches take turns and caps the pages from one site; `ResearchPromptBuilder` words each request and fences
  page text and notes between markers made up for the run; `ResearchCitationTransformer` turns every citation into
  a plain `[n]`, removes any number with no source behind it, and cuts the sources to those cited, renumbered in
  order. Citations inside code and the text of links are left alone.
- **Bounds** are the constants of `ResearchLimits`: queries, sources, sources from one site, pages fetched at once,
  note requests at once, the wait for a page, characters read from a page, characters of one page's notes, and
  characters of notes handed to the writer.
- **What stops it.** A search or a page that fails is passed over. With nothing to write from it throws a
  `ResearchError` that says which step came to nothing (`searchFailed`, `nothingFound`, `nothingReadable`,
  `nothingRelevant`) and no report is written. The model failing on one page loses that page; failing on all of
  them is the chat server's error. Stopping cancels the task the stream runs in, and with it every fetch and
  request under way, since all of them are child tasks of it.
- **Kept** as an ordinary reply whose `Message.isResearch` is set, with the report as its text and the cited pages
  as its `sources`, so "Try again" researches again whatever effort is then chosen, keeping the earlier report as
  a version. A report stopped part of the way is kept as far as it got, tidied in the same way. The sources close
  memory for the rest of the conversation, as any web search does, and research itself reads no memories.
- **On screen**, `ChatPresenter+Research` shows each step as a line under the reply (`ChatViewModel.researchStatus`)
  and `ResearchSourcesSection` lists the sources under a finished report by number, title and site. The logs hold
  counts only: never the question, a page's text or an address.

## The canvas

A reply may hold a piece of standalone work: a web page, a drawing, a document or a long block of code. The chat
shows a card in its place, and the card opens it in the canvas. Nothing about it is stored and nothing about it is
sent to the model; a piece is read out of the saved text of its reply each time it is wanted.

- **What a piece is** is decided by `CanvasExtractor`, a pure transformer over a reply's Markdown. It reads the
  text once, line by line, and cuts it into `CanvasSegment`s: stretches of ordinary Markdown and `CanvasPiece`s. A
  fenced block is a piece when it is HTML or SVG, by its language tag or by how it begins (`<!doctype html`,
  `<html`, `<svg`), or when it has at least `CanvasExtractor.minimumLineCount` lines, 15, as a `markdown`/`md`
  document or as code. Any other block stays in the Markdown around it, exactly as written, and is drawn by
  `MarkdownSection` as before. A fence still open when the text ends makes a piece that is not yet closed
  (`isClosed`), which is how a reply on its way is read. A block is closed by a bare fence at least as long as
  its own, and a Markdown document counts the fenced blocks inside it in and out.
- **Its kind** is a `CanvasKind`: `html`, `svg`, `markdown` or `code(language:)`. **Its title** is the page's or the
  drawing's own `<title>`, a document's first heading, or else the nearest heading within twelve lines above it;
  with none, the UI names it for its kind ("Page", "Drawing", "Document", "Python code"). **Its identity** is its
  place among the pieces of its reply, which cannot change while the reply streams, with the message's
  identifier: a `CanvasReference`.
- **Versions** are found by `CanvasVersionMatcher`, also pure: a piece anywhere in the chat is a version of the
  open one when it is the same kind (any two pieces of code are) and either has the same title or is the only
  piece in its reply. The canvas remembers the piece it was opened for and, at most, a version stepped back to;
  with none it shows the newest, so a version being written is followed as it arrives.
- **In the chat**, `ReplyBodySection` lays a reply out from its segments, with a `CanvasCard` for each piece. A card
  whose piece is open in a reply still streaming shows that it is being written.
- **The screen** is `CanvasPresenter`, `CanvasViewModel` and `CanvasView`. The presenter is given two closures, the
  open chat's messages and the reply on its way, and builds a `CanvasViewConfiguration` from them whenever the
  view asks, so it holds no copy of anything. The view model holds only what was opened, the version looked at
  and the choice of Preview or Code. A piece still being written is shown as code, and a page is handed to the
  web view only once it is finished.
- **Opening and closing** go through the coordinator (`AppCoordinator+Canvas`): the card calls
  `ChatPresenter.canvasAction`, the coordinator opens the presenter and sets `AppRouter.isCanvasOpen`. A wide screen
  shows the canvas as a trailing column of `RootView`; `CanvasLayout` gives it half of the space beside the chat
  list and puts the chat list away while there is not room for all three, which needs no state of its own, so
  closing brings the list back. A narrow screen shows a sheet (`isCanvasSheetPresented`, which the router keeps in
  step with the width). The canvas closes by its button, by its sheet being swiped away, by the lock, and when its
  piece is no longer in the open chat, as when another chat is opened. Closing sends VoiceOver to the message
  field and raises no keyboard.
- **A generated page is untrusted.** `CanvasWebPolicy` in the domain holds the decisions and `CanvasWebPreview`
  carries them out in a `WKWebView`: the document is loaded with `loadHTMLString` and no base address, into a
  store that keeps nothing; scripts run; a compiled `WKContentRuleList` blocks every `http`, `https`, `ws`, `wss`
  and `ftp` request, and no web view is made until those rules are installed, so if they cannot be compiled the
  page is not shown at all; every navigation to anything but `about:` is cancelled, so a link opens nothing, here
  or in the browser; new windows, the camera, the microphone, the motion sensors and the link menu are refused;
  there are no message handlers; and a script run before the page's own takes away peer connections, the one way
  to the network that is not a request. The log notes that a navigation was cancelled and never its address.

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

## Voice with the camera

A voice conversation may have the camera on. While it is, each spoken turn is sent with one still picture taken as
the words end. No video is recorded or sent.

- **The provider.** `CameraProvider` in the domain is a struct of closures: ask for leave, start facing one way,
  stop, flip, take one frame, say what cameras there are, and hand over the layer the live picture is drawn in.
  `CameraProvider.live()` is backed by `CameraService` in the data layer, an `AVCaptureSession` with a video output
  whose pictures are let go unseen unless a frame has been asked for; the one asked for is encoded as JPEG. All of
  it runs on the service's own queue. The preview is a plain `CALayer` as far as the domain and the UI know;
  `CameraPreviewSurface` holds it in a view.
- **The account.** `VoiceCamera` is the pure state, kept on `VoiceViewModel`: off, asking, starting or on, which
  way it faces, and why it is off if the user would expect otherwise. Every attempt to turn the camera on is
  numbered, and each step of it is checked against that number, so an attempt overtaken by the screen closing, the
  app leaving the front or another tap can never leave the camera running. `VoiceCamera.control` says whether the
  button is hidden (no camera), disabled (the chosen model cannot see; the screen says so, and no other model is
  chosen for the user) or enabled.
- **The presenter.** `VoicePresenter+Camera` asks for leave only when the button is first turned on. A refusal
  leaves the conversation as it was and shows a `PermissionNotice` that leads to the system's settings. The camera
  is stopped by its button, by the conversation ending, by the screen going away for any reason, and by the app
  leaving the foreground (`VoiceView` watches the scene phase); it starts off every time the screen opens. The
  system's own question about the camera also takes the app from the front, so an attempt that is only asking is
  left to finish unless the app goes off screen altogether.
- **The picture.** When the listener hears the end of a turn, the loop asks for one frame before anything is sent.
  The frame goes through `PhotoLoader.downscaledJPEG`, the same shrinking an attached photo is given, and is handed
  to the chat with the words (`ChatPresenter.submit(text:imagesJPEG:style:onDelta:)`), where it is an ordinary
  `Message.imagesJPEG`: shown on the user's message, saved with the chat, sent to the model, and closing memory, in a
  private chat as in any other. A frame that cannot be taken or read means the turn goes without one.
- **In the simulator** there is no camera. A debug build for the simulator uses `CameraProvider.simulated()`, which
  serves a drawn test card for each side (`SimulatedCameraService`). Launching it with the argument
  `-HearthVoiceScript "words"` also puts a scripted listener in place of the recogniser, which hears those words
  once, twenty seconds after listening begins, and a voice that says nothing and asks no speech server; with empty
  words it hears nothing. All of it is inside `#if DEBUG && targetEnvironment(simulator)` and is in no build that ships.

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
