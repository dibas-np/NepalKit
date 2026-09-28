import AppKit
import Testing
@testable import NepalKit

/// An unresolvable SF Symbol name renders as *nothing at all* — no error, no
/// fallback, no warning. A typo is therefore invisible to the compiler and to
/// every other test, and only shows up when a human looks at the screen. These
/// tests turn that silent failure into a suite failure.
///
/// The second half is the part that cannot be automated: whether a symbol
/// reinforces its label is a design judgement. It is recorded as a comment on
/// each name in `Symbols` so it is reviewable, not asserted here.
@MainActor
struct SymbolTests {
    @Test func everySymbolResolves() {
        for name in Symbols.all {
            #expect(
                NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
                "\(name) does not resolve and would render as nothing"
            )
        }
    }

    @Test func symbolsAreDistinct() {
        // Two names that collapse to the same glyph would silently lose the
        // distinction they exist to make.
        #expect(Set(Symbols.all).count == Symbols.all.count)
    }

    @Test func localTimeUsesAPlaceSymbolNotAPerson() {
        // The regression: `person` beside "Local" read as a user or account,
        // which is a different concept than the label. This pins the fix.
        #expect(Symbols.localTime == "location")
        #expect(Symbols.localTime != "person")
    }

    @Test func theTwoClockRowsAreOpticallyMatched() {
        // A clock and a place marker only pair well if they sit at the same
        // size, or one row visibly outweighs the other. Verified against the
        // real symbol set at the size the popover renders them.
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        let size = { (name: String) -> CGSize in
            NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config)?.size ?? .zero
        }
        let nepal = size(Symbols.nepalTime)
        let local = size(Symbols.localTime)

        #expect(nepal == local, "\(Symbols.nepalTime) is \(nepal) but \(Symbols.localTime) is \(local)")
    }
}
