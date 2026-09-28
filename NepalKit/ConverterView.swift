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
                    Picker(Strings.yearLabel, selection: Binding(
                        get: { model.bsYear },
                        set: { model.bsYear = $0; model.clampBSDay() }
                    )) {
                        ForEach(model.bsYears, id: \.self) { year in
                            Text(formatYear(year)).tag(year)
                        }
                    }
                    Picker(Strings.monthLabel, selection: Binding(
                        get: { model.bsMonth },
                        set: { model.bsMonth = $0; model.clampBSDay() }
                    )) {
                        ForEach(1 ... 12, id: \.self) { month in
                            Text(bsMonthName(month)).tag(month)
                        }
                    }
                    Picker(Strings.dayLabel, selection: $model.bsDay) {
                        ForEach(1 ... model.daysInBSMonth(year: model.bsYear, month: model.bsMonth), id: \.self) { day in
                            Text(formatDay(day)).tag(day)
                        }
                    }
                }
            case .adToBS:
                HStack {
                    Picker(Strings.yearLabel, selection: Binding(
                        get: { model.adYear },
                        set: { model.adYear = $0; model.clampADDate() }
                    )) {
                        ForEach(model.adYears, id: \.self) { year in
                            Text(formatYear(year)).tag(year)
                        }
                    }
                    Picker(Strings.monthLabel, selection: Binding(
                        get: { model.adMonth },
                        set: { model.adMonth = $0; model.clampADDate() }
                    )) {
                        ForEach(model.adMonths(year: model.adYear), id: \.self) { month in
                            Text(gregorianMonthNames[month - 1]).tag(month)
                        }
                    }
                    Picker(Strings.dayLabel, selection: $model.adDay) {
                        ForEach(1 ... model.daysInADMonth(year: model.adYear, month: model.adMonth), id: \.self) { day in
                            Text(formatDay(day)).tag(day)
                        }
                    }
                }
            }

            if let output = model.result(settings: settings) {
                Text(output)
                    .font(.headline)
            } else {
                Text(Strings.converterOutOfRange)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatYear(_ year: Int) -> String {
        formatNumber(year, digits: settings.digits)
    }

    private func formatDay(_ day: Int) -> String {
        formatNumber(day, digits: settings.digits)
    }

    private func bsMonthName(_ month: Int) -> String {
        switch settings.monthNames {
        case .nepali: return nepaliMonthNames[month - 1]
        case .transliterated: return transliteratedMonthNames[month - 1]
        }
    }
}
