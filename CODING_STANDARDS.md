# Coding standards

Conventions this codebase actually follows. Every rule below is grounded in
existing code; where a rule is narrow, the reason is stated. If a rule here
conflicts with the code, fix one or the other — don't leave them disagreeing.

## Module boundary

`NepalKitCore` is pure logic. It imports `Foundation` only, never AppKit or
SwiftUI, and does not know the app exists. The app target holds menu-bar UI,
settings persistence, and app-specific behavior, and depends on the core
package.

Core is where testable behavior goes. If logic can be expressed without a view,
it belongs in the core, not in a model.

Which types those are is not listed here on purpose. An inventory of a package
written into a standards document goes stale the moment a type crosses the
boundary, which is exactly when a reader most needs it to be accurate. This one
was wrong: it said the core held "the calendar dataset, BS ↔ Gregorian
conversion, and formatting" and stayed that way after `8c0b155` moved the spoken
forms in beside the formatters they mirror, so a reader deciding where
`SpokenDate` belonged would have been told it was not in the core at all. Read
`NepalKitCore/Sources/`.

## Naming

Use the glossary in `CONTEXT.md` — Bikram Sambat, Gregorian, Nepal Time, Nepali
Patro, digit script, month-name setting, supported range — in types, functions,
tests, and comments. Never use a term listed under a `_Avoid_` line. "BS" and
"AD" are acceptable in identifiers where `BikramSambat` would be unwieldy
(`BSDay`, `GADay`, `bsToAD`); the Avoid list targets prose.

Force unwraps are limited to values known to be non-nil at the call site:
`TimeZone(secondsFromGMT: 20700)!`, a fresh `UserDefaults(suiteName:)!` in a
test helper. Anywhere else, bind or return an optional.

An array subscript that can go out of range is the same class of hazard as a
force unwrap — a latent trap rather than a compile error. If an index comes from
outside the program, bounds-check it (`indices.contains(value)`), as
`devanagariString` does.

When a check belongs at a boundary, put it there once. `utcDate(from:)` is the
single place a `GADay` becomes a `Date` and therefore the single place civil-day
validity is enforced; `adToBS` and `weekday(of:)` rely on it rather than each
repeating a round-trip comparison.

## Pure functions over throwing ones

The core returns optionals and never throws. There is no error type and no
`try` in `NepalKitCore`. Invalid or out-of-range input yields `nil`:

```swift
public func bsToAD(_ bs: BSDay, in dataset: CalendarDataset) -> GADay?
public func adToBS(_ ad: GADay, in dataset: CalendarDataset) -> BSDay?
public func weekdayName(for weekday: Int, style: MonthNameStyle) -> String?
```

Views then decide how to present a `nil`, which is where user-facing wording
belongs. This keeps the whole conversion surface exhaustively testable without
error-handling noise at every call site.

## Validate once, at the boundary

Guard invalid components in a single shared helper rather than at each entry
point. `validatedMonths(for:in:)` in `Conversion.swift` is the one place a
Bikram Sambat date is checked against the dataset, and `utcDate(from:)` is the
one place a `GADay` becomes a `Date`.

`Calendar` silently normalizes impossible input — February 30 becomes March 1 —
so `adToBS` re-reads the components and rejects anything that doesn't round-trip
exactly. Don't trust `Calendar` to validate for you.

## Injection over globals

Every dependency that a test needs to control is a parameter with a sensible
default, not a global lookup:

```swift
init(now: Date = .now, localTimeZone: TimeZone = .current, refreshInterval: TimeInterval = 1)
func bsToAD(_ bs: BSDay, in dataset: CalendarDataset = .v2) -> BSDay?
SettingsStore(defaults: UserDefaults = .standard)
```

Hardware and OS services get a protocol so tests can substitute a mock —
`LoginItemServicing` behind `LoginItemModel` is the pattern. Models are dumb and
injectable: `SettingsStore` has no knowledge of the app.

Public value types in the core are `Sendable` and `Hashable`. Access control is
explicit on the public surface; internal helpers (`utcGregorian`,
`absoluteDayIndex`, `bsDay`, `validatedMonths`) stay internal.

## App-layer models

`@MainActor @Observable final class`, one per concern, instantiated as `@State`
in the app scene. Observable state is `private(set)`. Models own timers and
formatting inputs; views own layout only.

The app scene is a single `MenuBarExtra` with `.menuBarExtraStyle(.window)`.
Keyboard shortcuts go through scene `.commands` with
`CommandGroup(replacing:)` — a button-local `.keyboardShortcut` only fires while
that popover holds focus, which for an `LSUIElement` app is not an exit path.
Register the shortcut in exactly one place; two registrations for one action is
a bug even when both happen to work.

## Apple platform conventions

These are standing rules, not per-release preferences. They apply to every
surface without exception.

**Follow the Human Interface Guidelines.**
<https://developer.apple.com/design/human-interface-guidelines>, and its macOS
section,
<https://developer.apple.com/design/human-interface-guidelines/designing-for-macos>.
A control, a layout, or a naming choice that the HIG already answers is not a
design decision to make fresh — go and read what Apple says. Where NepalKit
knowingly departs from it, the departure gets a comment saying why, which is
usually a consequence of the app being `LSUIElement`.

**Use SF Symbols for all iconography.**
<https://developer.apple.com/design/human-interface-guidelines/sf-symbols>. Never
hand-draw a glyph, never ship a PNG or asset-catalog icon for something a symbol
covers, and never draw a bespoke app icon where Icon Composer will do — the app
icon is a layered `.icon` package for exactly this reason (ADR-0004). A symbol
name that does not resolve renders as *nothing at all*, with no error, so verify
names rather than trusting them: `NSImage(systemSymbolName:accessibilityDescription:)`
returning `nil` is the check, and it is worth running when adding one.

A symbol earns its place by reinforcing its label, never by decorating it. If a
row already reads "Nepal Time", a clock is reinforcement; a symbol that suggests
a different concept than the label is worse than none, because the user has to
reconcile the two. Check the pairing reads correctly before shipping it.

Rendering mode is chosen per surface for contrast against translucent Liquid
Glass, not imposed globally: hierarchical for section headers, monochrome for
small inline icons beside text (ADR-0004).

Liquid Glass is requested where a control needs the affordance and inherited
from the OS everywhere else. Today that is one place: the popover footer's two
buttons, which use `.buttonStyle(.glass)` inside one `GlassEffectContainer`.
Glass cannot sample other glass, so adjacent glass controls must share a
container or they render inconsistently against each other. Do not spread glass
to every control to make a surface look uniform — a `Form` of glass buttons is
neither conventional on macOS nor what the platform's own Settings does.
`.glass` and `.glassProminent` are macOS 26 APIs, so they need no `#available`
gate at this project's floor (ADR-0003, ADR-0007). `Glass` has no `.prominent`;
emphasis is `.regular.tint(_:)` with an opacity.

**Respect the menu-bar-only shape.** Do not call `setActivationPolicy`, and do
not add a Dock or Cmd-Tab presence. Any command that opens a normal window from
this context must go through `WindowPresentation` so activation and focus are
handled in one place (ADR-0011).

## User-facing strings

All UI strings live in `enum Strings` in `Strings.swift`, which imports only
`NepalKitCore`. It has its own file because both views and models need it — a
model returning a user-facing marker reaches for `Strings`, and putting it in a
view file would invert the models → views flow.

This is not a localization system: v1 ships an English interface, and the
month-name setting applies to Bikram Sambat month names and weekday names only.
Gregorian month names are always English (`Formatting.swift:105`) — don't route
them through the setting.

App Intents metadata is the exception. Intent titles, descriptions, parameter
summaries, phrases, and entity representations must be build-time literals at
their declaration site: the toolchain extracts them from source, and a
`LocalizedStringResource` cannot wrap a `Strings` constant. Runtime intent
dialogs are literal `LocalizedStringResource` values for the same reason.

`AppTermination.quit()` is the app's single exit path. Both the popover's Quit
button and the ⌘Q command call it, so termination logic has one home.

## SwiftUI and language conventions

These are the language- and framework-level rules. They are written down here,
and not left to review, because the failure they prevent is quiet: a superseded
spelling of a correct API still compiles, still passes every suite, and ships.
A pull request that uses one is wrong in a way only a reader will catch, and
most of them look like perfectly good Swift.

This list also lives in `AGENTS.md`, which is agent tooling and is gitignored —
so it reaches no contributor and no fresh clone. This is the copy that does, and
it is the authoritative one; the other is kept in step by hand.

### Swift

- Strict concurrency is assumed throughout. An isolation you did not write is
  not something to work around.
- Shared state is `@Observable`, never `ObservableObject`/`@Published`. Every
  `@Observable` class is `@MainActor` unless the project has default actor
  isolation. Ownership is `@State`; passing is `@Bindable` or `@Environment`.
  `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` and
  `@EnvironmentObject` are legacy here, and appear only where they already are
  and changing them would be the larger change.
- Concurrency is Swift's, not GCD's. No `DispatchQueue.main.async()`. Where an
  async API and a closure-based one both exist, take the async one.
- Prefer the Swift-native spelling of a Foundation API where one exists:
  `replacing("hello", with: "world")` over `replacingOccurrences(of:with:)`.
- Prefer the modern Foundation API: `URL.documentsDirectory` for the documents
  directory, `appending(path:)` to add a component to a `URL`.
- Never a `Formatter` subclass — `DateFormatter`, `NumberFormatter`,
  `MeasurementFormatter`. `FormatStyle` replaces all three:
  `myDate.formatted(date: .abbreviated, time: .shortened)` to render,
  `Date(inputString, strategy: .iso8601)` to parse,
  `myNumber.formatted(.number)` for numbers.
- Never C-style number formatting. `Text(String(format: "%.2f", abs(change)))` is
  `Text(abs(change), format: .number.precision(.fractionLength(2)))`.
- Prefer static member lookup to a struct instance: `.circle` over `Circle()`,
  `.borderedProminent` over `BorderedProminentButtonStyle()`.
- Filtering text the user typed uses `localizedStandardContains()`, never
  `contains()`.
- No force unwraps and no force `try` unless the failure is genuinely
  unrecoverable. *Naming* says where this codebase allows them, and why.
- No third-party framework without asking first. The dependency list is short on
  purpose: `NepalKitCore` and the app-test harness depend on nothing but each
  other.

### SwiftUI

- `foregroundStyle()`, never `foregroundColor()`.
- `clipShape(.rect(cornerRadius:))`, never `cornerRadius()`.
- The `Tab` API, never `tabItem()`.
- Never the one-parameter `onChange(of:)`. Use the variant that takes two
  parameters, or the one that takes none.
- `Button` rather than `onTapGesture()`, unless the tap's location or the number
  of taps is the thing you need.
- An image used as a button label always carries text alongside it:
  `Button("Tap me", systemImage: "plus", action: myButtonAction)`.
- `Task.sleep(for:)`, never `Task.sleep(nanoseconds:)`.
- Never `UIScreen.main.bounds` to ask how much space there is.
- `NavigationStack` with `navigationDestination(for:)`, never `NavigationView`.
- Bold text is `bold()`, never `fontWeight(.bold)`, and `fontWeight()` is not
  applied at all without a reason for it.
- No `GeometryReader` where a newer API answers the question —
  `containerRelativeFrame()`, `visualEffect()`.
- Render a view with `ImageRenderer`, never `UIGraphicsImageRenderer`.
- Hiding scroll indicators is `.scrollIndicators(.hidden)`, not
  `showsIndicators: false` in the `ScrollView` initializer.
- Scrolling and positioning use the current `ScrollView` APIs —
  `ScrollPosition`, `defaultScrollAnchor` — never `ScrollViewReader`.
- Split a large view into new `View` structs, not computed properties.
- `ForEach(x.enumerated(), id: \.element.id)`, never
  `ForEach(Array(x.enumerated()), id: \.element.id)`.
- Do not force font sizes; use Dynamic Type.
- No `AnyView` unless it is genuinely required.
- Hard-coded padding and stack spacing only when specifically asked for.
- No UIKit colors in SwiftUI code, and UIKit itself only when requested.
- View logic goes in a view model or the equivalent, so that it can be tested.

## Comments

Comment the *why*, especially the traps. A comment earns its place when it
records something the code cannot express: a spec invariant, a platform
misbehavior, a data-provenance decision.

```swift
/// The 30s poll keeps the label fresh cheaply; a one-shot midnight timer
/// fires just after the next Nepal Time midnight so the Bikram Sambat date
/// flips within ~1s (User Story 6), then reschedules itself.
```

Cite the source when one exists — a spec story number, an ADR, a published
calendar. Record a platform workaround where it was found, as
`MenuBarModel`'s `TimelineView` comment does. Do not narrate what the next line
does.

## Tests

Swift Testing (`import Testing`, `@Test`, `#expect`), never XCTest. Suites are
plain `struct`s; no test base classes, no `setUp`.

Assert externally observable behavior through the package boundary, never
implementation internals. State the expected value as a literal, and give the
reader the anchor:

```swift
// 27 Sep – 3 Oct 2026 are Sunday–Saturday; Ashoj 11–17, 2083.
```

Use `@Test("name")` when a bare function name doesn't say enough, and
`@Test(arguments:)` to sweep a set of cases. App-layer tests use
`@testable import NepalKit`; core tests cover the public API.

Deterministic logic and persistence are automated. Native visual rendering —
Liquid Glass materials, SF Symbol presentation, Devanagari layout in the status
bar — is verified manually and is not a unit-test target.

### Changing a supported-range boundary

A green suite does **not** prove every historical boundary assumption was
updated. A test whose fixture sits outside the new range can pass by not
running: `guard … else { continue }` turns "this assumption is now invalid" into
"this test did not run", which is worse than an ordinary assertion failure
because nothing goes red. `GregorianWeekdayTests` did exactly this during the
2.0.0 cut of 1970–1974 — a `1913-04-13` fixture stopped being convertible and
the suite stayed green.

So the order is:

1. Search the repository for the old lower/upper boundary literals.
2. Update the contract tests first, then change the data, so the failures show
   where the old bound was assumed.
3. Read every failure rather than bulk-rewriting expected values.
4. Review every conditional or guarded historical fixture **separately** — those
   are the ones a failure cannot report.
5. Search again afterwards for stale boundary literals.

Prefer a guarded fixture that records an issue over one that skips. If a fixture
is genuinely optional, say why in a comment, so a later range change does not
read the skip as coverage.

## Commands

- Everything: `scripts/check-all.sh`, the five local suites.
- Core tests: `swift test` in `NepalKitCore/`.
- App-layer tests: `scripts/run-app-tests.sh`. `xcodebuild test` currently hangs
  before connecting and is not the runner (see `README.md` and ADR-0005).
- Release: `scripts/package-release.sh`.
- Menu-bar rendering spike: `scripts/menubar-spike.swift`.

Four environment variables are read by those scripts, and none of them is
secret. `.env.example` is the place they are described, with each one's actual
default:

- `SPARKLE_BIN` — the Sparkle bin *directory*, so `verify-appcast.sh` can find
  `generate_appcast`. Unset, it searches DerivedData. `sign_update` lives in the
  same directory, and is what signs the feed itself; `generate_appcast` only
  writes items and signs archives.
- `NEPAKIT_DATA_CACHE` — where `verify-data-sources.py` caches fetched
  provenance tables. Unset, it uses `~/.cache/nepalkit-data-sources`; it caches
  in both cases, so this is not a switch for caching off.
- `NEPAKIT_TAP_DIR` — a local clone of the Homebrew tap for `update-cask.sh`.
  Unset, it uses `../homebrew-tap`.
- `NEPAKIT_BUILT_PLIST` — a built app's `Info.plist`, so `run-app-tests.sh`
  checks the shipped product rather than skipping five tests. Unset, the script
  discovers one and accepts it only if it is newer than the sources.

A new script that reads an environment variable adds it to `.env.example` in the
same commit, with the same "unset means" line. A variable that appears in a
script but not in that file is a claim no reader can check.

## Before you commit

- Glossary terms used, `_Avoid_` synonyms absent.
- Any date you assert is sourced from a published calendar or an ADR, and the
  source is in a comment.
- New core logic is reachable through the package boundary and covered by a
  test that a reader can check against a published date.
- A workaround for a platform or toolchain quirk is commented where it was
  found, and filed as a known issue if it is still outstanding.
- If a supported-range boundary moved, every guarded historical fixture was
  reviewed by hand and the tree re-grepped for the old bound.
- If you touched `appcast.xml` or the release pipeline, the feed is signed as
  well as the archives, and the signature is the **last** thing written:
  `sign_update appcast.xml`, after the notes injection, because it signs the
  exact bytes it is given. `scripts/verify-appcast.py` requires that block and
  fails without it, so an unsigned feed cannot be published by accident.
- Every new `systemImage` name was checked to resolve, and its pairing with its
  label actually reads. See *Apple platform conventions*.
- SwiftLint was **not** run. This project does not use it: there is no
  `.swiftlint.yml`, no lint step in any workflow, and no agreed rule set. A
  run on the current tree under SwiftLint's defaults reports 231 violations the
  project has never accepted — half of them `identifier_name` and `line_length`,
  which are house-style arguments rather than defects. "Make SwiftLint clean"
  is therefore not a bar this codebase has set, and a gate nobody can pass is
  worse than no gate. This document is the standard; review is where it is
  applied.
