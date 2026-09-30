# Converter state spike — recommendation

**029 already answered this plan's question. Close it as answered.**

Not the product question — the architectural one. The plan's premise was that
`bsDate`/`adDate` were "plain public `var`s, so any write skips `clampBSDay()`".
As of `7274821` they are `private(set)` (`ConverterModel.swift:19`, `:24`,
`:25`), both clampers are `private` (`:173`, `:187`), and every write goes
through a named mutating path. **A `resetToToday(now:)` is now the only shape a
reset can take**, because it is the only way to write the state. The spike's
central design choice is not open; it was settled as a side effect of a bug
fix. What remains is a product judgment about a button, which is not what this
plan was asked.

**Step 1, measured rather than reasoned.** The plan made "per process or per
presentation" the item's whole value. I built a probe replicating `NepalKitApp`'s
exact shape — default-initialized `@State` on an `App` struct *plus* the
explicit `init()` at `:24-37` — stamping a serial and a seeded instant at
construction, then drove repeated `App.body` evaluations. Across three builds:
**`Probe.init` ran exactly once while `body` evaluated 5–7 times.** The
`Date.now` read at `ConverterModel.init:85` is taken **once per process**, so
the plan's Step 1 STOP condition does *not* fire and its severity claim stands
— the window is the **login session**, and the app is a login item
(`spec.md:34` story 20, `NepalKitApp.swift:28`). The staleness is also not
visible: `ConverterView` renders three bounded pickers and a result line, and
nothing marks the offered date as stale.

**The other half also holds.** A child view's `@State` does reset when it
leaves and re-enters the hierarchy (`destination` returned `.today` on four
remounts, with and without `.id()`), which is why `PopoverView.swift:49-53`
works. But the plan has the asymmetry backwards: it is not an inconsistency to
correct. `destination` is ephemeral **by design, with a stated reason** at
`:49-52`; `ConverterModel` is app-scoped because `PopoverView` takes it as a
`let` (`:39`) and `MenuBarExtra`'s one content closure (`:40-41`) captures it
once. Matching them would mean moving a model into a view.

**Classification — the durable output.** Nine types, one genuine outlier:

| Type | Current | Intended | Why |
|---|---|---|---|
| `ConverterModel` | session | **session + reset** | user-chosen date; no route back |
| `ClockModel` | session | session | ticks; the popover shows live time while closed |
| `MenuBarModel` | session | session | polls `now`; a per-presentation scope freezes the menu bar |
| `UpdateCheckModel` | session | session | background work outlives any surface |
| `LoginItemModel` | session | session | reads OS registration; not UI state |
| `DisplaySettingsModel` | session | session | persisted; a UI-lifetime scope loses saves |
| `SettingsStore` | session | session | a `struct` over `UserDefaults`, not observable state |
| `AppData` | process | process | a `static let`; no lifetime question |
| `AppMetadata` | read-at-show | read-at-show | `28fb97a` already moved it |

The rule: **models holding a clock or OS state are session-scoped because
something outside any window needs them; only a model holding *user-chosen*
state is a reset candidate**, and `ConverterModel` is the only one of the nine
that is. That belongs in `CODING_STANDARDS.md` §*App-layer models* (`:93-97`)
beside "views own layout only" — not `CONTEXT.md`, a glossary. **I did not
write it:** a standards edit is not a spike's to make unilaterally.

**Recommendation: add `ConverterModel.resetToToday(now:)` and a `Today`
control, but do not schedule it.** The signature follows the injection
convention already in the repo (`ConverterModel.init:85`,
`ClockModel.swift:41`); it writes both stored properties, runs both clampers,
and leaves `direction` alone, since `spec.md:23` story 9 makes direction-carry
deliberate. The control goes in `ConverterView.body`'s `VStack` below the output
line, not in the picker row: 019's `PickerColumn` (`:78-85`) is a *value*
contract and a button is none of those, so it survives 029 and 019 untouched.
Symbol naming does not block — `clock.arrow.circlepath`,
`calendar.badge.clock` and `arrow.uturn.backward` all resolve non-nil under
`NSImage(systemSymbolName:accessibilityDescription:)` — and
`clock.arrow.circlepath` reinforces the label "Today" where a backward arrow
would not. Spoken form is `Strings.todayLabel` (`Strings.swift:66`) plus a hint,
on a channel kept separate per `CONTRIBUTING.md:125-127`. **Rejected: (b),
re-seed on presentation** — after 029 it is not even expressible from the
popover, and it destroys a converted date on every open, the `spec.md:23`
regression the plan warns about.

**Step 4's execution order: there is none to recommend.** 019 and 029 are both
landed. 018 is partly landed (`8c0b155`; `NepalKit/SpokenDate.swift:5-8` is now
the app-copy half), and a `Today` control's spoken form is a static string, not a
date form, so it does not move with 018 either way.

**Falsified by** a user reporting a stale date twice, or telemetry showing
Convert opened more than once per session. Absent that, a prior audit left four
direction items unselected for the same reason (clipboard, Nepali UI, month
calendar, `swift run`); this is not better evidenced, only cheaper. **Changed
by:** a ruling that the converter should *open* on today — then it is a
`destination` default, not a button.

**Not decided here:** whether a reset affordance earns its place in a 340pt
popover. **No ADR** — `CONTRIBUTING.md:132-134` compels one for a range,
licence, provenance or platform change, and this moves none of the four.
