# Changelog

Notable changes per released version. The same notes, formatted for the
update alert, live at `scripts/release-notes/<version>.html` and ship in
the [appcast](https://dibas-np.github.io/NepalKit/appcast.xml).

## 1.1 — 2026-09-29

### Features

- The popover is redesigned around the date: the Bikram Sambat date is the hero, shown large with the Gregorian date and weekday beneath it, and Today and Convert are now equal tabs — opening the popover to read the date no longer also presents three pickers and a conversion result.
- A header bar carries the app name and the live Nepal Time clock.
- A footer bar carries where you are on the left, and Settings, About and Quit on the right.
- The local-time clock appears only when the local zone actually differs from Nepal Time. Two identical clocks said nothing.
- Switching tabs cross-fades instead of replacing the content.

### Fixes

- Updates install. The app was missing the Sparkle key a sandboxed app needs to launch its installer, so every in-app update aborted with an authorization error and the DMG was the only way in. From this version automatic updates work, and the update alert shows release notes.
- About now states that the licence covers the app code, and that the bundled calendar data carries no licence from this project.
- The once-a-second clock tick re-renders only the parts of the popover that show live time, and clock formatting reuses its calendar instead of rebuilding it every second.

Note for 1.0: this version fixes the updater itself, so a 1.0 install cannot update in place — install 1.1 from the DMG this once. Automatic updates work from 1.1 onward.

## 1.0 — 2026-09-28

### New

- First release: today's Bikram Sambat date in the menu bar, with a popover carrying the full date, the Gregorian day beside it, and a Nepal Time clock anchored to UTC+5:45 regardless of the system time zone.
- A bounded Bikram Sambat ↔ Gregorian converter: day pickers follow the real month lengths and the dataset's supported range, so an invalid date cannot be picked.
- Launch at login on by default, digits in Latin or Devanagari, and month names in Nepali or transliterated — set once in Settings.
