# macOS 26+ floor, Liquid Glass-first on macOS 27

**Supersedes the Q7 floor decision (macOS 14+).** Minimum deployment target is macOS 26 (Tahoe); NepalKit is designed primarily against macOS 27 and uses modern Liquid Glass-era SwiftUI APIs directly, with no compatibility shims or degraded UI paths. Apple HIG compliance is a standing principle throughout.

macOS 26 and 27 may render Liquid Glass materials somewhat differently; those differences are OS behavior, not something NepalKit compensates for. Test on both and treat Apple's rendering differences as expected.
