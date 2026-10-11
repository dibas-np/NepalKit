// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import SwiftUI
import NepalKitCore

/// One Bikram Sambat month as a Sunday-first grid, with each day's Gregorian
/// day beneath it. Layout only: the month, the bounds, the cells and every
/// string come from `MonthGridModel`.
struct MonthGridView: View {
    let model: MonthGridModel
    let settings: DisplaySettings
    let clock: ClockModel
    /// "Open in Converter" from a day's popover. A callback, because the
    /// destination it switches belongs to `PopoverView`, not to the grid.
    let openInConverter: (BSDay) -> Void

    /// Focus is what lets the arrow keys reach the grid. Taken on appearance
    /// so they work as soon as the popover opens, without a click first.
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthGridHeader(model: model, settings: settings, clock: clock)

            if model.isTodayPastSupportedRange {
                // Range boundary state, not an error: the dataset ended and the
                // grid shows its last month. Secondary, like the Today tab's.
                Text(Strings.monthGridPastRange(model.lastSupportedBSYear, digits: settings.digits))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Strings.monthGridPastRange(model.lastSupportedBSYear, digits: .latin))
            }

            MonthGridDays(model: model, settings: settings, openInConverter: openInConverter)
        }
        // The model outlives the popover, so today is re-read on every
        // appearance, and the follower moves it while the grid stays open.
        .onAppear {
            model.refreshToday(now: clock.now)
            isFocused = true
        }
        .background { TodayFollower(clock: clock, model: model) }
        // Paging without aiming at the chevrons: the arrow keys, and
        // scrolling over the grid. Both page through the model, so they stop
        // at the supported range's ends exactly as the chevrons do.
        //
        // `.edit` rather than the default, which on macOS makes a view
        // focusable only with Full Keyboard Access turned on; the arrow keys
        // should not depend on that setting. No focus ring: the grid is not a
        // control to tab to, and the ring would frame the whole month.
        .focusable(interactions: .edit)
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.leftArrow) {
            model.page(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            model.page(by: 1)
            return .handled
        }
        .modifier(ScrollPaging(model: model))
    }
}

/// Pages the grid on scroll-wheel and trackpad scrolling while the pointer is
/// over it. SwiftUI has no scroll-wheel event for a view that is not a scroll
/// view, so this listens to the app's scroll events and takes only the ones
/// that arrive while the pointer is inside the grid; the rest pass through.
/// How many events make a page is `MonthScrollPager`'s decision.
private struct ScrollPaging: ViewModifier {
    let model: MonthGridModel
    @State private var isHovering = false
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            // The whole frame, not only the drawn glyphs, so scrolling in the
            // gaps between days still pages.
            .contentShape(.rect)
            .onHover { isHovering = $0 }
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    guard isHovering else { return event }
                    model.scroll(
                        deltaY: event.scrollingDeltaY,
                        phase: MonthScrollPager.Phase(phase: event.phase, momentumPhase: event.momentumPhase)
                    )
                    return nil
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}

/// Moves today's highlight when the visible clock crosses Nepal Time midnight.
/// A separate view so the clock's per-second tick re-evaluates only this empty
/// body, not the grid; `refreshToday` writes nothing until the day changes.
private struct TodayFollower: View {
    let clock: ClockModel
    let model: MonthGridModel

    var body: some View {
        Color.clear
            .onChange(of: clock.now) { _, now in model.refreshToday(now: now) }
    }
}

/// Month title on the left, navigation on the right.
private struct MonthGridHeader: View {
    let model: MonthGridModel
    let settings: DisplaySettings
    let clock: ClockModel

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.title(settings: settings))
                    .font(.headline)
                    .accessibilityLabel(model.spokenTitle(settings: settings))
                    .accessibilityAddTraits(.isHeader)
                // Which Gregorian months these days fall in, so the Gregorian
                // digits under each day have a month to belong to.
                if let span = model.gregorianSpan(settings: settings) {
                    Text(span)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(model.spokenGregorianSpan() ?? span)
                }
            }

            Spacer(minLength: 4)

            // Text alone: the tab above already says Today, and an icon
            // beside it crowded the title off its row in Devanagari.
            Button(Strings.todayLabel) {
                model.showToday(now: clock.now)
            }
            .disabled(model.isShowingTodayMonth)
            // Hidden rather than greyed while it would do nothing, which is
            // most of the time; it keeps its width so the chevrons stay put.
            .opacity(model.isShowingTodayMonth ? 0 : 1)
            .accessibilityHidden(model.isShowingTodayMonth)
            .accessibilityHint(Strings.showTodayHelp)

            Button(Strings.previousMonthLabel, systemImage: Symbols.previousMonth, action: model.showPreviousMonth)
                .labelStyle(.iconOnly)
                .disabled(!model.canShowPreviousMonth)

            Button(Strings.nextMonthLabel, systemImage: Symbols.nextMonth, action: model.showNextMonth)
                .labelStyle(.iconOnly)
                .disabled(!model.canShowNextMonth)
        }
        .symbolRenderingMode(.monochrome)
    }
}

/// The weekday row and the weeks, in one `Grid` so the columns share widths.
private struct MonthGridDays: View {
    let model: MonthGridModel
    let settings: DisplaySettings
    let openInConverter: (BSDay) -> Void

    /// The day whose popover is open. One for the grid rather than a flag per
    /// cell, so opening a day closes any other.
    @State private var selected: MonthGridDay?
    /// The day to open in the converter once its popover has finished closing.
    /// Switching destination while the popover is still closing tears down the
    /// cell it is anchored to mid-layout: AppKit logs layout recursion and the
    /// menu-bar popover jumps to the cell's frame before settling back.
    @State private var pendingConverterDay: BSDay?

    var body: some View {
        let headers = model.weekdayHeaders(settings: settings)
        let spokenHeaders = model.spokenWeekdayHeaders(settings: settings)
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                ForEach(0 ..< 7, id: \.self) { column in
                    Text(headers[column])
                        .font(.caption)
                        .foregroundStyle(model.isWeeklyHolidayColumn(column) ? Color.red : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(spokenHeaders[column])
                }
            }
            ForEach(model.weeks.enumerated(), id: \.offset) { _, week in
                GridRow {
                    ForEach(week.enumerated(), id: \.offset) { _, cell in
                        if let cell, cell.isInShownMonth {
                            dayButton(cell)
                        } else if let cell {
                            // A neighbouring month's day is context, not a
                            // target: the chevrons are the way to its month.
                            MonthGridCell(day: cell, model: model, settings: settings)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Strings.monthGridDaysLabel)
    }

    /// A day of the shown month as a button that opens its popover. A button,
    /// not a tap gesture, so VoiceOver announces it as one and it can be
    /// pressed from the keyboard.
    private func dayButton(_ day: MonthGridDay) -> some View {
        Button {
            selected = day
        } label: {
            MonthGridCell(day: day, model: model, settings: settings)
                // The whole cell is the target, not only the digits' glyphs.
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Restated on the button, which is the element VoiceOver lands on.
        .accessibilityLabel(model.spokenLabel(for: day, settings: settings))
        .accessibilityAddTraits(day.isToday ? .isSelected : [])
        .accessibilityHint(Strings.monthGridDayHelp)
        .popover(isPresented: isPresented(day), arrowEdge: .bottom) {
            let detail = model.detail(for: day, settings: settings)
            MonthGridDayPopover(
                detail: detail,
                copy: {
                    model.copy(detail)
                    selected = nil
                },
                openInConverter: {
                    pendingConverterDay = day.bikramSambat
                    selected = nil
                }
            )
            .onDisappear {
                guard let pending = pendingConverterDay else { return }
                pendingConverterDay = nil
                openInConverter(pending)
            }
        }
    }

    private func isPresented(_ day: MonthGridDay) -> Binding<Bool> {
        Binding(
            get: { selected == day },
            set: { if !$0, selected == day { selected = nil } }
        )
    }
}

/// A day: the Bikram Sambat day large, the Gregorian day small beneath it.
private struct MonthGridCell: View {
    let day: MonthGridDay
    let model: MonthGridModel
    let settings: DisplaySettings

    /// The large number's colour. Red for the holiday column, as on a wall
    /// calendar, and still red on today: the tint behind it is light enough
    /// that the number stays legible, and dropping the red there would hide
    /// that today is the holiday. A neighbouring month's day is tertiary
    /// whatever its column, so the shown month stays the one that reads.
    private var dayStyle: AnyShapeStyle {
        if !day.isInShownMonth { return AnyShapeStyle(.tertiary) }
        return day.isWeeklyHoliday ? AnyShapeStyle(.red) : AnyShapeStyle(.primary)
    }

    private var gregorianStyle: AnyShapeStyle {
        if !day.isInShownMonth { return AnyShapeStyle(.tertiary) }
        return day.isToday ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(model.dayText(day, settings: settings))
                .font(.body.weight(day.isToday ? .semibold : .regular))
                .foregroundStyle(dayStyle)
            Text(model.gregorianDayText(day, settings: settings))
                .font(.caption2)
                .foregroundStyle(gregorianStyle)
        }
        .monospacedDigit()
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
        .background {
            if day.isToday {
                // The accent tint is the system's own "this one" mark, and
                // follows the user's accent colour.
                RoundedRectangle(cornerRadius: 6)
                    .fill(.tint.opacity(0.25))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.spokenLabel(for: day, settings: settings))
        .accessibilityAddTraits(day.isToday ? .isSelected : [])
        // The neighbouring months' days are a sighted reader's context for
        // the first and last weeks. Read out, they would put another month's
        // days inside this month's list; the chevrons are the way there.
        .accessibilityHidden(!day.isInShownMonth)
    }
}

/// A day's popover: the day in both calendars, how far it is from today, and
/// what can be done with it. Layout only; every string is the model's.
private struct MonthGridDayPopover: View {
    let detail: MonthGridDayDetail
    let copy: () -> Void
    let openInConverter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.bikramSambat)
                    .font(.title3.weight(.semibold))
                    .accessibilityLabel(detail.spokenBikramSambat)
                Text(detail.gregorian)
                    .font(.callout)
                    .accessibilityLabel(detail.spokenGregorian)
                if let relative = detail.relative {
                    Text(relative)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(detail.spokenRelative ?? relative)
                }
            }

            HStack(spacing: 8) {
                Button(Strings.copyDateLabel, action: copy)
                    .accessibilityHint(Strings.copyDateHelp)
                Button(Strings.openInConverterLabel, action: openInConverter)
                    .accessibilityHint(Strings.openInConverterHelp)
            }
        }
        .padding()
        .fixedSize()
    }
}

#if DEBUG
#Preview("Month grid") {
    MonthGridView(
        model: MonthGridModel(now: AppData.previewInstant),
        settings: DisplaySettings(digits: .latin, monthNames: .transliterated),
        clock: ClockModel(now: AppData.previewInstant, refreshes: false),
        openInConverter: { _ in }
    )
    .padding()
    .frame(width: 340)
}
#endif
