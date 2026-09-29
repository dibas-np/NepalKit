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
/// Iconography (per ADR-0004): SF Symbols throughout, monochrome for small
/// inline icons so they keep contrast beside text. The menu-bar extra itself
/// stays date text only.
///
/// The header and the Today destination read `ClockModel`, which ticks every
/// second. Each is its own view type, so a tick re-evaluates only the sections
/// that show live time and leaves the tab picker and the footer's buttons
/// untouched.
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
    let dataset: CalendarDataset
    /// Ephemeral by design: the popover closes on every activation, so a
    /// remembered selection would open onto Convert after a read of the date and
    /// back onto Today after a conversion, with no predictability. Today is the
    /// resting state because it is what the menu-bar item just showed.
    @State private var destination: PopoverDestination = .today

    /// One width for both destinations, so switching tabs does not resize the
    /// popover under the pointer. Fixed rather than a minimum because the
    /// converter's pickers are the widest content; a minimum would let the Today
    /// screen shrink narrower than they do.
    private static let popoverWidth: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderBar(clock: clock, settings: settings.settings)

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

            // The swap cross-fades: Today and Convert are two states of one
            // surface, not two replacements. Scoped to the switch rather than
            // the outer stack so the segmented control and the footer's
            // position label, which also read `destination`, update plainly.
            Group {
                switch destination {
                case .today:
                    VStack(alignment: .leading, spacing: 8) {
                        TodaySection(clock: clock, settings: settings.settings, dataset: dataset)
                        Divider()
                        ClocksSection(clock: clock, settings: settings.settings)
                    }
                case .convert:
                    ConverterView(model: converter, settings: settings.settings)
                }
            }
            .animation(.default, value: destination)
        }
        .padding()
        .frame(width: Self.popoverWidth)
        // The actions below are full-width rows, so the whole popover shares one
        // left edge. Without this the date and the actions are left-aligned to
        // two different x positions and the block looks accidentally staggered.
        .frame(maxWidth: .infinity, alignment: .leading)

        // Settings, About and Quit live below the content rather than inside
        // either destination. They open other windows or end the process, so
        // they are not a step in navigating Today and Convert, and burying them
        // in one tab would hide them from the other.
        footer
    }

    // MARK: - Footer

    /// A bar along the bottom: the selected destination on the left, the three
    /// actions on the right.
    ///
    /// This follows the reference layout, where the footer names where you are
    /// on the left and puts the actions on the right. Naming the destination here
    /// is what the segmented control's selection does not say on its own when the
    /// popover is read as a whole: the control is a control, and this is the
    /// surface's own statement of position.
    ///
    /// Each action pairs a symbol with its visible title and carries a spoken
    /// hint. Why the titles are not dropped in favour of the reference's bare
    /// glyphs is recorded at the call site below.
    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Text(destination.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                // Visible text, not icon-only: a bare glyph on this surface
                // exposes no accessible name (System Events reports `AXName` as
                // missing for these buttons), and with the text removed a
                // screen-reader user hears "button" twice with no way to tell
                // the actions apart. An action whose name cannot be proven
                // announced shows its name.
                action(
                    Symbols.settings,
                    title: Strings.settingsLabel,
                    help: Strings.settingsHelp
                ) {
                    WindowPresentation.present(open: { openSettings() })
                }

                action(
                    Symbols.about,
                    title: Strings.aboutLabel,
                    help: Strings.aboutHelp
                ) {
                    WindowPresentation.present(open: { openWindow(id: AboutWindow.id) })
                }

                // Quit keeps its text. It is the only action in a menu-bar-only
                // app that ends the process, and the one a first-time user most
                // likely to hunt for; the others have conventional glyphs, this
                // does not.
                //
                // The ⌘Q shortcut lives on the app's termination command group
                // (NepalKitApp.swift) so it works when the app is frontmost
                // without the popover open. This is the discoverable control for
                // the same action.
                Button(Strings.quitLabel, action: AppTermination.quit)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Strings.quitLabel)
                    .accessibilityHint(Strings.quitHelp)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    /// A compact symbol-and-title action for the footer.
    ///
    /// Tighter than a full-width row so three of them fit beside the position
    /// label, but still text: see the note at the call site for why these are not
    /// icon-only. The hint carries the purpose, which a glyph cannot.
    private func action(
        _ symbol: String,
        title: String,
        help: String,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .symbolRenderingMode(.monochrome)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint(help)
    }
}

#if DEBUG
#Preview("Popover") {
    PopoverView(
        settings: .preview,
        // `refreshes: false` because a live clock schedules a main-run-loop
        // timer on every redraw that nothing ever invalidates.
        clock: ClockModel(now: AppData.previewInstant, refreshes: false),
        converter: ConverterModel(now: AppData.previewInstant),
        dataset: AppData.dataset
    )
    .padding()
}
#endif

// MARK: - Header Bar

/// Identity on the left, the live Nepal Time on the right.
///
/// The reference this follows leads with a title bar carrying a name and a
/// running value, and that is what makes it read as a surface with its own
/// top edge rather than a loose stack of controls. The technique is taken; the
/// dashboard framing is not, so nothing here is a card and the row is a plain
/// line of text.
///
/// The clock is the live element because it is the only value that changes
/// without the user acting. The date is deliberately not repeated here — it
/// is the hero directly below, and saying it twice would make the header
/// decorative.
private struct HeaderBar: View {
    let clock: ClockModel
    let settings: DisplaySettings

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Strings.appName)
                .font(.subheadline.weight(.medium))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(clock.nptTimeString(digits: settings.digits))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel(
                    "\(Strings.nepalTimeLabel): \(clock.nptTimeString(digits: .latin))"
                )
        }
    }
}

// MARK: - Today

/// Today's date as the hero, with the Gregorian line beneath it.
private struct TodaySection: View {
    let clock: ClockModel
    let settings: DisplaySettings
    let dataset: CalendarDataset

    /// Last Bikram Sambat year the bundled dataset can convert. Named in the
    /// range boundary state so a user past it can tell a data limit from a bug.
    private var lastSupportedBSYear: Int { dataset.supportedRange.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // No "Today" header here. The segmented control directly above already
            // reads "Today" and is the selected segment, so a second "Today" two
            // lines down repeats the destination to confirm what the control just
            // said. Removing it also lets the date sit at the top of the content
            // rather than below a label describing it.
            //
            // The heading role is not lost: the segmented control carries the
            // destination name, and the date below it is the first thing a reader
            // meets either way.

            if let todayBS = clock.todayBSDate(in: dataset) {
                // The hero. Weight is what makes the date the first thing read
                // rather than a value sitting beside its own label; everything
                // below steps down from it.
                //
                // Shown exactly as configured; announced in a form a voice can
                // pronounce. The two come from the same date, so they cannot
                // drift into describing different days.
                Text(formatBS(todayBS, settings: settings))
                    .font(.system(size: 28, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    // Label only: `children: .ignore` leaves a `Text` with no
                    // accessibility role at all. Replacing the label keeps its
                    // static-text role.
                    .accessibilityLabel(
                        SpokenDate.bs(todayBS, monthNames: settings.monthNames)
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
                    Text(Strings.supportedThrough(lastSupportedBSYear, digits: settings.digits))
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
                let weekday = clock.weekdayString(style: settings.monthNames)
                HStack(spacing: 4) {
                    Text(formatAD(todayAD, settings: settings))
                    if let weekday {
                        Text("\(Strings.weekdaySeparator) \(weekday)")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    SpokenDate.gregorianAnnouncement(date: todayAD, weekday: weekday)
                )
            }
        }
    }
}

// MARK: - Clocks

/// The local-time reference, which is the one clock the header cannot carry.
///
/// Sits outside the Gregorian conditional because a clock is answerable
/// regardless of calendar data, so it must survive the range boundary.
///
/// `Label` supplies the row's title for free, but it announces that title
/// verbatim — under Devanagari that is "Local: ११:४५:००", and a clock face is
/// the one place where a misread digit is not obviously wrong to the listener.
/// So the row re-derives its own string in Latin digits, and the stack is a
/// container that leaves the rows as separate elements rather than merging
/// them into one unreadable run.
private struct ClocksSection: View {
    let clock: ClockModel
    let settings: DisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Nepal Time is not repeated here. The header carries it, so a second
            // copy one row below showed the same ticking value twice and made the
            // popover read as though it had two clocks to offer.
            //
            // Only the local reference remains, which is the half the header
            // cannot carry: the header is one value, and "what time is it here
            // compared to Nepal" is a comparison that needs both.
            //
            // Omitted entirely when the local reading would repeat Nepal Time,
            // which is the case for every user in Nepal. Two identical clocks
            // imply the second is somehow significant, and it is not — the
            // reference only earns its row by differing.
            if !clock.localTimeIsRedundant {
                Label {
                    Text(clock.localTimeString(digits: settings.digits))
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
