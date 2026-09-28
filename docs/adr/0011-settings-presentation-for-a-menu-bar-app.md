# Settings is presented by the native scene, opened with an explicit activation

**Answers the ticket 01 spike. Governs ticket 05, and the same question in
ticket 06.**

NepalKit is a menu-bar-only app: `LSUIElement`, activation policy `.accessory`,
no Dock icon, no Cmd-Tab presence, and no application menu in the menu bar. The
open question was whether a native SwiftUI `Settings` scene can be reached and
used at all in that shape, or whether a controlled window or panel presented
from the popover is required instead.

**Decision: use the native `Settings` scene.** It opens reliably and takes focus
reliably — but only because the app activates itself explicitly. Opening alone is
not enough, and that is the whole finding.

## What was measured, and how

The spike declared a placeholder `Settings` scene and a `SettingsLink` in the
popover, then ran the **real `.app` bundle** launched through LaunchServices, not
a preview and not the SwiftPM harness. A throwaway probe recorded observations
to JSON. Activation policy is part of what is under test, so only the real
bundle can answer it. The probe was thrown away afterwards; the decision is the
deliverable.

Three routes to the scene were measured separately:

| Route | Window opened | App active | Window is key |
| --- | --- | --- | --- |
| AppKit app-menu `Settings…` item | yes | no | no |
| SwiftUI `openSettings` (what `SettingsLink` dispatches) | yes | no | no |
| …then `NSApp.activate(ignoringOtherApps: true)` | — | **yes** | **yes** |

So both routes open the window and neither activates the app. The window appears
on screen, `canBecomeKey` is `true`, and it is *not* key: `NSApp.keyWindow` is
nil and another app is still frontmost. A single explicit
`NSApp.activate(ignoringOtherApps: true)` afterwards makes the app frontmost,
makes the window key, and puts it on the active space. The first responder is the
window itself rather than a control inside it, so a keyboard user presses Tab to
descend into the form.

Ticket 05 must therefore pair `openSettings()` with an explicit activation. The
native scene is still the right choice over a custom panel: it gives standard
Settings chrome, standard window behaviour, and standard close-then-reopen
semantics, with no window controller to maintain.

## What was measured to trust the measurement

Two controls were run, because the first measurement was wrong and nearly
recorded a false finding.

`NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` — the
selector widely used to open Settings programmatically — **returns `true` and
does nothing.** It is dead on current macOS. A minimal control app with
`WindowGroup` + `Settings` showed no Settings window through it either. The
route that works is performing the action of the app menu's `Settings…` item, and
for SwiftUI the `openSettings` environment action. Any future spike that pokes at
the settings machinery should verify its trigger against a known-good control
first, or it will measure its own broken probe.

The `activationPolicy: accessory` result is asserted by macOS rather than by us:
`.accessory` apps are in neither the Dock nor Cmd-Tab, and the app was never
observed to become frontmost spontaneously. No Dock icon and no Cmd-Tab entry.

## Lifecycle

Opening and closing survives. `performClose` hides the window; re-opening brings
back the same window rather than creating a second one, so the
close-then-reopen failure mode the ticket warned about does not occur. The
process stays running and the menu-bar item is unaffected.

## Still needs human eyes

Recorded here rather than claimed as verified, because the probe cannot reach
them:

- **Clicking the actual `SettingsLink` in the popover.** System Events has no
  assistive access in the development environment. What was verified is the
  action both routes dispatch, driven directly — not a literal click on the
  control. The residual risk is the popover hosting a usable control, and the
  menu-bar popover's own window reporting `canBecomeKey: false`.
- **Window position.** The Settings window opened at bounds `X: -1170` on the
  machine used, consistent with a display to the left of the origin. On-screen
  placement on a single-display setup is unverified and should be eyeballed.
- **Whether yanking the app frontmost on open is acceptable** in practice. It is
  required for the window to be usable at all, and it is what a normal app does
  when opening Settings, so it is expected — but it is a visible state change for
  an app that is otherwise invisible.

## Considered Options

**A controlled `WindowGroup` or `NSPanel` presented from the popover.** Rejected
as the primary approach. It would work, and it can be made to activate
predictably, but it means hand-building the chrome, the window lifecycle, and the
reopen behaviour that the native scene already provides correctly.

**Declare the `Settings` scene and open it without activating.** Rejected: this
is the failure the ticket names — a window that opens but cannot take focus.
Keyboard navigation would be broken for every user, and ticket 08 makes
VoiceOver correctness a release gate.

**Give the app a real menu bar, abandoning `LSUIElement`.** Rejected. The
menu-bar-only shape is the product: a Dock icon and Cmd-Tab presence are not
wanted. The app menu already exists in the bundle and already contains
`Settings…` and `About NepalKit`; it is simply not reachable from the menu bar,
which is exactly the constraint this decision accepts.
