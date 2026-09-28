# Settings is presented by the native scene; opening it must establish focus

**Answers the ticket 01 spike. Governs ticket 05, and ticket 06 by inheritance.**

NepalKit is a menu-bar-only app: `LSUIElement`, activation policy `.accessory`,
no Dock icon, no Cmd-Tab presence, and no application menu in the menu bar. The
open question was whether a native SwiftUI `Settings` scene can be reached and
used at all in that shape, or whether a controlled window or panel presented
from the popover is required instead.

**Decision: present Settings with the native `Settings` scene, opened through
SwiftUI's own `SettingsLink` / `openSettings`.** Those are the supported
abstractions for exactly this architecture, and no hand-built window or panel is
needed. What the spike established is that this is not sufficient on its own:
**opening a normal application window from NepalKit's context does not, by
itself, establish application activation or focus.** The window appears on
screen and is not key.

This record deliberately stops short of naming the activation call or its
sequencing. That is ticket 05's to implement and measure; this decision fixes the
architecture and the requirement, not the mechanism.

## The rule this generalises to

> **Any command that opens a normal application window from NepalKit's
> menu-bar-only context must explicitly establish application activation and
> focus.**

About (ticket 06) is not a second architecture. It obeys the same rule, and the
two should share one small behaviour rather than each growing its own ad-hoc
activation call.

## What was measured

The spike declared a placeholder `Settings` scene and a `SettingsLink` in the
popover, then ran the **real `.app` bundle** launched through LaunchServices —
not a preview, and not the SwiftPM harness, because activation policy is itself
part of what is under test. A throwaway probe recorded observations to JSON. The
probe was discarded afterwards; the decision is the deliverable.

Two routes were measured separately, both reaching the same declared scene:

| Route | Window opened | App active | Window is key |
| --- | --- | --- | --- |
| AppKit app-menu `Settings…` item | yes | no | no |
| SwiftUI `openSettings` (what `SettingsLink` dispatches) | yes | no | no |

Both put the window on screen. Neither activates the app: `NSApp.keyWindow` is
`nil`, `NSApp.isActive` is `false`, and another application is still frontmost.
`canBecomeKey` is `true`, so the window is focusable — it simply is not focused.
Granting activation afterwards does make it key, active, and frontmost, with the
window on the active space, so the requirement is satisfiable rather than a dead
end. The first responder is the window itself rather than a control inside it, so
a keyboard user presses Tab to descend into the form.

Lifecycle survives opening and closing: `performClose` hides the window, and
re-opening brings back the same window rather than creating a second one. The
close-then-reopen failure mode does not occur, and the process and menu-bar item
are unaffected.

No Dock icon and no Cmd-Tab entry: `activationPolicy: accessory` with
`LSUIElement`, asserted by macOS rather than by us, and the app was never
observed to become frontmost spontaneously.

## Negative finding: `showSettingsWindow:` is dead

Kept because it is a trap, not because it is a route.

`NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)` — the
selector widely used to open a Settings window programmatically — **returns
`true` and does nothing.** A minimal control app with `WindowGroup` +
`Settings` showed no Settings window through it either; performing the action of
the app menu's `Settings…` item on the same app did open one.

The first measurement in this spike used that selector, concluded "the Settings
scene never opens", and was wrong.

**The methodological lesson, which outlives the specific API:** never validate a
UI surface through a private or legacy mechanism when the trigger itself is part
of what you are testing. A broken trigger measures the probe, not the product,
and — because it returns `true` rather than failing — it reports a confident
negative. Verify any probe's trigger against a known-good control first.

## Do not use the deprecated activation API

The spike reached for `activateIgnoringOtherApps: true`. Do not copy that into
production. `NSApp.activate()` is the current API and Apple's own deprecation
message names it; the floor is macOS 26, well past its macOS 14 introduction.
The old spelling is not merely discouraged in Swift — it does not compile:
`activateIgnoringOtherApps` "has been renamed to `activate(ignoringOtherApps:)`"
and "was obsoleted in Swift 3", and the underlying method carries
`API_DEPRECATED` reading "Use NSApp.activate instead." Apple also cautions
generally against stealing focus, so any activation is to be scoped to the
moment the user has asked for a window, not applied opportunistically.

## Still needs human eyes

Recorded rather than claimed as verified, because the probe cannot reach them:

- **Clicking the actual `SettingsLink` in the popover.** System Events has no
  assistive access in the development environment. What was verified is the
  action the control dispatches, driven directly — not a literal click. The
  residual risk is the popover hosting a usable control; its own window reports
  `canBecomeKey: false`.
- **Window position.** The Settings window opened at bounds `X: -1170` on the
  machine used, consistent with a display left of the origin. Placement on a
  single-display setup is unverified and should be eyeballed.
- **Whether fronting a normally-invisible app feels right in practice.** It is
  required for the window to be usable at all, and it is what opening Settings
  does in a normal app, so it is expected — but it is a visible state change
  for an app that is otherwise invisible.

## Considered Options

**A controlled `WindowGroup` or `NSPanel` presented from the popover.** Rejected.
It would work and can be made to activate predictably, but the native scene
already provides the chrome, the lifecycle, and correct reopen behaviour.

**Declare the `Settings` scene and open it without establishing focus.**
Rejected: this is the failure the ticket names — a window that opens but cannot
take focus. Keyboard navigation would be broken for every user, and ticket 08
makes VoiceOver correctness a release gate.

**Give the app a real menu bar, abandoning `LSUIElement`.** Rejected. The
menu-bar-only shape is the product. Note that the app menu already exists in the
bundle and already carries both `Settings…` and `About NepalKit`; it is simply
unreachable from the menu bar, which is the constraint this decision accepts
rather than one it tries to remove.
