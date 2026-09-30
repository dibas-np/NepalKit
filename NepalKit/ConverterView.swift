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
                    // Label only: `children: .ignore` leaves a `Text` with no role
                    // (same as the popover headline). Replacing the label keeps its
                    // static-text role.
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

/// One column of the converter's date pickers: the values to choose from,
/// the selection binding, and the two channels — what is shown and what is
/// spoken. Grouping them is what keeps a picker concern from being a
/// parameter on a fifteen-argument call.
///
/// The shown and spoken closures are deliberately separate members even
/// where they currently agree: they are different channels by contract
/// (SpokenDate's header), and welding them removes the seam the first
/// speech-specific divergence will need.
private struct PickerColumn {
    let label: String
    let minWidth: CGFloat
    let values: [Int]
    let selection: Binding<Int>
    let text: (Int) -> String
    let spoken: (Int) -> String
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
private struct DatePickers: View {
    let year: PickerColumn
    let month: PickerColumn
    let day: PickerColumn

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            column(year)
            // Widest of the three: "September" is nine characters, and a
            // Devanagari month name is longer again. Truncating the month to an
            // ellipsis defeats the point of a picker, since the month is the one
            // field a user is actually scanning to identify.
            column(month)
            column(day)
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
    private func column(_ column: PickerColumn) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(column.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("", selection: column.selection) {
                ForEach(column.values, id: \.self) { Text(column.text($0)).tag($0) }
            }
            .labelsHidden()
            .frame(minWidth: column.minWidth)
            .accessibilityLabel(column.label)
            .accessibilityValue(column.spoken(column.selection.wrappedValue))
        }
    }
}

private struct BSPickers: View {
    @Bindable var model: ConverterModel
    let settings: DisplaySettings

    var body: some View {
        DatePickers(
            year: PickerColumn(
                label: Strings.yearLabel, minWidth: 68, values: model.bsYears,
                selection: $model.bsYear,
                text: { formatNumber($0, digits: settings.digits) },
                spoken: { SpokenDate.number($0) }),
            month: PickerColumn(
                label: Strings.monthLabel, minWidth: 112, values: Array(1 ... 12),
                selection: $model.bsMonth,
                text: { monthName(month: $0, style: settings.monthNames) },
                spoken: { monthName(month: $0, style: settings.monthNames) }),
            day: PickerColumn(
                label: Strings.dayLabel, minWidth: 68,
                values: Array(1 ... model.daysInBSMonth(year: model.bsYear, month: model.bsMonth)),
                selection: $model.bsDay,
                text: { formatNumber($0, digits: settings.digits) },
                spoken: { SpokenDate.number($0) })
        )
    }
}

private struct ADPickers: View {
    @Bindable var model: ConverterModel
    let settings: DisplaySettings

    var body: some View {
        DatePickers(
            year: PickerColumn(
                label: Strings.yearLabel, minWidth: 68, values: model.adYears,
                selection: $model.adYear,
                text: { formatNumber($0, digits: settings.digits) },
                spoken: { SpokenDate.number($0) }),
            month: PickerColumn(
                label: Strings.monthLabel, minWidth: 112,
                values: model.adMonths(year: model.adYear),
                selection: $model.adMonth,
                text: { gregorianMonthName($0) },
                spoken: { gregorianMonthName($0) }),
            day: PickerColumn(
                label: Strings.dayLabel, minWidth: 68,
                values: model.adDays(year: model.adYear, month: model.adMonth),
                selection: $model.adDay,
                text: { formatNumber($0, digits: settings.digits) },
                spoken: { SpokenDate.number($0) })
        )
    }
}

#if DEBUG
#Preview("Converter") {
    ConverterView(
        model: ConverterModel(now: AppData.previewInstant),
        settings: DisplaySettings(digits: .latin, monthNames: .transliterated)
    )
    .padding()
    .frame(width: 340)
}
#endif
