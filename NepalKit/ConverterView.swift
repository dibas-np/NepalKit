// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

/// Bikram Sambat ↔ Gregorian converter with direction toggle and bounded pickers.
/// Invalid dates are structurally impossible: day ranges follow the real
/// month length, years follow the dataset's supported range.
struct ConverterView: View {
    @Bindable var model: ConverterModel
    let settings: DisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Untitled, and the label hidden. The section header directly
            // above is already an `AXHeading: Converter`, and a titled picker
            // adds its title as a second static text — the live tree showed the
            // section name twice.
            Picker("", selection: $model.directionSelection) {
                Text(Strings.bsToAD).tag(ConverterDirection.bsToAD)
                Text(Strings.adToBS).tag(ConverterDirection.adToBS)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch model.direction {
            case .bsToAD:
                HStack {
                    BSPickers(model: model, settings: settings)
                }
            case .adToBS:
                HStack {
                    ADPickers(model: model, settings: settings)
                }
            }

            if let output = model.convertedText(settings: settings) {
                // The shown line and the announcement come from the same
                // conversion, so they cannot describe different days. The
                // "Result" prefix is spoken-only: on screen the line sits under
                // the pickers that produced it, but read aloud "12 Ashoj 2083"
                // gives no clue which calendar it is in.
                //
                // Falls back to the shown text rather than an optional. The two
                // share a conversion, so this is unreachable in practice — but
                // an unreachable path must not be allowed to announce
                // "Optional(12 Ashoj 2083)" to a screen reader.
                Text(output)
                    .font(.headline)
                    // Label only, for the same reason as the popover headline:
                    // `children: .ignore` left the live tree showing
                    // `AXUnknown: Result: ...` with no role at all.
                    .accessibilityLabel(
                        [Strings.converterResultLabel, model.spokenResult(settings: settings) ?? output]
                            .joined(separator: ": ")
                    )
            } else {
                // A plain Text already announces itself; no override needed.
                Text(Strings.converterOutOfRange)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BSPickers: View {
    @Bindable var model: ConverterModel
    let settings: DisplaySettings

    var body: some View {
        Picker(Strings.yearLabel, selection: $model.bsYear) {
            ForEach(model.bsYears, id: \.self) { year in
                Text(formatNumber(year, digits: settings.digits)).tag(year)
            }
        }
        .accessibilityValue(SpokenDate.number(model.bsYear))
        Picker(Strings.monthLabel, selection: $model.bsMonth) {
            ForEach(1 ... 12, id: \.self) { month in
                Text(monthName(month: month, style: settings.monthNames)).tag(month)
            }
        }
        .accessibilityValue(monthName(month: model.bsMonth, style: settings.monthNames))
        Picker(Strings.dayLabel, selection: $model.bsDay) {
            ForEach(1 ... model.daysInBSMonth(year: model.bsYear, month: model.bsMonth), id: \.self) { day in
                Text(formatNumber(day, digits: settings.digits)).tag(day)
            }
        }
        .accessibilityValue(SpokenDate.number(model.bsDay))
    }
}

private struct ADPickers: View {
    @Bindable var model: ConverterModel
    let settings: DisplaySettings

    var body: some View {
        Picker(Strings.yearLabel, selection: $model.adYear) {
            ForEach(model.adYears, id: \.self) { year in
                Text(formatNumber(year, digits: settings.digits)).tag(year)
            }
        }
        .accessibilityValue(SpokenDate.number(model.adYear))
        Picker(Strings.monthLabel, selection: $model.adMonth) {
            ForEach(model.adMonths(year: model.adYear), id: \.self) { month in
                Text(gregorianMonthNames[month - 1]).tag(month)
            }
        }
        .accessibilityValue(gregorianMonthNames[model.adMonth - 1])
        Picker(Strings.dayLabel, selection: $model.adDay) {
            ForEach(model.adDays(year: model.adYear, month: model.adMonth), id: \.self) { day in
                Text(formatNumber(day, digits: settings.digits)).tag(day)
            }
        }
        .accessibilityValue(SpokenDate.number(model.adDay))
    }
}
