// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import SwiftUI
import NepalKitCore

/// One Bikram Sambat month as a Sunday-first grid. Layout only; state and
/// strings come from `MonthGridModel`.
struct MonthGridView: View {
    let model: MonthGridModel
    let settings: DisplaySettings
    let clock: ClockModel
    /// False while hidden under another destination, so it stops taking keys and scrolls.
    var isActive = true

    @State private var selected: MonthGridDay?
    @State private var calendarFailed = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthGridHeader(model: model, settings: settings, clock: clock)

            if model.isTodayPastSupportedRange {
                Text(Strings.monthGridPastRange(model.lastSupportedBSYear, digits: settings.digits))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Strings.monthGridPastRange(model.lastSupportedBSYear, digits: .latin))
            }

            MonthGridDays(model: model, settings: settings, selected: $selected)
            MonthGridYearNotes(model: model, settings: settings)

            // Under the grid rather than in a popover anchored to a cell, which was torn
            // down mid-layout when its action switched destination.
            if let day = selected {
                let detail = model.detail(for: day, settings: settings)
                MonthGridDayDetailCard(
                    detail: detail,
                    copy: { model.copy(detail) },
                    addToCalendar: { calendarFailed = !model.addToCalendar(day, settings: settings) },
                    addToCalendarFailed: calendarFailed,
                    close: { selected = nil }
                )
            }
        }
        .onChange(of: model.shown) { selected = nil }
        .onChange(of: selected) { calendarFailed = false }
        // The model outlives the popover, so today is re-read on appear.
        .onAppear { model.refreshToday(now: clock.now) }
        .background { TodayFollower(clock: clock, model: model) }
        // `.edit` makes the grid focusable without Full Keyboard Access.
        .focusable(isActive, interactions: .edit)
        .focusEffectDisabled()
        .focused($isFocused)
        // Not `isFocused = true` in `onAppear`, which changes first responder mid-layout.
        .defaultFocus($isFocused, true)
        .onKeyPress(.leftArrow) {
            model.page(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            model.page(by: 1)
            return .handled
        }
        .modifier(ScrollPaging(model: model, isActive: isActive))
    }
}

/// Pages the grid on scrolling over it. SwiftUI has no scroll-wheel event outside
/// a scroll view, so this monitors the app's scroll events.
private struct ScrollPaging: ViewModifier {
    let model: MonthGridModel
    let isActive: Bool
    @State private var isHovering = false
    /// Read by the monitor's closure, which is created once and would otherwise
    /// capture a stale `isActive`.
    @State private var isActiveNow = true
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .contentShape(.rect)
            .onHover { isHovering = $0 }
            .onChange(of: isActive, initial: true) { isActiveNow = isActive }
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    guard isActiveNow, isHovering else { return event }
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

/// A separate view so the clock's per-second tick invalidates only this body.
private struct TodayFollower: View {
    let clock: ClockModel
    let model: MonthGridModel

    var body: some View {
        Color.clear
            .onChange(of: clock.now) { _, now in model.refreshToday(now: now) }
    }
}

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
                if let span = model.gregorianSpan(settings: settings) {
                    Text(span)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(model.spokenGregorianSpan() ?? span)
                }
            }

            Spacer(minLength: 4)

            // No icon: it crowded the title off its row in Devanagari.
            Button(Strings.todayLabel) {
                model.showToday(now: clock.now)
            }
            .disabled(model.isShowingTodayMonth)
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

/// The shown year's caveats, so a year past the transcribed lists does not read
/// as one with no festivals.
private struct MonthGridYearNotes: View {
    let model: MonthGridModel
    let settings: DisplaySettings

    var body: some View {
        let notes = model.yearNotes(digits: settings.digits)
        let spoken = model.yearNotes(digits: .latin)
        ForEach(notes.indices, id: \.self) { index in
            Text(notes[index])
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(spoken[index])
        }
    }
}

/// The weekday row and the weeks, in one `Grid` so the columns share widths.
private struct MonthGridDays: View {
    let model: MonthGridModel
    let settings: DisplaySettings
    @Binding var selected: MonthGridDay?

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
            ForEach(GridSlot.weeks(model.weeks)) { week in
                GridRow {
                    ForEach(week.slots) { slot in
                        let cell = slot.day
                        if let cell, cell.isInShownMonth {
                            dayButton(cell)
                        } else if let cell {
                            // Context, not a target: the chevrons go there.
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

    /// A button rather than a tap gesture so VoiceOver and the keyboard can press it.
    private func dayButton(_ day: MonthGridDay) -> some View {
        Button {
            selected = selected == day ? nil : day
        } label: {
            MonthGridCell(day: day, model: model, settings: settings, isSelected: selected == day)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Restated on the button, where VoiceOver lands.
        .accessibilityLabel(model.spokenLabel(for: day, settings: settings))
        .accessibilityAddTraits(day.isToday || selected == day ? .isSelected : [])
        .accessibilityHint(Strings.monthGridDayHelp)
    }
}

/// A day's identity is its Gregorian date, so grid identities outlive a month.
struct GridSlot: Identifiable {
    let id: AnyHashable
    let day: MonthGridDay?

    struct Week: Identifiable {
        let id: AnyHashable
        let slots: [GridSlot]
    }

    static func weeks(_ weeks: [[MonthGridDay?]]) -> [Week] {
        weeks.enumerated().map { row, week in
            let slots = week.enumerated().map { column, day in
                GridSlot(id: day.map { AnyHashable($0.gregorian) } ?? AnyHashable("empty \(row) \(column)"), day: day)
            }
            let first = week.compactMap { $0 }.first
            return Week(id: first.map { AnyHashable($0.gregorian) } ?? AnyHashable("empty \(row)"), slots: slots)
        }
    }
}

/// A day: the Bikram Sambat day large, the Gregorian day small beneath it.
private struct MonthGridCell: View {
    let day: MonthGridDay
    let model: MonthGridModel
    let settings: DisplaySettings
    var isSelected = false

    private static let festivalMarkSize: CGFloat = 4

    /// Red for a holiday even on today, as on a wall calendar.
    private var dayStyle: AnyShapeStyle {
        if !day.isInShownMonth { return AnyShapeStyle(.tertiary) }
        return day.isMarkedAsHoliday ? AnyShapeStyle(.red) : AnyShapeStyle(.primary)
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
            // Drawn in every cell and shown only on festival days, so rows keep one height.
            Circle()
                .fill(.tint)
                .frame(width: Self.festivalMarkSize, height: Self.festivalMarkSize)
                .padding(.top, 1)
                .opacity(day.showsFestivalMark ? 1 : 0)
        }
        .monospacedDigit()
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
        .background {
            if day.isToday {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.tint.opacity(0.25))
            }
        }
        .overlay {
            // Selection is an outline, so it reads over today's fill too.
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.tint, lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.spokenLabel(for: day, settings: settings))
        .accessibilityAddTraits(day.isToday ? .isSelected : [])
        // Read out, neighbouring days would put another month's days in this one's list.
        .accessibilityHidden(!day.isInShownMonth)
    }
}

#if DEBUG
#Preview("Month grid") {
    MonthGridView(
        model: MonthGridModel(now: AppData.previewInstant),
        settings: DisplaySettings(digits: .latin, monthNames: .transliterated),
        clock: ClockModel(now: AppData.previewInstant, refreshes: false),
    )
    .padding()
    .frame(width: 340)
}
#endif
