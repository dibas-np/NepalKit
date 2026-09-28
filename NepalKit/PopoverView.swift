// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI
import NepalKitCore

/// Popover: today details, converter, and a route into Settings.
///
/// Iconography (per ADR-0004): SF Symbols everywhere in the popover, with the
/// rendering mode chosen per surface — hierarchical for section headers so the
/// symbols stay legible on translucent Liquid Glass in both appearances,
/// monochrome for small inline icons so they keep full contrast next to text.
/// The menu-bar extra itself stays date text only.
struct PopoverView: View {
    let settings: DisplaySettingsModel
    let clock: ClockModel
    let converter: ConverterModel
    /// Settings open through SwiftUI's own action rather than a hand-built
    /// window; the activation half is `WindowPresentation`'s (ADR-0011).
    @Environment(\.openSettings) private var openSettings
    /// About is a named window scene, opened the same way — same activation
    /// behaviour, not a second mechanism (ADR-0011).
    @Environment(\.openWindow) private var openWindow
    /// Injected so the year named in the range boundary state is the same
    /// dataset the rest of the view reads, and so a test can control it.
    var dataset: CalendarDataset = .v2

    /// Last Bikram Sambat year the bundled dataset can convert. Named in the
    /// range boundary state so a user past it can tell a data limit from a bug.
    private var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(Strings.todayLabel, systemImage: Symbols.today)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            if let todayBS = clock.todayBSDate(in: dataset) {
                // Shown exactly as configured; announced in a form a voice can
                // pronounce. The two come from the same date, so they cannot
                // drift into describing different days.
                Text(formatBS(todayBS, settings: settings.settings))
                    .font(.headline)
                    // Label only. Adding `children: .ignore` here collapsed the
                    // element and left it with no role at all — the live tree
                    // showed `AXUnknown: 12 Ashoj 2083`, which is not something
                    // to hand a screen reader. Replacing the label on a `Text`
                    // keeps its static-text role.
                    .accessibilityLabel(
                        SpokenDate.bs(todayBS, monthNames: settings.settings.monthNames)
                    )
            } else {
                // Range boundary state: the bundled data has ended. Say so in
                // words rather than showing a blank, and keep the Gregorian date
                // and clocks below, which are still answerable.
                // One element, not two: a heading and a sub-line are two
                // separate announcements, and the second alone ("Supported
                // through 2084 BS") is meaningless without the first. Merged, and
                // given a single label, so the whole state is one sentence.
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.bsDateUnavailable)
                        .font(.headline)
                    Text(Strings.supportedThrough(lastSupportedBSYear, digits: settings.settings.digits))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(Strings.bsDateUnavailable). \(Strings.supportedThrough(lastSupportedBSYear, digits: .latin))"
                )
            }
            if let todayAD = clock.todayADDate() {
                // One date, two channels: the shown line as configured, the
                // announcement with Latin digits and the weekday folded in, so
                // the whole line is a single spoken sentence.
                let weekday = clock.weekdayString(style: settings.settings.monthNames)
                HStack(spacing: 4) {
                    Text(formatAD(todayAD, settings: settings.settings))
                    if let weekday {
                        Text("· \(weekday)")
                    }
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    SpokenDate.gregorianAnnouncement(date: todayAD, weekday: weekday)
                )
            }
            // Clocks sit outside the Gregorian conditional: they are answerable
            // regardless of calendar data, so they must survive the boundary.
            // `Label` supplies each row's title for free, but it announces that
            // title verbatim — under Devanagari that is "Nepal Time:
            // ११:४५:००", and a clock face is the one place where a misread digit
            // is not obviously wrong to the listener. So each row re-derives its
            // own time string in Latin digits, and the stack is a container that
            // leaves the two rows as separate elements rather than merging them
            // into one unreadable run.
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("\(Strings.nepalTimeLabel): \(clock.nptTimeString(digits: settings.settings.digits))")
                } icon: {
                    Image(systemName: Symbols.nepalTime)
                        .symbolRenderingMode(.monochrome)
                }
                .accessibilityLabel("\(Strings.nepalTimeLabel): \(clock.nptTimeString(digits: .latin))")
                Label {
                    Text("\(Strings.localTimeLabel): \(clock.localTimeString(digits: settings.settings.digits))")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: Symbols.localTime)
                        .symbolRenderingMode(.monochrome)
                }
                .accessibilityLabel("\(Strings.localTimeLabel): \(clock.localTimeString(digits: .latin))")
            }
            .accessibilityElement(children: .contain)
            .monospacedDigit()
            .padding(.top, 2)
        }
        .padding()
        .frame(minWidth: 280)
        Divider()
        Label(Strings.converterLabel, systemImage: Symbols.converter)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.monochrome)
            .padding(.horizontal)
            // A header, so it can be reached by heading navigation. The symbol
            // is decoration next to a word that already names the section, and
            // left in the label some voices announce it too ("arrow.triangle
            // .2.circlepath, Converter").
            // Combined into one element. A `Label` otherwise contributes its
            // own text as a separate child, and with the heading trait applied
            // the live tree exposed both `AXHeading: Converter` and
            // `AXStaticText: Converter` — the section announced twice.
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Strings.converterLabel)
            .accessibilityAddTraits(.isHeader)
        ConverterView(model: converter, settings: settings.settings)
            .padding(.horizontal)
        Divider()
        // The settings themselves live in the native Settings scene now, so
        // the popover carries one entry point instead of three inline controls.
        // Opening it must also establish activation and focus, which an
        // `LSUIElement` app does not get for free — WindowPresentation owns
        // that, and About will reuse it (ADR-0011).
        Button {
            WindowPresentation.present(open: { openSettings() })
        } label: {
            Label(Strings.settingsLabel, systemImage: Symbols.settings)
                .symbolRenderingMode(.monochrome)
        }
        .padding(.horizontal)
        .accessibilityLabel(Strings.settingsLabel)
        // About sits directly above Quit, as it does in a macOS application
        // menu. The app menu's own `About NepalKit` item is unreachable from the
        // menu bar for the same reason `Settings…` is, so this is the route.
        Button {
            WindowPresentation.present(open: { openWindow(id: AboutWindow.id) })
        } label: {
            Label(Strings.aboutLabel, systemImage: Symbols.about)
                .symbolRenderingMode(.monochrome)
        }
        .padding(.horizontal)
        .accessibilityLabel(Strings.aboutLabel)
        Divider()
        // The visible exit path for a menu-bar-only app. The matching ⌘Q lives
        // on the app's termination command group (NepalKitApp.swift) so it works
        // when the app is frontmost without the popover open; this button is the
        // discoverable control for the same action.
        Button(Strings.quitLabel, action: AppTermination.quit)
            .padding(.horizontal)
            .padding(.bottom, 4)
    }
}
