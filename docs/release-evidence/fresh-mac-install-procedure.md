# Fresh-Mac install test — procedure

Ticket 11's gate. Run this on a Mac that **has never trusted the developer**:
a different user account is not enough, and neither is a CI runner, because
both already have a trust relationship and would pass more easily.

Everything else in this repository was verified on a machine that already has
the signing certificate installed. That is precisely why this gate exists: the
build can be correctly signed and still be uninstallable by a person who has
never seen it.

## Before you start

You need two things, and only the first is a technical task:

1. **The candidate.** `scripts/package-release.sh` produces a signed,
   notarized, stapled `.dmg`. It needs `TEAM_ID`, `APPLE_ID` and
   `APP_SPECIFIC_PASSWORD`; the app-specific password is created at
   <https://account.apple.com>. The app is **not** published publicly while
   being tested — use AirDrop, a USB stick, or any transfer that is not a
   public download link.
2. **A Mac you have not touched.** Prefer one **not** on the current macOS
   release, so this gate and the deployment-floor gate (ticket 04) test
   different things rather than duplicating each other.

## Do not

- Do not right-click → Open, and do not use "Open Anyway" in the Gatekeeper
  dialog. **A warning that requires a workaround is a failure**, even if the app
  then launches. The workaround is the bug.
- Do not copy a local `.app` across. That tests the copy, not the distribution.
- Do not install the certificate used to sign it.

## Procedure

Work in order. Each step assumes the previous one passed.

```sh
# 1. Obtain it the way a user would. Record how, and from where.
#    (AirDrop, USB, private link — not a public release URL.)

# 2. Check what you are about to run, before opening it.
codesign -dv --verbose=4 ~/Downloads/NepalKit-1.0.dmg 2>&1 | head -20
hdiutil imageinfo ~/Downloads/NepalKit-1.0.dmg | head -5

# 3. Does it hold a stapled ticket? This must succeed offline.
xcrun stapler validate ~/Downloads/NepalKit-1.0.dmg

# 4. Mount and install by dragging to Applications.
open ~/Downloads/NepalKit-1.0.dmg
# drag NepalKit.app to /Applications, then eject

# 5. Gatekeeper, with no special instructions.
spctl -a -t execute -vvv /Applications/NepalKit.app
#    expect: accepted, source=Notarized Developer ID
#    "Unnotarized Developer ID" here is a failure, not a warning

# 6. Does it run at all?
open /Applications/NepalKit.app
```

Then, in the app itself:

- [ ] The menu-bar item appears, showing today's date
- [ ] The popover opens and shows today, Nepal Time, and both clocks
- [ ] The converter converts, in both directions
- [ ] Settings opens, and both display pickers take effect
- [ ] Launch at login toggles without error
- [ ] About shows the right version, dataset version, and supported range
- [ ] ⌘Q quits (with the popover open, and with it closed)
- [ ] The update check reports a status rather than failing silently

Then VoiceOver, which corroborates ticket 08 outside the development
environment — this is the one place its open gate can be closed:

- [ ] VoiceOver reads the menu-bar item: "NepalKit, <date>"
- [ ] The popover is navigable by rotor and its content is announced
- [ ] Devanagari digits are pronounced rather than skipped
- [ ] Settings' toggles announce their state; pickers announce their value
- [ ] Nothing decorative is announced, and nothing important is silent

## Finally, the uninstall path

Worth doing, because it is the path a disappointed user takes, and it catches
state that survives removal:

```sh
rm -rf /Applications/NepalKit.app
# then reinstall from the same DMG and confirm first launch is clean
```

## Record

Note the macOS version, how the file was obtained, every warning seen, and
whether any step needed a workaround. **A warning that needed one is a finding,
not an inconvenience** — write it down rather than working past it.
