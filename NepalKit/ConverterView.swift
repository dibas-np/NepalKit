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
            // Named, because the popover's own Today/Converter control no
            // longer heads this section: it names the *tab*, not the direction
            // within it, so without this the two segments announce as bare
            // "BS → AD" with nothing to say what the control governs.
            Picker(Strings.converterDirectionLabel, selection: $model.directionSelection) {
                // Abbreviated on screen, spoken in full. The segments share one
                // control with the tab switcher above and a 340pt popover, so
                // the full calendar names clipped to "ikram Sambat → Gregorian".
                Text(Strings.bsToAD)
                    .accessibilityLabel(Strings.bsToADSpoken)
                    .tag(ConverterDirection.bsToAD)
                Text(Strings.adToBS)
                    .accessibilityLabel(Strings.adToBSSpoken)
                    .tag(ConverterDirection.adToBS)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch model.direction {
            case .bsToAD:
                BSPickers(model: model, settings: settings)
            case .adToBS:
                ADPickers(model: model, settings: settings)
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

/// Layout shared by both directions' pickers.
///
/// Year, month and day are given explicit minimum widths rather than being left
/// to size themselves. A `Picker` with no floor shrinks to whatever is left over,
/// and inside a 340pt popover that left the Year label reading "ar" and the
/// month collapsed to an ellipsis — a control that is technically present and
/// practically unusable.
///
/// Month gets the extra room because "September" is nine characters where a year
/// is four, and Devanagari month names are longer again.
private struct DatePickers<Y: Hashable, M: Hashable, D: Hashable>: View {
    let yearLabel: String
    let monthLabel: String
    let dayLabel: String
    @Binding var year: Y
    @Binding var month: M
    @Binding var day: D
    let years: [Y]
    let yearText: (Y) -> String
    let months: [M]
    let monthText: (M) -> String
    let days: [D]
    let dayText: (D) -> String
    let spokenYear: (Y) -> String
    let spokenMonth: (M) -> String
    let spokenDay: (D) -> String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            column(label: yearLabel, minWidth: 68) {
                Picker("", selection: $year) {
                    ForEach(years, id: \.self) { Text(yearText($0)).tag($0) }
                }
            } value: { spokenYear(year) }

            // Widest of the three: "September" is nine characters, and a
            // Devanagari month name is longer again. Truncating the month to an
            // ellipsis defeats the point of a picker, since the month is the one
            // field a user is actually scanning to identify.
            column(label: monthLabel, minWidth: 112) {
                Picker("", selection: $month) {
                    ForEach(months, id: \.self) { Text(monthText($0)).tag($0) }
                }
            } value: { spokenMonth(month) }

            column(label: dayLabel, minWidth: 68) {
                Picker("", selection: $day) {
                    ForEach(days, id: \.self) { Text(dayText($0)).tag($0) }
                }
            } value: { spokenDay(day) }
        }
    }

    /// A caption above an untitled picker.
    ///
    /// The label moves out of the control because a titled macOS `Picker` lays
    /// its title and its value out on one line, so the title eats the width the
    /// value needs. Inside a 340pt popover that left "Year" clipped to "ar" and
    /// the month to an ellipsis. Captioning above also matches the order a date
    /// is read in - year, then month, then day - instead of interleaving labels
    /// and values on one line.
    ///
    /// The caption is the visible label but the picker stays untitled, so the
    /// caption is what VoiceOver announces; the two must not both speak.
    private func column<Content: View>(
        label: String,
        minWidth: CGFloat,
        @ViewBuilder content: () -> Content,
        value: () -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .labelsHidden()
                .frame(minWidth: minWidth)
                .accessibilityLabel(label)
                .accessibilityValue(value())
        }
    }
}

private struct BSPickers: View {
    @Bindable var model: ConverterModel
    let settings: DisplaySettings

    var body: some View {
        DatePickers(
            yearLabel: Strings.yearLabel,
            monthLabel: Strings.monthLabel,
            dayLabel: Strings.dayLabel,
            year: $model.bsYear,
            month: $model.bsMonth,
            day: $model.bsDay,
            years: model.bsYears,
            yearText: { formatNumber($0, digits: settings.digits) },
            months: Array(1 ... 12),
            monthText: { monthName(month: $0, style: settings.monthNames) },
            days: Array(1 ... model.daysInBSMonth(year: model.bsYear, month: model.bsMonth)),
            dayText: { formatNumber($0, digits: settings.digits) },
            spokenYear: { SpokenDate.number($0) },
            spokenMonth: { monthName(month: $0, style: settings.monthNames) },
            spokenDay: { SpokenDate.number($0) }
        )
    }
}

private struct ADPickers: View {
    @Bindable var model: ConverterModel
    let settings: DisplaySettings

    var body: some View {
        DatePickers(
            yearLabel: Strings.yearLabel,
            monthLabel: Strings.monthLabel,
            dayLabel: Strings.dayLabel,
            year: $model.adYear,
            month: $model.adMonth,
            day: $model.adDay,
            years: model.adYears,
            yearText: { formatNumber($0, digits: settings.digits) },
            months: model.adMonths(year: model.adYear),
            monthText: { gregorianMonthNames[$0 - 1] },
            days: model.adDays(year: model.adYear, month: model.adMonth),
            dayText: { formatNumber($0, digits: settings.digits) },
            spokenYear: { SpokenDate.number($0) },
            spokenMonth: { gregorianMonthNames[$0 - 1] },
            spokenDay: { SpokenDate.number($0) }
        )
    }
}
