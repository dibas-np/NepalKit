# macOS 26+ floor, designed primarily against macOS 27

**Supersedes the Q7 floor decision (macOS 14+).** Minimum deployment target is macOS 26 (Tahoe); NepalKit is designed primarily against macOS 27, with no compatibility shims and no degraded UI paths for older systems. Apple HIG compliance is a standing principle throughout.

macOS 26 and 27 may render Liquid Glass materials somewhat differently; those differences are OS behavior, not something NepalKit compensates for. Test on both and treat Apple's rendering differences as expected.

## Correction: the Liquid Glass rationale

This ADR originally claimed that NepalKit "uses modern Liquid Glass-era SwiftUI APIs directly." A source audit found that it does not. There is no `glassEffect`, no `GlassEffectContainer`, and no `.glass` in the source; the only mention of Liquid Glass is a comment in `PopoverView`. The highest API availability actually used is macOS 15.

The decision is unchanged; the stated justification was inaccurate. NepalKit is a native SwiftUI application, so it inherits Liquid Glass rendering from the OS rather than requesting materials directly. The macOS 26 floor is an intentional product and platform decision, expressed as `MACOSX_DEPLOYMENT_TARGET = 26.0`, not a consequence of an API dependency. That the source happens to be macOS 26-compatible is a property worth maintaining and verifying, not the reason for the floor.

The floor therefore does not depend on any macOS 27-only API, and lowering it is not a matter of removing version checks. Changing the floor is an explicit product decision that requires its own ADR. Compatibility with macOS 26 is enforced by CI (ADR-0007).
