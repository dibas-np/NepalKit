// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

/// A day's details under the grid: the day in both calendars, how far it is
/// from today, and what can be done with it. Layout only; every string is the
/// model's.
struct MonthGridDayDetailCard: View {
    let detail: MonthGridDayDetail
    let copy: () -> Void
    let openInConverter: () -> Void
    let close: () -> Void

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
                // One line per name, so a day with three reads as three. The
                // text is primary: tinted text over Liquid Glass takes on what
                // is behind the popover and lost its contrast. The tint stays
                // on a dot, which ties each name to the dot on the day's cell.
                ForEach(Array(zip(detail.festivals, detail.spokenFestivals).enumerated()), id: \.offset) { _, names in
                    let (shown, spoken) = names
                    HStack(alignment: .firstTextBaseline) {
                        Circle().fill(.tint).frame(width: 5, height: 5).accessibilityHidden(true)
                        Text(shown)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(spoken)
                }
                // Who the day is a holiday for, under the names it is a
                // holiday for. Secondary rather than red or tinted: the red
                // is the cell's, and coloured text over Liquid Glass loses
                // its contrast.
                ForEach(detail.holidays, id: \.self) { holiday in
                    Text(holiday)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(Strings.copyDateLabel, action: copy)
                    .accessibilityHint(Strings.copyDateHelp)
                Button(Strings.openInConverterLabel, action: openInConverter)
                    .accessibilityHint(Strings.openInConverterHelp)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            Button(Strings.closeDayDetailsLabel, systemImage: Symbols.closeDetails, action: close)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .padding(6)
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
/// The card on the preview's today, 1 Kartik 2083, which is Maha Ashtami and a
/// Dashain public holiday: the one state the grid preview cannot reach
/// without a click.
#Preview("Day details, festival") {
    let model = MonthGridModel(now: AppData.previewInstant)
    let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)
    if let today = model.weeks.joined().compactMap({ $0 }).first(where: \.isToday) {
        MonthGridDayDetailCard(detail: model.detail(for: today, settings: settings), copy: {}, openInConverter: {}, close: {})
            .padding()
            .frame(width: 340)
    }
}
#endif
