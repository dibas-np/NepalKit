// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import SwiftUI
import NepalKitCore

enum PopoverDestination: String, CaseIterable {
    case today
    case convert

    var title: String {
        switch self {
        case .today: Strings.todayLabel
        case .convert: Strings.converterLabel
        }
    }
}

struct PopoverView: View {
    let settings: DisplaySettingsModel
    let clock: ClockModel
    let converter: ConverterModel
    let monthGrid: MonthGridModel
    @Environment(\.openSettings) private var openSettings
    let dataset: CalendarDataset
    let updates: UpdateCheckModel
    @State private var destination: PopoverDestination = .today

    private static let popoverWidth: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderBar(clock: clock, settings: settings.settings)

            DestinationTabs(selection: $destination)

            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    TodaySection(clock: clock, settings: settings.settings, dataset: dataset)
                    Divider()
                    MonthGridView(
                        model: monthGrid, settings: settings.settings, clock: clock,
                        isActive: destination == .today
                    )
                    ClocksSection(clock: clock, settings: settings.settings)
                }
                .destinationLayer(isShowing: destination == .today)

                ConverterView(model: converter, settings: settings.settings)
                    .destinationLayer(isShowing: destination == .convert)
            }
            .animation(.default, value: destination)
        }
        .padding()
        .frame(width: Self.popoverWidth)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await clock.refreshWhileVisible() }

        PopoverFooter(openSettings: { openSettings() }, updates: updates)
    }

}

extension View {
    fileprivate func destinationLayer(isShowing: Bool) -> some View {
        opacity(isShowing ? 1 : 0)
            .allowsHitTesting(isShowing)
            .disabled(!isShowing)
            .accessibilityHidden(!isShowing)
    }
}

#if DEBUG
#Preview("Popover") {
    PopoverView(
        settings: .preview,
        clock: ClockModel(now: AppData.previewInstant, refreshes: false),
        converter: ConverterModel(now: AppData.previewInstant),
        monthGrid: MonthGridModel(now: AppData.previewInstant),
        dataset: AppData.dataset,
        updates: UpdateCheckModel(service: PreviewUpdateService())
    )
    .padding()
}

#Preview("Popover, update available") {
    PopoverView(
        settings: .preview,
        clock: ClockModel(now: AppData.previewInstant, refreshes: false),
        converter: ConverterModel(now: AppData.previewInstant),
        monthGrid: MonthGridModel(now: AppData.previewInstant),
        dataset: AppData.dataset,
        updates: UpdateCheckModel(service: PreviewUpdateService(reporting: .updateAvailable))
    )
    .padding()
}
#endif

private struct HeaderBar: View {
    let clock: ClockModel
    let settings: DisplaySettings

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Strings.appName)
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(settings.digits.formatTime(.distantPast, in: .gmt))
                .hidden()
                .overlay(alignment: .trailing) {
                    HeaderClockTime(clock: clock, digits: settings.digits)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct HeaderClockTime: View {
    let clock: ClockModel
    let digits: DigitScript

    var body: some View {
        Text(clock.headerTimeString(digits: digits))
            .accessibilityLabel(
                "\(clock.headerClockLabel): \(clock.headerTimeString(digits: .latin))"
            )
    }
}

private struct ClocksSection: View {
    let clock: ClockModel
    let settings: DisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if clock.showsSecondaryClock {
                Divider()
                Label {
                    Text(settings.digits.formatTime(.distantPast, in: .gmt))
                        .hidden()
                        .overlay(alignment: .leading) {
                            SecondaryClockTime(clock: clock, digits: settings.digits)
                        }
                } icon: {
                    Text(clock.secondaryClockLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.title3)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
        .accessibilityElement(children: .contain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SecondaryClockTime: View {
    let clock: ClockModel
    let digits: DigitScript

    var body: some View {
        Text(clock.secondaryTimeString(digits: digits))
            .accessibilityLabel("\(clock.secondaryClockLabel): \(clock.secondaryTimeString(digits: .latin))")
    }
}
