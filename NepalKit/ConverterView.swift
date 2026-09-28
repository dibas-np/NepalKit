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
            Picker(Strings.converterLabel, selection: Binding(
                get: { model.direction },
                set: { model.setDirection($0) }
            )) {
                Text(Strings.bsToAD).tag(ConverterDirection.bsToAD)
                Text(Strings.adToBS).tag(ConverterDirection.adToBS)
            }
            .pickerStyle(.segmented)

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
                Text(output)
                    .font(.headline)
            } else {
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
        Picker(Strings.yearLabel, selection: Binding(
            get: { model.bsYear },
            set: { model.bsYear = $0 }
        )) {
            ForEach(model.bsYears, id: \.self) { year in
                Text(formatNumber(year, digits: settings.digits)).tag(year)
            }
        }
        Picker(Strings.monthLabel, selection: Binding(
            get: { model.bsMonth },
            set: { model.bsMonth = $0 }
        )) {
            ForEach(1 ... 12, id: \.self) { month in
                Text(monthName(month: month, style: settings.monthNames)).tag(month)
            }
        }
        Picker(Strings.dayLabel, selection: Binding(
            get: { model.bsDay },
            set: { model.bsDay = $0 }
        )) {
            ForEach(1 ... model.daysInBSMonth(year: model.bsYear, month: model.bsMonth), id: \.self) { day in
                Text(formatNumber(day, digits: settings.digits)).tag(day)
            }
        }
    }
}

private struct ADPickers: View {
    @Bindable var model: ConverterModel
    let settings: DisplaySettings

    var body: some View {
        Picker(Strings.yearLabel, selection: Binding(
            get: { model.adYear },
            set: { model.adYear = $0 }
        )) {
            ForEach(model.adYears, id: \.self) { year in
                Text(formatNumber(year, digits: settings.digits)).tag(year)
            }
        }
        Picker(Strings.monthLabel, selection: Binding(
            get: { model.adMonth },
            set: { model.adMonth = $0 }
        )) {
            ForEach(model.adMonths(year: model.adYear), id: \.self) { month in
                Text(gregorianMonthNames[month - 1]).tag(month)
            }
        }
        Picker(Strings.dayLabel, selection: Binding(
            get: { model.adDay },
            set: { model.adDay = $0 }
        )) {
            ForEach(model.adDays(year: model.adYear, month: model.adMonth), id: \.self) { day in
                Text(formatNumber(day, digits: settings.digits)).tag(day)
            }
        }
    }
}
