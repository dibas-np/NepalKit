// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import SwiftUI
import NepalKitCore

/// Which of the popover's two destinations is showing.
///
/// Today and Convert are peers, so they are named as tabs rather
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

    var symbol: String {
        switch self {
        case .today: Symbols.today
        case .convert: Symbols.converter
        }
    }
}

/// Popover: today's date and month, the converter, and routes into Settings and About.
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
    let monthGrid: MonthGridModel
    /// Settings open through SwiftUI's own action rather than a hand-built
    /// window; the activation half is `WindowPresentation`'s (ADR-0011).
    @Environment(\.openSettings) private var openSettings
    /// Injected so the year named in the range boundary state is the same
    /// dataset the rest of the view reads, and so a test can control it.
    let dataset: CalendarDataset
    /// The app's updater, owned by `NepalKitApp` and shared with the Settings
    /// window. Read here only to hand it to the footer, which is where the
    /// update button lives.
    let updates: UpdateCheckModel
    /// Ephemeral by design: the popover closes on every activation, so a
    /// remembered selection would open onto Convert after a read of the date and
    /// back onto Today after a conversion, with no predictability. Today is the
    /// resting state because it is what the menu-bar item just showed.
    @State private var destination: PopoverDestination = .today

    /// One width for every destination, so switching tabs does not resize the
    /// popover under the pointer. Fixed rather than a minimum because the
    /// converter's pickers are the widest content; a minimum would let the Today
    /// screen shrink narrower than they do.
    private static let popoverWidth: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderBar(clock: clock, settings: settings.settings)

            DestinationTabs(selection: $destination)

            // Both destinations stay laid out, one over the other, and the
            // swap cross-fades between them. The stack is as tall as the
            // taller one (Today, with its month grid), so switching never
            // resizes the menu-bar window. Swapping views in a `switch` did:
            // the window shrank and grew on every switch, animated inside
            // SwiftUI's commit, which AppKit rejects (layout recursion,
            // "transaction during CA commit") and which made the popover jump.
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    TodaySection(clock: clock, settings: settings.settings, dataset: dataset)
                    Divider()
                    // The month sits with today's date rather than behind a
                    // tab of its own: reading the date and seeing where it
                    // falls in the month are one glance, not two.
                    MonthGridView(
                        model: monthGrid, settings: settings.settings, clock: clock,
                        isActive: destination == .today
                    )
                    ClocksSection(clock: clock, settings: settings.settings)
                }
                .destinationLayer(isShowing: destination == .today)

                ConverterView(model: converter, settings: settings.settings)
                    .destinationLayer(isShowing: destination == .convert)
            }
            .animation(.default, value: destination)
        }
        .padding()
        .frame(width: Self.popoverWidth)
        // The actions below are full-width rows, so the whole popover shares one
        // left edge. Without this the date and the actions are left-aligned to
        // two different x positions and the block looks accidentally staggered.
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await clock.refreshWhileVisible() }

        // Settings and Quit live below the content rather than inside either
        // destination. They open another window or end the process, so they are
        // not a step in navigating the destinations, and burying them in one tab
        // would hide them from the other.
        //
        // `openSettings` and the update state are all this hands over, so a
        // per-second clock tick never re-evaluates the footer - the same
        // reasoning that made the header, Today and Clocks their own view
        // types.
        PopoverFooter(openSettings: { openSettings() }, updates: updates)
    }

}

extension View {
    /// One destination in the popover's stack: drawn, hit-testable, focusable
    /// and read out only while it is the one showing.
    fileprivate func destinationLayer(isShowing: Bool) -> some View {
        opacity(isShowing ? 1 : 0)
            .allowsHitTesting(isShowing)
            .disabled(!isShowing)
            .accessibilityHidden(!isShowing)
    }
}

#if DEBUG
#Preview("Popover") {
    PopoverView(
        settings: .preview,
        // Keep the preview clock fixed when the visibility task starts.
        clock: ClockModel(now: AppData.previewInstant, refreshes: false),
        converter: ConverterModel(now: AppData.previewInstant),
        monthGrid: MonthGridModel(now: AppData.previewInstant),
        dataset: AppData.dataset,
        // The resting state: no update, so no update button in the footer.
        updates: UpdateCheckModel(service: PreviewUpdateService())
    )
    .padding()
}

/// The state the default preview cannot reach. The footer only draws its update
/// button once a check has found something, so without a reporting service this
/// is the only place that button can be looked at.
#Preview("Popover, update available") {
    PopoverView(
        settings: .preview,
        clock: ClockModel(now: AppData.previewInstant, refreshes: false),
        converter: ConverterModel(now: AppData.previewInstant),
        monthGrid: MonthGridModel(now: AppData.previewInstant),
        dataset: AppData.dataset,
        updates: UpdateCheckModel(service: PreviewUpdateService(reporting: .updateAvailable))
    )
    .padding()
}
#endif

// MARK: - Header Bar

/// Identity on the left, the live clock today follows on the right: Nepal Time,
/// or the Mac's own time when the user chose it (ADR-0017).
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
            // Sized by a constant "00:00:00" and drawn in an overlay, so the
            // per-second change never resizes anything: a ticking `Text` in the
            // stack itself made SwiftUI re-measure the whole popover every
            // second. Digits are monospaced, so the template is exactly as wide
            // as every reading.
            Text(formatClock(.distantPast, timeZone: .gmt, digits: settings.digits))
                .hidden()
                .overlay(alignment: .trailing) {
                    HeaderClockTime(clock: clock, digits: settings.digits)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

/// The header's ticking reading: the only part of the header that reads the
/// clock, so the tick re-evaluates this and not the row around it.
private struct HeaderClockTime: View {
    let clock: ClockModel
    let digits: DigitScript

    var body: some View {
        Text(clock.headerTimeString(digits: digits))
            // Named aloud because nothing on screen says which clock this
            // is, and with the user's own zone chosen it is not Nepal's.
            .accessibilityLabel(
                "\(clock.headerClockLabel): \(clock.headerTimeString(digits: .latin))"
            )
    }
}

// MARK: - Clocks

/// The other clock, which is the one the header cannot carry: the Mac's local
/// time beside Nepal Time, or Nepal Time beside the user's own zone (ADR-0017).
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
            // The header's clock is not repeated here. A second copy one row
            // below showed the same ticking value twice and made the popover
            // read as though it had two clocks to offer.
            //
            // Only the other reference remains, which is the half the header
            // cannot carry: the header is one value, and "what time is it here
            // compared to Nepal" is a comparison that needs both.
            //
            // Omitted entirely when the two readings would repeat each other,
            // which is the case for every user in Nepal. Two identical clocks
            // imply the second is somehow significant, and it is not — the
            // reference only earns its row by differing.
            if clock.showsSecondaryClock {
                // The divider comes and goes with the row, so a reader in
                // Nepal is not left with a rule above nothing.
                Divider()
                Label {
                    // Sized by a constant reading and drawn in an overlay, as
                    // the header's clock is, so the per-second change re-draws
                    // only `SecondaryClockTime` and never re-measures the popover.
                    Text(formatClock(.distantPast, timeZone: .gmt, digits: settings.digits))
                        .hidden()
                        .overlay(alignment: .leading) {
                            SecondaryClockTime(clock: clock, digits: settings.digits)
                        }
                } icon: {
                    Text(clock.secondaryClockLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.title3)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
        .accessibilityElement(children: .contain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The secondary row's ticking reading: the only part of the row that reads
/// the clock, so the tick re-evaluates this and not the row around it.
private struct SecondaryClockTime: View {
    let clock: ClockModel
    let digits: DigitScript

    var body: some View {
        Text(clock.secondaryTimeString(digits: digits))
            .accessibilityLabel("\(clock.secondaryClockLabel): \(clock.secondaryTimeString(digits: .latin))")
    }
}
