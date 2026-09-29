# Changelog

Notable changes per released version. The same notes, formatted for the
update alert, live at `scripts/release-notes/<version>.html` and ship in
the [appcast](https://dibas-np.github.io/NepalKit/appcast.xml).

## 1.2 — unreleased

### Fixes

- Launch at login now behaves. macOS can put the login item into “requires approval” and ask you to confirm it in System Settings; the app read that state as “not registered”, so the toggle sprang back to off the moment you returned, with nothing on screen to explain why. Turning it on when it was already on also raised a confusing “already registered” error. Both came from the same cause: the app was not tracking the real registration state, and it told the system to re-register items it already had.
- The Local clock now follows your system time zone while the app is running. It was read once, when the app launched, so if you changed zones — travelling, or macOS updating it on its own — Local kept showing the zone you were in at launch until you restarted the app. In the worst case the row disappeared: launch in Nepal, land somewhere else, and the app still believed your local time matched Nepal Time, so it hid Local as redundant and left you with no local reference at all.
- About no longer says the bundled calendar data is “licensed separately”. No such licence exists — the data carries no licence from this project, which is what SOURCES.md has said throughout. The corrected line ships in this version.
- The popover no longer draws a doubled rule above its footer. The date area and the footer bar each carried their own separator, and they ended up directly against each other, so every popover you opened showed two lines where there should have been one. Only the redundant one is gone; the line that separates the date from the actions below it is still there.

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
