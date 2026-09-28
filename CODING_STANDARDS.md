# Coding standards

Conventions this codebase actually follows. Every rule below is grounded in
existing code; where a rule is narrow, the reason is stated. If a rule here
conflicts with the code, fix one or the other — don't leave them disagreeing.

## Module boundary

`NepalKitCore` is pure logic: the calendar dataset, BS ↔ Gregorian conversion,
and formatting. It imports `Foundation` only, never AppKit or SwiftUI, and does
not know the app exists. The app target holds menu-bar UI, settings persistence,
and app-specific behavior, and depends on the core package.

Core is where testable behavior goes. If logic can be expressed without a view,
it belongs in the core, not in a model.

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
init(now: Date = Date(), localTimeZone: TimeZone = .current, refreshInterval: TimeInterval = 1)
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

## User-facing strings

All UI strings live in `enum Strings` in `Strings.swift`, which imports only
`NepalKitCore`. It has its own file because both views and models need it — a
model returning a user-facing marker reaches for `Strings`, and putting it in a
view file would invert the models → views flow.

This is not a localization system: v1 ships an English interface, and the
month-name setting applies to Bikram Sambat month names and weekday names only.
Gregorian month names are always English (`Formatting.swift:105`) — don't route
them through the setting.

`AppTermination.quit()` is the app's single exit path. Both the popover's Quit
button and the ⌘Q command call it, so termination logic has one home.

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

## Commands

- Core tests: `swift test` in `NepalKitCore/`.
- App-layer tests: run the committed harness (see `README.md` and ADR-0005).
  `xcodebuild test` currently hangs before connecting and is not the runner.
- Release: `scripts/package-release.sh`.
- Menu-bar rendering spike: `scripts/menubar-spike.swift`.

## Before you commit

- Glossary terms used, `_Avoid_` synonyms absent.
- Any date you assert is sourced from a published calendar or an ADR, and the
  source is in a comment.
- New core logic is reachable through the package boundary and covered by a
  test that a reader can check against a published date.
- A workaround for a platform or toolchain quirk is commented where it was
  found, and filed as a known issue if it is still outstanding.
