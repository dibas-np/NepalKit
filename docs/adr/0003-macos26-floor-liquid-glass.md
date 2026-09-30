# macOS 26.6 floor, designed primarily against macOS 27

**Supersedes the Q7 floor decision (macOS 14+).** Minimum deployment target is **macOS 26.6**; NepalKit is designed primarily against macOS 27, with no compatibility shims and no degraded UI paths for older systems. Apple HIG compliance is a standing principle throughout.

The floor was 26.0 when this ADR was first written and is now 26.6, which is a narrowing and therefore a product decision like any other: it drops support for 26.0 through 26.5. It was raised to match what the app target had actually been building against — see the amendment below, which records a drift this repository had no gate for.

All four `XCBuildConfiguration` blocks — the two project-level ones and the two app-target ones — state `MACOSX_DEPLOYMENT_TARGET = 26.6`. The project-level pair matters as much as the app's, because the test target inherits from it, and it was the pair left behind: the app target had been given 26.6 while the project-level configurations still said 26.0, so the test target was building against 26.0 while the app it tests required 26.6.

All four is a larger surface than the project has to keep correct, and the reason it is four rather than one is worth recording: Xcode materialises an inherited value into the target's own configuration when the value is changed in the UI, so "set it once at the project level" is not something the file preserves. `verify-deployment-floor.py` reads every occurrence, so the extra copies are checked rather than assumed consistent.

macOS 26 and 27 may render Liquid Glass materials somewhat differently; those differences are OS behavior, not something NepalKit compensates for. Test on both and treat Apple's rendering differences as expected.

## Correction: the Liquid Glass rationale

This ADR originally claimed that NepalKit "uses modern Liquid Glass-era SwiftUI APIs directly." A source audit found that it did not. There was no `glassEffect`, no `GlassEffectContainer`, and no `.glass` in the source; the only mention of Liquid Glass was a comment in `PopoverView`. The highest API availability actually used was macOS 15.

The decision is unchanged; the stated justification was inaccurate. NepalKit is a native SwiftUI application, so it inherits Liquid Glass rendering from the OS rather than requesting materials directly. The macOS 26 floor is an intentional product and platform decision, expressed as `MACOSX_DEPLOYMENT_TARGET = 26.0`, not a consequence of an API dependency. That the source happens to be macOS 26-compatible is a property worth maintaining and verifying, not the reason for the floor.

The floor therefore does not depend on any macOS 27-only API, and lowering it is not a matter of removing version checks. Changing the floor is an explicit product decision that requires its own ADR. Compatibility with macOS 26 is enforced by CI (ADR-0007).

## Amendment: glass is now requested where it is wanted

The audit above was accurate when written and is now out of date. The popover footer uses `GlassEffectContainer` and `.buttonStyle(.glass)`, so the source now does request materials directly.

The "inherits it from the OS" argument above still holds for everything else, and is the reason the amendment is narrow rather than a reversal:

- **Requested** in the popover footer only — two glass buttons, in one `GlassEffectContainer` so they share a sampling region. Glass cannot sample other glass, so adjacent glass controls need a shared container or they render inconsistently against each other.
- **Inherited** everywhere else. The settings window, the forms, the segmented pickers and the menu-bar item all take their appearance from the OS, which is the right default: a `Form` full of glass controls is neither conventional on macOS nor what the platform's own Settings does.

Why the footer specifically. Both its buttons carried `.buttonStyle(.plain)`, which strips a button's visual treatment entirely — no background, no border, no material. That read as deliberate when the footer held three symbol-and-text pairs and wrong once it held one bare glyph and one word: the controls stopped looking like controls. `.glass` restores the affordance and, being an OS-drawn material, tracks the user's appearance and contrast settings, which a hand-built background would not.

This is consistent with the floor rather than in tension with it. `.glass`, `GlassEffectContainer` and `.glassProminent` are all macOS 26 APIs — verified by compiling against the floor SDK with no `#available` gate, which is exactly the property ADR-0007's CI job checks. Nothing here is gated above the floor, so no availability check is needed anywhere.

Note for the next audit: `Glass` has no `.prominent`. Emphasis is `.regular.tint(_:)` with an opacity. The footer deliberately uses `.glass` rather than `.glassProminent` on both buttons — Quit is the less likely of the two actions and tinting it would outrank Settings for someone who opened the app to read a date.

## Amendment: the floor had drifted, and the feed followed it wrongly

Raising the floor to 26.6 exposed a live bug rather than merely a stale number.

The app target had been building at `MACOSX_DEPLOYMENT_TARGET = 26.6` while the two
project-level configurations still said 26.0, and `package-release.sh` — the value
`verify-appcast.py` reads as "the app's floor" — said 26.0 as well. So the
built app carried `LSMinimumSystemVersion = 26.6` while the published feed
declared `<sparkle:minimumSystemVersion>26.0` on all three items, and the
verifier reported `minimumSystemVersion 26.0 matches the app's floor` and
`Appcast is sound.`

**That combination is the bug**: Sparkle offers an update to any system whose
version is at or above the item's declared minimum, so macOS 26.0 through 26.5
were being offered an update to a build that cannot launch there. The gate was
green because it compared the feed against a *declared* floor that had drifted
from the real one — the same failure mode as a control that is never exercised,
just with a number instead of a control.

Two things had to move together, and only one of them was code:

- `MACOSX_DEPLOYMENT_TARGET` in all four configurations, and
  `DEPLOYMENT_TARGET` in `package-release.sh`, are now 26.6. The verifier
  derives its answer from the latter, so the two cannot now disagree.
- The published `appcast.xml` was re-declared at 26.6 and **re-signed**. Editing
  the feed invalidates its signature — the same ordering constraint as any other
  feed change, for the same reason: `sign_update` signs the exact bytes it is
  handed.

The standing gap this leaves had a gate written for it, and now has one.
`verify-appcast.py` cannot read the floor from the source tree at all, because a
source `Info.plist` carries the unexpanded `$(MACOSX_DEPLOYMENT_TARGET)` token; it
reads `package-release.sh` instead. That indirection is a single point of failure,
and nothing gated it — the build's own floor could drift from the release
script's without anything failing, which is precisely what happened.

`scripts/verify-deployment-floor.py` closes it. It compares the *sources* against
each other — every `XCBuildConfiguration`, `package-release.sh`, and the
`LSMinimumSystemVersion` of a built product when one is available — so the
declared number is the thing under test rather than the premise. It is the last
gate in `check-all.sh`, which builds first so the product is there to compare, and
it runs in `pages.yml` before the feed check that trusts the floor. Eighteen
tests cover it, including a negative control per drift shape; the one that
reproduces this bug sets a project-level configuration back to 26.0 and asserts
the gate fails and names the line.

The point of the gate is the one the drift teaches: a check that compares a
declared value against another declared value cannot detect that both are wrong.
`verify-appcast.py` will keep reporting "matches the app's floor" as long as the
feed and the release script agree, even if the app targets something else
entirely. Comparing the sources is the only form of this check that can fail.
