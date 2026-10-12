# Today in Nepal Time or the user's time zone

Date: 2026-10-11
Status: accepted

## Context

Since 1.0 the app's rule has been that today follows Nepal Time (UTC+5:45),
whatever the Mac's own time zone (CONTEXT.md, *Today*). The Bikram Sambat date
in the menu bar flips at Nepal's midnight, the popover's header shows Nepal
Time, and a second row shows the Mac's local time when it differs.

That is right for the reader the app was built for: someone who wants to know
the date in Nepal. It is wrong for a second reader, someone outside Nepal who
keeps the Bikram Sambat calendar for their own days. For them, in New York, the
menu bar turns to tomorrow's date at 14:15 in the afternoon, and every evening
the app disagrees with the wall calendar beside them. They want their own
midnight.

Both readings are reasonable, and the app cannot tell which reader it has.

## Decision

1. **A setting, "Time zone", in Settings → General**, with two options:
   *Nepal Time* and *My time zone*. The second names the Mac's zone ("My time
   zone (Eastern Time)") so the reader knows what it will follow.

2. **Nepal Time is the default.** Nothing changes for a user who never opens
   Settings, and the stored value is read as Nepal Time when absent or not
   understood. It is persisted under the `timeReference` key, pinned in
   `PersistedIdentifierTests`.

3. **It applies everywhere on the Mac.** The choice decides which day is today
   in the menu bar, the Today hero, the month grid's today mark and the
   converter's starting day; when the menu bar's midnight fire and time tick
   land; which clock the popover's header shows; the menu bar's time; and the
   Siri answers for today, tomorrow and yesterday, which read it from
   `SettingsStore` as they read the month names. A setting that moved the menu
   bar but not Siri would leave two answers to "what is today".

4. **"My time zone" follows the Mac.** It is `TimeZone.autoupdatingCurrent`,
   and the menu bar observes the system's time zone change, so travelling with
   the Mac moves today without a relaunch.

5. **The clocks swap roles.** The header shows the clock today follows. The
   secondary row shows the other one — Local under Nepal Time, Nepal Time under
   My time zone — and is hidden when the two read the same, as before.

6. **The Watch stays on Nepal Time.** It has no settings, and the complications
   are scheduled on Nepal Time midnights (ADR-0015 covers how it ships). The
   core keeps Nepal Time as the default of every today function, so the Watch
   calls them unchanged.

## Consequences

- The core's today, midnight and menu-bar title functions take a time zone,
  defaulting to Nepal Time; `nextNPTMidnight(after:)` remains for the Watch and
  delegates to `nextMidnight(after:in:)`.
- With My time zone, the Mac and a paired Watch can show different dates in the
  hours the two zones disagree. That is the choice the user made, and the
  General footnote says the Watch always follows Nepal Time.
- A change of setting reaches the models through one registration in the app
  scene. The converter is the exception: it reads today only for the day its
  pickers start on, and a later change does not move a selection the user may
  have made.
- Dates a user names for conversion are unaffected. They are calendar days, not
  instants, and no time zone applies to them (CONTEXT.md, *Today*).
- "Today follows Nepal Time" is now "today follows Nepal Time by default" in
  README.md and CONTEXT.md.
