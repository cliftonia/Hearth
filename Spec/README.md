# Spec: shared test vectors

The iOS app (this repository), the Android app (`HearthAndroid`) and Hearth Hub (`HearthHub`) are written
separately, in Swift, Kotlin and Python, and have to behave alike: tell the model the same thing, read the same
answers the same way, and agree on the sync wire. This folder holds that agreement as data. Each file gives
inputs and the output every platform must produce from them, and each platform's tests read it, so the two apps
cannot drift apart without a test failing on one of them.

This folder is the one place the vectors are edited. Phase 1 covers pure functions only: nothing here needs a
server, a clock or a device.

## Layout

```
Spec/
  vectors/   input → expected output for pure domain functions
  wire/      sync items as a device sends them to the hub, with what a reader must make of them
```

**`vectors/`**, one file per function, each `{"about": "...", "cases": [...]}` (the prompt file also gives the
shared settings: the time, the time zone and the project fence):

| File | What it pins down |
|---|---|
| `prompt_system.json` | The system message, paragraph by paragraph, for several settings (memory and search offered or not, a project, a private chat, voice). |
| `prompt_date.json` | The date line every prompt carries, research prompts included: `Monday 16 November 2026`, in English, in the device's time zone. |
| `passages.json` | Which passages of long files are chosen for a question, and how they are joined: `[…]` where text was left out; nothing when there is nothing to choose by. |
| `search_query.json` | What is searched for: the latest user message on one line, blank lines left out, at most 200 characters; nothing when it is only white space. |
| `memory_duplicates.json` | When a fact is already remembered: whatever its case or accents. |
| `provisional_title.json` | The first 48 characters of the first message, until the model names the chat. |
| `renamed_title.json` | A title typed by hand: trimmed and cut to 80 characters; nothing when empty. |
| `generated_title.json` | The title read out of a model's answer. |
| `follow_ups.json` | The follow-up questions read out of a model's answer. |
| `math.json` | LaTeX written out as plain text. |
| `sync_decisions.json` | What sync does with a received version, from the stamps alone. |

**`wire/`**, one item per file: `{"about", "kind", "id", "put", "expect"}`. `put` is the body of
`PUT /v1/items/<kind>/<id>` exactly as the hub's `docs/WIRE_FORMAT.md` describes it; `expect` is what a reader
makes of it (defaults filled in, identifiers in lowercase, the fields it does not know). They cover the examples of
WIRE_FORMAT.md and the edge cases: fields missing and the same fields `null` (read alike), unknown fields at body,
message and document level and on the envelope, a tombstone, and identifiers written in capitals.

## Who reads it

- **iOS.** `HearthDomainTests` (`Spec*Tests.swift`) reads the vectors and maps the wire conversations into models;
  `HearthDataTests` (`SpecWireTests.swift`) reads the wire examples as DTOs. They read this folder where it stands,
  found from the test file's own `#filePath`: the tests run on the Mac, in the simulator or not, which can read the
  source tree, so there is no copy to keep in step and nothing to run after a change. (Resources in the package
  would mean a second copy inside `HearthKit` and a script to refresh it, for no gain.)
- **Android.** The Android repository has no access to this one at build time, so it keeps a copy:
  `tools/sync-spec.sh` copies `vectors/` and `wire/` from `../Hearth/Spec` into `domain/src/test/resources/spec`,
  and `wire/` into `data/src/test/resources/spec`. `SpecCopyTests` fails while a copy differs from this folder, and
  is skipped where this folder is not beside the Android repository (a build server that checks out that
  repository alone).
- **Hearth Hub.** `tests/test_spec_wire.py` puts every wire example to a hub and reads it back from the changes
  unchanged; it is skipped when this folder is not at `../Hearth/Spec`.

## Adding a vector

1. Add a case to the right file, or a new file. A new vector file needs a test on both sides; the iOS test
   `every vector file is read by a test` lists the files, so a file no test reads fails it.
2. Run the iOS tests.
3. In the Android repository, run `tools/sync-spec.sh`, then `./gradlew test`.
4. For a wire example, run the hub's tests too: `python3 -m unittest tests.test_spec_wire`.

Keep the times in `wire/` in the past: the hub refuses an `updatedAt` more than a day ahead of its clock.

## Deliberate differences

Some things are allowed to differ, and the vectors keep clear of them:

- **Counting characters.** Every limit (48 for a provisional title, 80 for a rename, 200 for a memory, 60,000 for a
  file, and the rest) counts characters as each platform sees them: Swift counts whole characters, so an emoji with
  a skin tone or a letter with a combining accent is one; Kotlin counts UTF-16 units, and cuts only where a
  character begins, so a surrogate pair is never split but may count as two. The same long text can therefore be cut
  at a different place on each. The vectors put only plain characters at a cut.
- **Line breaks and white space.** Swift's newlines include U+2028, U+2029, U+0085, vertical tab and form feed;
  Kotlin's `lines()` breaks only at `\n`, `\r` and `\r\n`. The vectors use `\n` and `\r\n`.
- **Case and accents.** Foundation's case- and accent-insensitive comparison and Kotlin's
  NFD-strip-marks-lowercase agree on ordinary letters with accents; they can differ on letters such as `ß` that change
  length when their case changes. The vectors keep to the ordinary ones.
- **The canvas start script.** The Android script does three things the iOS one does not (`sendBeacon`, a guard on
  `Document.parseHTMLUnsafe`, a `DOMParser` wrapper), each for a reason that holds only in Chromium; the reasons are
  beside the iOS script in `CanvasWebPolicy+StartScript.swift` and in both `docs/ARCHITECTURE.md`. It is not
  covered here.
