// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

/// One Bikram Sambat month as a Sunday-first grid, with each day's Gregorian
/// day beneath it. Layout only: the month, the bounds, the cells and every
/// string come from `MonthGridModel`.
struct MonthGridView: View {
    let model: MonthGridModel
    let settings: DisplaySettings
    let clock: ClockModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthGridHeader(model: model, settings: settings)

            if model.isTodayPastSupportedRange {
                // Range boundary state, not an error: the dataset ended and the
                // grid shows its last month. Secondary, like the Today tab's.
                Text(Strings.monthGridPastRange(model.lastSupportedBSYear, digits: settings.digits))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Strings.monthGridPastRange(model.lastSupportedBSYear, digits: .latin))
            }

            MonthGridDays(model: model, settings: settings)
        }
        // The model outlives the popover, so today is re-read on every
        // appearance, and the follower moves it while the grid stays open.
        .onAppear { model.refreshToday(now: .now) }
        .background { TodayFollower(clock: clock, model: model) }
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

    var body: some View {
        HStack(spacing: 4) {
            Text(model.title(settings: settings))
                .font(.headline)
                .accessibilityLabel(model.spokenTitle(settings: settings))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 4)

            Button(Strings.todayLabel, systemImage: Symbols.monthGridToday) {
                model.showToday(now: .now)
            }
            .disabled(model.isShowingTodayMonth)
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

    var body: some View {
        let headers = model.weekdayHeaders(settings: settings)
        let spokenHeaders = model.spokenWeekdayHeaders(settings: settings)
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                ForEach(0 ..< 7, id: \.self) { column in
                    Text(headers[column])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(spokenHeaders[column])
                }
            }
            ForEach(model.weeks.enumerated(), id: \.offset) { _, week in
                GridRow {
                    ForEach(week.enumerated(), id: \.offset) { _, cell in
                        if let cell {
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
}

/// A day: the Bikram Sambat day large, the Gregorian day small beneath it.
private struct MonthGridCell: View {
    let day: MonthGridDay
    let model: MonthGridModel
    let settings: DisplaySettings

    var body: some View {
        VStack(spacing: 0) {
            Text(model.dayText(day, settings: settings))
                .font(.body.weight(day.isToday ? .semibold : .regular))
            Text(model.gregorianDayText(day, settings: settings))
                .font(.caption2)
                .foregroundStyle(day.isToday ? .primary : .secondary)
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
    }
}

#if DEBUG
#Preview("Month grid") {
    MonthGridView(
        model: MonthGridModel(now: AppData.previewInstant),
        settings: DisplaySettings(digits: .latin, monthNames: .transliterated),
        clock: ClockModel(now: AppData.previewInstant, refreshes: false)
    )
    .padding()
    .frame(width: 340)
}
#endif
