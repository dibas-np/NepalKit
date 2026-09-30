# macOS 26+ floor, designed primarily against macOS 27

**Supersedes the Q7 floor decision (macOS 14+).** Minimum deployment target is macOS 26 (Tahoe); NepalKit is designed primarily against macOS 27, with no compatibility shims and no degraded UI paths for older systems. Apple HIG compliance is a standing principle throughout.

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
