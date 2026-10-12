// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

/// A day's details under the grid: both calendars, distance from today, and
/// actions. Layout only; every string is the model's.
struct MonthGridDayDetailCard: View {
    let detail: MonthGridDayDetail
    let copy: () -> Void
    let addToCalendar: () -> Void
    /// The last Add to Calendar did not reach a calendar app.
    var addToCalendarFailed = false
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                // Close shares the title's row so a long date at a large text
                // size wraps before it instead of running underneath.
                HStack(alignment: .firstTextBaseline) {
                    Text(detail.bikramSambat)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(detail.spokenBikramSambat)
                    Spacer(minLength: 0)
                    Button(Strings.closeDayDetailsLabel, systemImage: Symbols.closeDetails, action: close)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
                Text(detail.gregorian)
                    .font(.callout)
                    .accessibilityLabel(detail.spokenGregorian)
                if let relative = detail.relative {
                    Text(relative)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(detail.spokenRelative ?? relative)
                }
                // Primary text, tint only on the dot (matching the cell's):
                // tinted text over Liquid Glass loses contrast. Keyed by name;
                // a day never lists the same festival twice.
                ForEach(Array(zip(detail.festivals, detail.spokenFestivals)), id: \.0) { shown, spoken in
                    HStack(alignment: .firstTextBaseline) {
                        Circle().fill(.tint).frame(width: 5, height: 5).accessibilityHidden(true)
                        Text(shown)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(spoken)
                }
                // Who the day is a holiday for. Secondary, not red: the red is
                // the cell's, and coloured text over Liquid Glass loses contrast.
                ForEach(detail.holidays, id: \.self) { holiday in
                    Text(holiday)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Button(Strings.copyDateLabel, action: copy)
                    .accessibilityHint(Strings.copyDateHelp)
                Button(Strings.addToCalendarLabel, action: addToCalendar)
                    .accessibilityHint(Strings.addToCalendarHelp)
            }
            if addToCalendarFailed {
                Text(Strings.addToCalendarFailed)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
/// The card on the preview's today, 1 Kartik 2083 (Maha Ashtami, a Dashain
/// public holiday): a state the grid preview needs a click to reach.
#Preview("Day details, festival") {
    let model = MonthGridModel(now: AppData.previewInstant)
    let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)
    if let today = model.weeks.joined().compactMap({ $0 }).first(where: \.isToday) {
        MonthGridDayDetailCard(detail: model.detail(for: today, settings: settings), copy: {}, addToCalendar: {}, close: {})
            .padding()
            .frame(width: 340)
    }
}
#endif
