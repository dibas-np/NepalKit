// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

/// Bikram Sambat ↔ Gregorian converter with a direction toggle and bounded pickers.
struct ConverterView: View {
    @Bindable var model: ConverterModel
    let settings: DisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Named so VoiceOver says what the segments govern.
            Picker(Strings.converterDirectionLabel, selection: $model.directionSelection) {
                // Abbreviated on screen, spoken in full: full names clipped at 340pt.
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
                // "Result" is spoken only: read aloud, the date alone doesn't say which calendar
                // it is in.
                Text(output)
                    .font(.headline)
                    // Label only: `children: .ignore` would drop the static-text role.
                    .accessibilityLabel(
                        [Strings.converterResultLabel, model.spokenResult(settings: settings) ?? output]
                            .joined(separator: ": ")
                    )
                if model.resultIsProvisional {
                    // Hidden from VoiceOver: the result's label already speaks it.
                    Text(Strings.converterProvisionalNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            } else {
                Text(Strings.converterOutOfRange)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// One picker column: the values, the selection, and the shown and spoken text.
private struct PickerColumn {
    let label: String
    let minWidth: CGFloat
    let values: [Int]
    let selection: Binding<Int>
    let text: (Int) -> String
    let spoken: (Int) -> String
}

/// Layout shared by both directions' pickers. Minimum widths stop the pickers
/// collapsing in the 340pt popover.
private struct DatePickers: View {
    let year: PickerColumn
    let month: PickerColumn
    let day: PickerColumn

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            column(year)
            // Widest: month names, especially in Devanagari, are the longest values.
            column(month)
            column(day)
        }
    }

    /// A caption above an untitled picker: a titled macOS `Picker` puts its title on
    /// the value's line and clips it. The caption is the accessibility label.
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
                text: { settings.digits.format($0) },
                spoken: { SpokenDate.number($0) }),
            month: PickerColumn(
                label: Strings.monthLabel, minWidth: 112, values: Array(1 ... 12),
                selection: $model.bsMonth,
                text: { BikramSambatDate.monthName($0, style: settings.monthNames) },
                spoken: { BikramSambatDate.monthName($0, style: settings.monthNames) }),
            day: PickerColumn(
                label: Strings.dayLabel, minWidth: 68,
                values: Array(1 ... model.daysInBSMonth(year: model.bsYear, month: model.bsMonth)),
                selection: $model.bsDay,
                text: { settings.digits.format($0) },
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
                text: { settings.digits.format($0) },
                spoken: { SpokenDate.number($0) }),
            month: PickerColumn(
                label: Strings.monthLabel, minWidth: 112,
                values: model.adMonths(year: model.adYear),
                selection: $model.adMonth,
                text: { GregorianDate.monthName($0) },
                spoken: { GregorianDate.monthName($0) }),
            day: PickerColumn(
                label: Strings.dayLabel, minWidth: 68,
                values: model.adDays(year: model.adYear, month: model.adMonth),
                selection: $model.adDay,
                text: { settings.digits.format($0) },
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
