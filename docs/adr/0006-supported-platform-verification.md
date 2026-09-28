# Supported-platform verification: macOS 26 functional floor, macOS 27 design target

Refines ADR-0003. Verification is two-tier. macOS 26, the deployment floor, is a functional and stability release gate: NepalKit launches, does not enter the known runaway launch loop, shows the menu-bar item, opens the popover, navigates, and neither crashes nor pegs the CPU. macOS 27 is the primary design and rendering verification target, where pixel-level judgement matters. Pixel-for-pixel parity on 26 is not required — ADR-0003 already treats material rendering differences as OS behavior.

The split exists because the two failure classes are not equal. A runaway launch loop on your own stated floor is a shipping defect that affects every user on that OS; glyph and material differences are cosmetic and expected. It matters concretely here because the `TimelineView`-in-`MenuBarExtra` workaround at `MenuBarModel.swift:6` was found on 27's SwiftUI, and whether 26's older SwiftUI needs it at all is untested.

Not having a macOS 26 environment is a release-blocking evidence gap, not an accepted unknown. Release waits on a recorded 26 run; the full acceptance list is in the v1 spec.
