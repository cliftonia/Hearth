# Design system

Everything that gives Hearth its look lives in `HearthKit/Sources/HearthUI/DesignSystem`. `Tokens/` holds
the values and `Components/` holds the few pieces built from them that are used in more than one place.

## Rules

1. **No raw colours in views.** Every colour is a `HearthColor`. That includes black and white: use
   `scrim` and `onDanger`. An opacity applied to a token is fine.
2. **No raw radii, shadows or border widths in views.** Use `HearthRadius`, `hearthShadow(_:)` and the
   surface modifiers, which draw every border at `HearthSize.hairline`.
3. **Gaps and padding come from `HearthSpacing`.** `0` may be written as `0`.
4. **A measurement that belongs to one view stays with that view**, as a `private static let` with a name
   that says what it is: an orb's diameter, a row's vertical padding tuned by eye. It becomes a token
   when a second view needs it.
5. **Interface text uses the system text styles through `Font.hearth(_:)`** (`.hearth(.body)`,
   `.hearth(.footnote)`), so it follows Dynamic Type on iPhone and iPad. On a Mac it is set a quarter larger than
   the style's standard size, grown or shrunk in proportion to the system's preferred size for the style
   (`Font.macPointSize`), so it follows the text size chosen for the app in the Mac's settings wherever the system
   passes it on. `HearthFont` is for the serif and monospaced faces only. Never set a fixed
   point size.
6. **Reach for a component before drawing a pattern again.** If the same shape appears a second time,
   it moves into `DesignSystem/Components`.
7. **Every interactive control carries an accessibility label**; decoration is hidden from VoiceOver.
8. **Every haptic is played through `Haptics`**, never with `.sensoryFeedback` or a UIKit generator directly,
   so that the switch in Settings silences them all. See [Haptics](#haptics).
9. **Changing a token changes the app.** Tokens with near-equal values, such as the radii 12 and 14, are
   kept apart on purpose; do not merge them without meaning to change the look.

## Tokens

### Colour: `HearthColor`

Each colour has a light and a dark value and follows the appearance by itself. The colours that carry meaning in a
quiet tone also have stronger values that are drawn while Increase Contrast is on (see the table below).

| Token | Light | Dark | For |
|---|---|---|---|
| `paper` | `#F3F5F1` | `#121715` | The background of every screen |
| `card` | `#FFFFFF` | `#1B2220` | Raised surfaces: the composer, code blocks, pills, round buttons |
| `bubble` | `#E6EBE5` | `#232C29` | The user's message bubble; the selected chat in the list |
| `line` | `#DDE2DC` | `#2A3330` | Borders and dividers |
| `scrim` | black | black | The veil over the chat while the drawer is open |
| `ink` | `#18211E` | `#E9EEEA` | Body text and primary symbols |
| `mute` | `#5F6A65` | `#8B9691` | Secondary text, placeholders, quiet symbols |
| `pine` | `#2C6B5A` | `#6FC2A8` | The brand colour: the tint, primary buttons, anything switched on |
| `pineSoft` | `#DCEAE4` | `#1F3A32` | The fill behind something switched on |
| `onPine` | `#FFFFFF` | `#0E1211` | Text and symbols drawn on pine |
| `danger` | `#B0472F` | `#E0705A` | Errors, recording, buttons that end or destroy, as text or a symbol |
| `dangerFill` | `#B0472F` | `#B54E3A` | The fill of a button that ends something, under `onDanger` |
| `onDanger` | white | white | Symbols drawn on `dangerFill` |
| `online` | `#3FA66B` | `#57C283` | The dot that says the server can be reached; never text, where success is `pine` |
| `orb` | `#9FE0CB`, `#2C6B5A`, `#1B4A3D` | `#9FE0CB`, `#3E8A75`, `#1B4A3D` | The voice orb's gradient |

A new colour is made with `Color(lightHex:darkHex:)`, or `Color(lightHex:darkHex:highContrast:)` when it needs a
stronger value under Increase Contrast, and only inside `HearthColor`.

#### Increase Contrast

The dynamic colour reads `traitCollection.accessibilityContrast`; at `.high` these values replace the ordinary ones.
Every other token keeps its own value.

| Token | Light | Dark | Measured |
|---|---|---|---|
| `mute` | `#46504B` | `#B4BEB9` | light 7.63:1 on `paper`, 6.93:1 on `bubble`; dark 9.50:1 on `paper`, 7.52:1 on `bubble` |
| `line` (and every hairline) | `#7A847D` | `#6A7570` | light 3.53:1 on `paper`, 3.20:1 on `bubble`; dark 3.79:1 on `paper`, 3.00:1 on `bubble` (non-text, 3:1) |
| `pine` | `#1E5446` | `#95DCC5` | light 7.94:1 on `paper`, white on it 8.71:1; dark 11.49:1 on `paper` |
| `danger` | `#8F3520` | `#F29A87` | light 7.09:1 on `paper`, 6.44:1 on `bubble`; dark 8.41:1 on `paper`, 6.66:1 on `bubble` |
| `dangerFill` | `#8F3520` | `#9A3F2D` | white on it: light 7.78:1, dark 6.72:1 |
| `online` | `#22784A` | `#86E0AA` | light 4.97:1 on `paper` (from 2.78:1); dark 11.44:1 on `paper` |

Text colours reach at least 4.5:1 against the surfaces they are drawn on (WCAG AA). In light, `mute` is 5.12:1 on
`paper` and 4.65:1 on `bubble`; `danger` is 5.05:1 on `paper` and 4.59:1 on `bubble`; white on `dangerFill` is 5.54:1.
In dark, `danger` is 5.72:1 on `paper` and white on `dangerFill` is 5.10:1. Check a new text colour before adding it.

### Type: `HearthFont`

| Token | Face | For |
|---|---|---|
| `brand` | Serif, title 2, bold | The app's name beside its mark |
| `display` | Serif, title, semibold | The one large line on an empty screen |
| `spoken` | Serif, title 3 | The caption of a voice conversation |
| `math` | Serif, title 3 | A formula on a line of its own |
| `heading(level:)` | Serif, title 2 / title 3 / headline | Markdown headings |
| `code` | Monospaced, footnote | Code blocks |
| `icon` | System, body, medium | The symbol in an `IconButton` |

Symbols in controls drawn in a fixed frame (the glass buttons, `IconButton`, the composer's controls, the reply's
actions, `OptionChip`, the sheet's close button) follow Dynamic Type only up to the largest standard size, through
`.iconGlyphSize()`, so they never outgrow their frames at the accessibility sizes. Each such control also offers the
large content viewer through `.largeContentLabel(_:systemImage:)`. Text beside them grows in full: names wrap to more
lines, and buttons with words grow taller.

### Spacing: `HearthSpacing`

Steps are named for their size in points: `s2`, `s4`, `s6`, `s8`, `s10`, `s12`, `s14`, `s16`, `s18`, `s20`,
`s24`, `s28`, `s32`. Only steps the app uses are listed; add one when a design needs it rather than
writing the number in a view.

### Corner radius: `HearthRadius`

| Token | Points | For |
|---|---|---|
| `row` | 10 | The highlight behind the selected chat |
| `card` | 12 | Code blocks, tables, notices, thumbnails, the search field |
| `banner` | 14 | The error banner |
| `bubble` | 18 | The user's message bubble |
| `bubbleTail` | 6 | The bubble's one tight corner |
| `preview` | 20 | The camera's live picture in a voice conversation |
| `composer` | 24 | The composer |

Rounded rectangles are always drawn with `style: .continuous`. Pills and round buttons use `Capsule` and
`Circle`, which need no radius.

### Size: `HearthSize`

| Token | Points | For |
|---|---|---|
| `hairline` | 1 | Borders and dividers |
| `iconButton` | 40 | An `IconButton`, and anything that lines up with one |
| `glassButton` | 44 | A `GlassCircleButton`, and the pill of glass beside it at the top of the chat |
| `composerControl` | 34 × 32 | Attach and dictate |
| `optionChip` | 38 × 32 | A switch in the composer's options |
| `sendButton` | 34 | The composer's send button |
| `messageAction` | 34 × 30 | Copy, share, read aloud, try again |
| `floatingButton` | 48 | Settings and New chat over the chat list |
| `voiceButton` | 60 | The camera, mute and end in a voice conversation |
| `minimumHitTarget` | 44 | The least a control may be touched across, through `.minimumHitTarget()` |
| `statusDot` | 10 | The connection dot (filled when the server can be reached, an empty ring when not); the writing indicator |
| `readingWidth` | 780 | The widest a line of chat grows |
| `sidebarWidth` | 320 | The chat list beside the chat |
| `drawerMaximumWidth` | 340 | The widest the drawer opens |

A size that is a `CGSize` is applied with `.frame(size:)`.

### Shadow: `HearthShadow`

| Token | Opacity of black | Blur | Offset down | For |
|---|---|---|---|---|
| `composer` | 5% | 10 | 2 | The composer |
| `floating` | 6% | 8 | 3 | A quiet floating button (Settings) |
| `floatingProminent` | 12% | 8 | 3 | The prominent floating button (New chat) |

Apply one with `.hearthShadow(.composer)`.

## Components

| Component | What it is | Use it for |
|---|---|---|
| `HearthMark(sideLength:)` | The app's mark, drawn in proportion to its side | The brand in the chat list, the empty chat, the lock |
| `IconButton(systemImage:label:action:)` | A round, borderless, 40-point button with one symbol | Buttons in a sheet's or a panel's header. The label is what VoiceOver reads |
| `GlassCircleButton(systemImage:label:isSelected:action:)` | A 44-point round button in its own bubble of glass, tinted pine when what it switches is on | The lone buttons at the top of the chat: the chat list and the private switch |
| `OptionChip(systemImage:isOn:)` | An icon-only capsule, filled when on and outlined when off | The label of a `Button` or `Menu` that switches something |
| `Hairline(axis:)` | A one-point line in the line colour | Dividers, horizontal by default |
| `Avatar(photoJPEG:initials:diameter:)` | A round picture of a person: a photo, else initials, else a person symbol | The profile row and the profile page |
| `PermissionNotice(systemImage:message:actionTitle:action:)` | A card saying the system is holding something back, with a button to where that is changed | Notifications refused; the camera refused |
| `SheetHeader(title:closeAction:)` | A sheet's title, centred between an empty slot at the leading edge and the round close button at the trailing one, as wide as each other, so a long title wraps instead of running under the button. Escape closes it too | The top of the model picker, the project picker and the tasks notice. Every sheet that is not an editor closes by one round button at the trailing edge (Settings and the canvas too); an editor has Cancel leading and Done trailing |
| `Haptics.play(_:)`, `.haptic(_:trigger:when:)` | The one place a haptic is played from | Every haptic; see below |
| `.surface(_:fill:border:)` | A filled shape with a hairline border inside its edge | Any bordered shape; the modifiers below are built on it |
| `.cardSurface(radius:border:)` | A card-coloured rounded rectangle with a border | Code blocks, tables, the search field, the composer, the error banner |
| `.capsuleSurface(fill:)` | A bordered pill | The model picker, attached files |
| `.capsuleOutline(_:)` | A capsule's border with nothing behind it | Quiet controls such as attach and dictate |
| `.glassSurface(_:tint:)` | The system's interactive glass in the given shape on iOS 26 and later; before that a frosted fill, a hairline edge and the floating shadow | The glass buttons, and the pill holding New chat and the chat's menu |
| `.hearthShadow(_:)` | One of the shadows above | Lifting a surface off the paper |
| `.hoverHighlight(_:)` | The system's highlight under an iPad's pointer, a faint wash of ink on a Mac, in the given shape | Every control drawn with the plain button style: the round buttons, the chips, menu labels, the composer's controls, the rows of the chat list and the settings. Put it after `.minimumHitTarget()` |
| `.minimumHitTarget()` | Grows the touchable area of a control to at least 44 points a side without moving or redrawing it | Every icon control drawn smaller than 44 points; put it last on the label |
| `.folded(_:)` | Keeps a view in place but folds it to nothing: unseen, untouchable and unread | A line that comes and goes, such as a check's result or an empty note, without an `if` |
| `.iconGlyphSize()` | Caps a symbol at the largest standard text size | The symbol of every icon control drawn in a fixed frame |
| `.largeContentLabel(_:systemImage:)` | Shows the control's name and symbol in the large content viewer | Every icon-only control |
| `.discardChangesDialog(isPresented:discardAction:)` | Asks "Discard your changes?" with Discard Changes and Keep Editing | Cancel in an editor that has been changed, alongside `.interactiveDismissDisabled` |
| `SectionHeading(title:isQuiet:)` | Small capitals in the muted colour, or plain words where quiet, read as a heading | The caption above a group of rows, quiet in the chat list; the caller pads it |

Order matters where a surface also casts a shadow: apply the surface first, then the shadow.

```swift
HStack(spacing: HearthSpacing.s8) {
    Image(systemName: "magnifyingglass")
        .font(.footnote)
        .foregroundStyle(HearthColor.mute)
        .accessibilityHidden(true)
    TextField(Strings.searchChats, text: $query)
        .font(.subheadline)
        .foregroundStyle(HearthColor.ink)
}
.padding(.horizontal, HearthSpacing.s12)
.cardSurface()
```

## Haptics

`Haptics` is the only thing in the app that plays a haptic. It asks `Haptics.isEnabled`, which the root view
keeps in step with the Vibration switch in Settings (shown on iPhone only, through `Haptics.isAvailable`), and does nothing on an iPad or a Mac, which have nothing to
tap with. A kind is named for how it feels, not for what caused it:

| `HapticKind` | Feels like | For |
|---|---|---|
| `light` | A light tap | Sending, pinning, opening or closing the chat list by its button, switching picture mode, a change of state in a voice conversation, turning its camera on or off, starting to hold to talk |
| `soft` | A softer, rounder tap | A reply finishing on screen; letting go after holding to talk |
| `selection` | A tick | Choosing a model or an effort, stepping between versions of a reply |
| `success` | Two rising taps | Copying, saving a picture, a picture arriving |
| `warning` | A caution | Confirming something destructive |
| `error` | Three sharp taps | The error banner appearing |

Call `Haptics.play(.light)` from a button's action, or hang `.haptic(.success, trigger: copyCount)` on a value
that changes; `when:` narrows it to the changes that count. Keep them light, play them from views and not from
presenters, and never tie one to a value that changes while text streams.

Views shared between screens that know about the domain, such as `MarkdownSection`, are not part of the
design system; they live in `HearthUI/Components` and are built from it.

The canvas added no token and no design-system component. Its card in a reply, `CanvasCard`, knows what a piece
of work is, so it lives with the chat's components; it is a `cardSurface()` holding the kind's symbol on
`pineSoft` at the `row` radius, a title, a line in `mute` and the word Open in `pine`. The panel is built from
`IconButton`, `Hairline`, the system's segmented picker and the code block's own styling (`HearthFont.code` on
`card`). The widths that share a wide screen between the columns are `CanvasLayout`'s, beside the one view that
uses them.

## Adding to it

- **A token**: add it to the right enum with a `///` line saying what it is for, and add a row to the
  table here.
- **A component**: one file in `DesignSystem/Components`, built only from tokens, with no knowledge of
  the domain or of any screen. Add a row to the table here.
