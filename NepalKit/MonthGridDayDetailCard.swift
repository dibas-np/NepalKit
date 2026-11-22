// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

struct MonthGridDayDetailCard: View {
    let detail: MonthGridDayDetail
    let copy: () -> Void
    let addToCalendar: () -> Void
    var addToCalendarFailed = false
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(detail.bikramSambat)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(detail.spokenBikramSambat)
                    Spacer(minLength: 0)
                    Button(Strings.closeDayDetailsLabel, systemImage: Symbols.closeDetails.rawValue, action: close)
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
