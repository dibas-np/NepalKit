// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import SwiftUI
import NepalKitCore

/// Which of the popover's two destinations is showing.
///
/// Today and Convert are peers, so they are named as a segmented control rather
/// than as one screen with a section stapled to the bottom. The alternative made
/// the popover a single long scroll in which the converter was always expanded,
/// so opening it to read the date also presented three pickers and a result the
/// reader did not ask for.
enum PopoverDestination: String, CaseIterable {
    case today
    case convert

    var title: String {
        switch self {
        case .today: Strings.todayLabel
        case .convert: Strings.converterLabel
        }
    }
}

/// Popover: today's date, the converter, and routes into Settings and About.
///
/// Iconography (per ADR-0004): SF Symbols throughout, with the rendering mode
/// chosen per surface — hierarchical where a symbol carries meaning on its own,
/// monochrome for small inline icons so they keep contrast beside text. The
/// menu-bar extra itself stays date text only.
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
    /// Ephemeral by design: the popover closes on every activation, so a
    /// remembered selection would open onto Convert after a read of the date and
    /// back onto Today after a conversion, with no predictability. Today is the
    /// resting state because it is what the menu-bar item just showed.
    @State private var destination: PopoverDestination = .today

    /// Last Bikram Sambat year the bundled dataset can convert. Named in the
    /// range boundary state so a user past it can tell a data limit from a bug.
    private var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }

    /// One width for both destinations, so switching tabs does not resize the
    /// popover under the pointer. Fixed rather than a minimum because the
    /// converter's pickers are the widest content; a minimum would let the Today
    /// screen shrink narrower than they do.
    private static let popoverWidth: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $destination) {
                ForEach(PopoverDestination.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            // The control is untitled and the label hidden, but that is not the
            // same as unlabelled: without this the two segments announce only
            // "Today" and "Convert" with no indication that they are a choice
            // between views. `AXRadioGroup` is what a segmented control is.
            .accessibilityLabel(Strings.popoverDestinationsLabel)
            .accessibilityElement(children: .contain)

            switch destination {
            case .today: today
            case .convert:
                ConverterView(model: converter, settings: settings.settings)
            }
        }
        .padding()
        .frame(width: Self.popoverWidth)

        Divider()

        // Settings, About and Quit live below the content rather than inside
        // either destination. They open other windows or end the process, so
        // they are not a step in navigating Today and Convert, and burying them
        // in one tab would hide them from the other.
        VStack(alignment: .leading, spacing: 2) {
            Button {
                WindowPresentation.present(open: { openSettings() })
            } label: {
                Label(Strings.settingsLabel, systemImage: Symbols.settings)
                    .symbolRenderingMode(.monochrome)
            }
            .accessibilityLabel(Strings.settingsLabel)

            // About sits directly above Quit, as it does in a macOS application
            // menu. The app menu's own `About NepalKit` item is unreachable from
            // the menu bar for the same reason `Settings…` is, so this is the route.
            Button {
                WindowPresentation.present(open: { openWindow(id: AboutWindow.id) })
            } label: {
                Label(Strings.aboutLabel, systemImage: Symbols.about)
                    .symbolRenderingMode(.monochrome)
            }
            .accessibilityLabel(Strings.aboutLabel)

            // The visible exit path for a menu-bar-only app. The matching ⌘Q lives
            // on the app's termination command group (NepalKitApp.swift) so it works
            // when the app is frontmost without the popover open; this is the
            // discoverable control for the same action.
            Button(Strings.quitLabel, action: AppTermination.quit)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    // MARK: - Today

    private var today: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(Strings.todayLabel, systemImage: Symbols.today)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
                // A heading, so it can be reached by heading navigation, and
                // combined into one element: a `Label` otherwise contributes its
                // own text as a separate child, so the live tree exposed both
                // `AXHeading: Today` and `AXStaticText: Today`.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Strings.todayLabel)
                .accessibilityAddTraits(.isHeader)

            if let todayBS = clock.todayBSDate(in: dataset) {
                // The hero. Weight is what makes the date the first thing read
                // rather than a value sitting beside its own label; everything
                // below steps down from it.
                //
                // Shown exactly as configured; announced in a form a voice can
                // pronounce. The two come from the same date, so they cannot
                // drift into describing different days.
                Text(formatBS(todayBS, settings: settings.settings))
                    .font(.system(size: 28, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
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
                //
                // Not styled as an error. The dataset ended, the app did not
                // fail, and an alert-coloured panel would imply the user has done
                // something wrong. The same weight as the date it replaces keeps
                // the layout from jumping when the range is crossed.
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.bsDateUnavailable)
                        .font(.title3)
                        .fixedSize(horizontal: false, vertical: true)
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
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    SpokenDate.gregorianAnnouncement(date: todayAD, weekday: weekday)
                )
            }

            Divider()
            clocks
        }
    }

    // MARK: - Clocks

    /// Clocks sit outside the Gregorian conditional: they are answerable
    /// regardless of calendar data, so they must survive the range boundary.
    ///
    /// `Label` supplies each row's title for free, but it announces that title
    /// verbatim — under Devanagari that is "Nepal Time: ११:४५:००", and a clock
    /// face is the one place where a misread digit is not obviously wrong to the
    /// listener. So each row re-derives its own time string in Latin digits, and
    /// the stack is a container that leaves the two rows as separate elements
    /// rather than merging them into one unreadable run.
    private var clocks: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(clock.nptTimeString(digits: settings.settings.digits))
            } icon: {
                Text(Strings.nepalTimeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.title3)
            .monospacedDigit()
            .accessibilityLabel("\(Strings.nepalTimeLabel): \(clock.nptTimeString(digits: .latin))")

            // Omitted entirely when the local reading would repeat Nepal Time,
            // which is the case for every user in Nepal. Two identical clocks
            // imply the second is somehow significant, and it is not — the
            // reference only earns its row by differing.
            if !clock.localTimeIsRedundant {
                Label {
                    Text(clock.localTimeString(digits: settings.settings.digits))
                } icon: {
                    Text(Strings.localTimeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.title3)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel("\(Strings.localTimeLabel): \(clock.localTimeString(digits: .latin))")
            }
        }
        .accessibilityElement(children: .contain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
