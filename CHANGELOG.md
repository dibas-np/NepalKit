# Changelog

Notable changes per released version. The same notes, formatted for the
update alert, live at `scripts/release-notes/<version>.html` and ship in
the [appcast](https://dibas-np.github.io/NepalKit/appcast.xml).

## 1.6.0 — unreleased

### Today on your Apple Watch

NepalKit now lives on your wrist. A standalone Apple Watch app shows today's Bikram Sambat date with its weekday and the corresponding Gregorian date for the Nepal Time day — offline, independent of your Mac and iPhone, and anchored to Nepal Time whatever time zone the watch is in.

- Four complication styles for your watch face — rectangular, inline, circular, and corner — each showing today's Bikram Sambat date at a glance.
- Tapping any complication opens Today on the watch.
- VoiceOver announces the full date with Latin digits and transliterated month names that every voice reads, and includes the Gregorian date wherever it is shown.
- The complications' dates are scheduled ahead on Nepal Time midnights, so the date rolls over on its own; the exact refresh moment is the system's to choose.
- Requires watchOS 26 or later. The Watch app installs on your watch from Xcode for now; the Mac DMG installs only the macOS app.

### Calendar data, carefully sourced

The bundled dataset is now version 2.0.1. Bikram Sambat 2084 remains projected: no official publication confirms the year yet, and 1.6.0's revised 2084 month lengths follow the cross-checked sources, so conversions inside 2084 may differ from 1.5.0. Read SOURCES.md for provenance and what is still outstanding.

### Fixes

- The popover's live clock ticks only while the popover is visible, so the app sits quieter on your Mac in the background.
- Shortcuts date entities derive their weekday from the shared calendar engine, keeping Siri and Shortcuts answers consistent with the app.

## 1.5.0 — 2026-10-01

### Siri and Shortcuts support

Ask Siri, "What is today's Nepali date with NepalKit" to hear today's Bikram Sambat date and weekday. Today's date follows Nepal Time.

- Convert dates between Gregorian and Bikram Sambat using new Shortcuts actions.
- Gregorian-to-Bikram Sambat conversion returns year, month, day, and weekday fields for use in your shortcuts. Conversion to Gregorian returns a standard date.
- Spoken answers use Latin digits and your chosen month-name language. Bikram Sambat date labels in Shortcuts follow your display settings, including Devanagari digits.
- Unsupported dates report the supported range. Invalid Bikram Sambat dates report the month's actual length.
- Find the available phrases in Settings, General, Siri & Shortcuts.

Siri supports today's date query. Use Shortcuts for date conversions, as Siri cannot yet reliably collect conversion parameters by voice.

## 1.4.1 — 2026-09-30

### The update channel is signed end to end.

- The update feed itself now carries a signature, and NepalKit refuses a feed without one. Until now the app verified every download but trusted the feed that named it; both are checked now, so a tampered feed cannot point an installation at anything other than a signed archive.

### Settings

- The Settings window is rebuilt around the system tab sidebar — Menu Bar, General, and About. About is no longer a separate window: what it showed sits on the About tab, beside the update controls that used to be their own Settings section. The popover's footer carries the gear and Quit, and its buttons take the new Liquid Glass treatment.

### Fixes

- The hero date, the large Bikram Sambat line at the top of the popover, now scales with the user's text size, as every other line in the app already did.

### Requirements

- NepalKit now requires macOS 26.6, up from 26.0. Installs on 26.0 to 26.5 keep working on 1.3.0 and are not offered this update.
- The bundled updater is Sparkle 2.10.0.

## 1.4.0 — 2026-09-30

### The update channel is signed end to end.

- The update feed itself now carries a signature, and NepalKit refuses a feed without one. Until now the app verified every download but trusted the feed that named it; both are checked now, so a tampered feed cannot point an installation at anything other than a signed archive.

### Settings

- The Settings window is rebuilt around the system tab sidebar — Menu Bar, General, and About. About is no longer a separate window: what it showed sits on the About tab, beside the update controls that used to be their own Settings section. The popover's footer carries the gear and Quit, and its buttons take the new Liquid Glass treatment.

### Fixes

- The hero date, the large Bikram Sambat line at the top of the popover, now scales with the user's text size, as every other line in the app already did.

### Requirements

- NepalKit now requires macOS 26.6, up from 26.0. Installs on 26.0 to 26.5 keep working on 1.3.0 and are not offered this update.
- The bundled updater is Sparkle 2.10.0.

## 1.3.0 — 2026-09-30

### Nothing in the app itself has changed.

This release exists because how NepalKit is numbered and installed changed, not because anything you can see or use did. If you are already on 1.2, there is no reason to take this one.

### Install

- NepalKit can now be installed with Homebrew, from the project’s own tap: brew install --cask dibas-np/tap/nepalkit. Pick that or the DMG, not both — Homebrew installs to the same place NepalKit does, and while Homebrew is told the app updates itself (so it will not reinstall over one that has moved forward), a Sparkle update after a Homebrew install leaves the two disagreeing about which version is installed.

### Numbering

- Versions now read three components — 1.3.0, not 1.3. The About window, the Git tag, and the Homebrew cask all show the same number because they are all derived from one value. Releases 1.0 to 1.2 keep the numbers they shipped with; their tags and downloads are not rewritten.

## 1.2 — 2026-09-29

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
