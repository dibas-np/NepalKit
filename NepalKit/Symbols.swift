// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation

/// Every SF Symbol the app uses, named once.
///
/// Centralised so an unresolvable name fails the suite rather than rendering as
/// *nothing* with no error and no fallback. `SymbolTests` resolves every name in
/// `all`, and `all` is meant to list exactly what the app renders — an entry no
/// view can reach is dead weight that still looks maintained.
///
/// A symbol earns its place by reinforcing its label, not decorating it, so each
/// pairing is written down with the reasoning. That is what caught `person`
/// beside "Local", which reads as a user account rather than a place, and it is
/// why the popover's clock rows use typographic labels instead: "Nepal Time" and
/// "Local" are short enough that a glyph beside them is decoration, and a glyph
/// that differs only in a detail the reader must decode is worse than none.
///
/// Per ADR-0004 rendering mode is chosen per surface for contrast against Liquid
/// Glass; the remaining symbols are all monochrome inline icons beside text.
enum Symbols {
    /// "Launch at login" — the conventional glyph for run-at-startup.
    static let launchAtLogin = "power"

    /// "Settings…" — the standard macOS Settings glyph.
    static let settings = "gearshape"

    /// "About NepalKit" — the standard macOS information glyph.
    static let about = "info.circle"

    /// "Menu Bar" — the Settings sidebar row for the menu-bar item's own
    /// appearance. The glyph is the menu bar itself rather than a clock, because
    /// what the tab governs is the item's presence and format, not the time.
    static let menuBar = "menubar.rectangle"

    /// "General" — the remaining preferences. Deliberately *not* `gearshape`:
    /// that glyph is the Settings button in the popover footer, and putting the
    /// same gear on a row inside Settings would read as "the settings for these
    /// settings". Sliders say "adjustable preferences" and stay distinct.
    static let general = "slider.horizontal.3"

    /// "Source repository" — the conventional source-control glyph, beside the
    /// word "Source" in the identity strip along the bottom of the Settings
    /// window. The word carries the meaning; the glyph marks it as a link.
    static let repository = "chevron.left.forwardslash.chevron.right"

    static let all: [String] = [
        launchAtLogin, settings, about, menuBar, general, repository
    ]
}
