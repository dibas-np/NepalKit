// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI

/// The bar along the bottom of the popover: the selected destination on the left,
/// the two actions on the right.
///
/// This follows the reference layout, where the footer names where you are on the
/// left and puts the actions on the right. Naming the destination here is what the
/// segmented control's selection does not say on its own when the popover is read
/// as a whole: the control is a control, and this is the surface's own statement
/// of position.
///
/// Its own view type rather than a computed property on `PopoverView`, which is
/// both the house rule (AGENTS.md:118) and the cheaper arrangement: this reads
/// `destination` and the two actions, none of the clock, so a per-second tick
/// never re-evaluates it.
struct PopoverFooter: View {
    let destination: PopoverDestination
    /// Passed in rather than read from the environment here, so this type depends
    /// on the action and not on how the popover happens to reach Settings.
    let openSettings: () -> Void

    var body: some View {
        // The container is a wrapping view, not a modifier — it has to *be* the
        // parent of the content it groups.
        //
        // It wraps the whole footer rather than just the two buttons, so the
        // destination label sits inside the same sampling region and the buttons'
        // refraction of the text beside them is consistent. `spacing` matches the
        // `HStack` inside, which is what makes the grouping read as one group
        // rather than two objects that happen to be near each other.
        //
        // Glass refracts light by sampling content from an area larger than itself,
        // and glass cannot sample other glass — so two glass buttons left in
        // separate containers render inconsistently against each other, which on a
        // two-button bar shows as the pair disagreeing about their background.
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    Text(destination.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    settingsButton
                    quitButton
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    /// Settings, as a bare gear.
    ///
    /// Icon only, because the gear is the conventional mark for this action on
    /// macOS and the words buy nothing beside it in a 340pt bar.
    ///
    /// `.labelStyle(.iconOnly)` rather than a bare `Image`. Apple's guidance is to
    /// keep the title on the label and drop it visually, so the name survives in
    /// the accessibility tree instead of being re-attached by hand: a label that is
    /// only an image has no name of its own, and the documented alternative to a
    /// hand-written `.accessibilityLabel` is not to discard the title in the first
    /// place. It is also what lets this button render correctly if it is ever moved
    /// into a toolbar or a menu, where SwiftUI decides whether to show the title.
    private var settingsButton: some View {
        Button(Strings.settingsLabel, systemImage: Symbols.settings) {
            WindowPresentation.present(open: openSettings)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .font(.caption)
        .symbolRenderingMode(.monochrome)
        // The title keeps its ellipsis, which marks an action that continues past
        // this surface. That is a visual affordance and reads as nothing aloud, so
        // the announcement drops it.
        .accessibilityLabel(Strings.settingsLabelSpoken)
        .accessibilityHint(Strings.settingsHelp)
    }

    /// Quit, as text.
    ///
    /// It keeps its text because it is the only action in a menu-bar-only app that
    /// ends the process, and the one a first-time user most likely to hunt for.
    /// There is no conventional glyph for it, so a glyph here would be decoration
    /// standing in for the one label in this footer that has to be unmistakable.
    ///
    /// Shown short. `Strings.quitLabel` names the app because the app menu needs
    /// to ("Quit NepalKit"); inside the app's own popover the name is already on
    /// screen in the header two lines up, so the footer says only "Quit" and gives
    /// the width back to the destination label. The announcement keeps the full
    /// name.
    ///
    /// The ⌘Q shortcut lives on the app's termination command group
    /// (NepalKitApp.swift) so it works when the app is frontmost without the
    /// popover open. This is the discoverable control for the same action.
    ///
    /// `.glass`, not `.glassProminent`. Prominent glass is for the one action a
    /// surface wants you to take; Quit is the less likely of the two, and tinting
    /// it would outrank Settings for someone who opened the app to read a date. It
    /// being the only control that ends the process argues for it being
    /// unmistakable — which is carried by the text and the hint, not by making the
    /// process-ending one the visually louder of the pair.
    private var quitButton: some View {
        Button(Strings.quitFooterLabel, action: AppTermination.quit)
            .buttonStyle(.glass)
            .font(.caption)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Strings.quitLabel)
            .accessibilityHint(Strings.quitHelp)
    }
}
