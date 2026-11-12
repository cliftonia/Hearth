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
5. **Interface text uses the system text styles** (`.body`, `.subheadline`, `.footnote`, `.caption`), so it
   follows Dynamic Type. `HearthFont` is for the serif and monospaced faces only. Never set a fixed
   point size.
6. **Reach for a component before drawing a pattern again.** If the same shape appears a second time,
   it moves into `DesignSystem/Components`.
7. **Every interactive control carries an accessibility label**; decoration is hidden from VoiceOver.
8. **Changing a token changes the app.** Tokens with near-equal values, such as the radii 12 and 14, are
   kept apart on purpose; do not merge them without meaning to change the look.

## Tokens

### Colour: `HearthColor`

Each colour has a light and a dark value and follows the appearance by itself.

| Token | Light | Dark | For |
|---|---|---|---|
| `paper` | `#F3F5F1` | `#121715` | The background of every screen |
| `card` | `#FFFFFF` | `#1B2220` | Raised surfaces: the composer, code blocks, pills, round buttons |
| `bubble` | `#E6EBE5` | `#232C29` | The user's message bubble; the selected chat in the list |
| `line` | `#DDE2DC` | `#2A3330` | Borders and dividers |
| `scrim` | black | black | The veil over the chat while the drawer is open |
| `ink` | `#18211E` | `#E9EEEA` | Body text and primary symbols |
| `mute` | `#6C7772` | `#8B9691` | Secondary text, placeholders, quiet symbols |
| `pine` | `#2C6B5A` | `#6FC2A8` | The brand colour: the tint, primary buttons, anything switched on |
| `pineSoft` | `#DCEAE4` | `#1F3A32` | The fill behind something switched on |
| `onPine` | `#FFFFFF` | `#0E1211` | Text and symbols drawn on pine |
| `danger` | `#C8553D` | `#E0705A` | Errors, recording, buttons that end or destroy |
| `onDanger` | white | white | Symbols drawn on danger |
| `online` | `#3FA66B` | `#57C283` | The server can be reached |
| `orb` | `#9FE0CB`, `#2C6B5A`, `#1B4A3D` | `#9FE0CB`, `#3E8A75`, `#1B4A3D` | The voice orb's gradient |

A new colour is made with `Color(lightHex:darkHex:)`, and only inside `HearthColor`.

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
| `composer` | 24 | The composer |

Rounded rectangles are always drawn with `style: .continuous`. Pills and round buttons use `Capsule` and
`Circle`, which need no radius.

### Size: `HearthSize`

| Token | Points | For |
|---|---|---|
| `hairline` | 1 | Borders and dividers |
| `iconButton` | 40 | An `IconButton`, and anything that lines up with one |
| `composerControl` | 34 × 32 | Attach and dictate |
| `optionChip` | 38 × 32 | A switch in the composer's options |
| `sendButton` | 34 | The composer's send button |
| `messageAction` | 34 × 30 | Copy, share, read aloud, try again |
| `floatingButton` | 48 | Settings and New chat over the chat list |
| `voiceButton` | 60 | Mute and end in a voice conversation |
| `statusDot` | 10 | The connection dot; the writing indicator |
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
| `IconButton(systemImage:label:action:)` | A round, borderless, 40-point button with one symbol | Header buttons. The label is what VoiceOver reads |
| `OptionChip(systemImage:isOn:)` | An icon-only capsule, filled when on and outlined when off | The label of a `Button` or `Menu` that switches something |
| `Hairline(axis:)` | A one-point line in the line colour | Dividers, horizontal by default |
| `.surface(_:fill:border:)` | A filled shape with a hairline border inside its edge | Any bordered shape; the modifiers below are built on it |
| `.cardSurface(radius:border:)` | A card-coloured rounded rectangle with a border | Code blocks, tables, the search field, the composer, the error banner |
| `.capsuleSurface(fill:)` | A bordered pill | The model picker, sources, attached files |
| `.capsuleOutline(_:)` | A capsule's border with nothing behind it | Quiet controls such as attach and dictate |
| `.hearthShadow(_:)` | One of the shadows above | Lifting a surface off the paper |

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

Views shared between screens that know about the domain, such as `MarkdownSection`, are not part of the
design system; they live in `HearthUI/Components` and are built from it.

## Adding to it

- **A token**: add it to the right enum with a `///` line saying what it is for, and add a row to the
  table here.
- **A component**: one file in `DesignSystem/Components`, built only from tokens, with no knowledge of
  the domain or of any screen. Add a row to the table here.
