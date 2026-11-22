// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import WidgetKit
import NepalKitCore
import NepalKitWatchSupport

struct TodayComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayComplicationEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                TodayRectangularComplication(state: entry.state)
            case .accessoryInline:
                TodayInlineComplication(state: entry.state)
            case .accessoryCircular:
                TodayCircularComplication(state: entry.state)
            case .accessoryCorner:
                TodayCornerComplication(state: entry.state)
            default:
                TodayInlineComplication(state: entry.state)
            }
        }
        .containerBackground(for: .widget) {
            // Accessory widgets must declare a container background.
        }
    }
}

/// The watchOS Text Size slider stops below the accessibility sizes, so
/// `isAccessibilitySize` never fires.
extension DynamicTypeSize {
    var watchLargeTextFallback: Bool {
        self >= .xxLarge
    }
}

struct TodayRectangularComplication: View {
    let state: TodayComplicationState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        switch state {
        case .placeholder:
            Text("NepalKit")
        case .day(.supported(let components)):
            if dynamicTypeSize.watchLargeTextFallback {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(components.bikramSambatDay) \(components.bikramSambatMonthName)")
                        .font(.title3)
                    Text(components.bikramSambatYear)
                        .font(.body)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ComplicationAccessibility.supportedLabel(components, weekday: false, gregorian: false))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(components.weekdayName) · \(components.bikramSambatYear)\(ComplicationFixtureMarker.suffix)")
                        .font(.caption2.weight(.semibold))
                        .widgetAccentable()
                    Text("\(components.bikramSambatDay) \(components.bikramSambatMonthName)")
                        .font(.title3)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ComplicationAccessibility.supportedLabel(components, weekday: true, gregorian: false))
            }
        case .day(.rangeBoundary(let boundary)):
            VStack(alignment: .leading, spacing: 2) {
                Text(WatchDayCopy.boundaryCompact)
                    .font(.headline)
                Text(boundary.compactContextLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ComplicationAccessibility.boundaryLabel(boundary, gregorian: false))
        case .day(.calculationError(let components)):
            VStack(alignment: .leading) {
                Text(WatchDayCopy.failureFull)
                    .font(.headline)
                if let day = components.gregorianDay,
                   let month = components.gregorianMonthName,
                   let year = components.gregorianYear {
                    Text("\(day) \(month) \(year)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(components.spokenDescription)
        }
    }
}

struct TodayInlineComplication: View {
    let state: TodayComplicationState

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        switch state {
        case .placeholder:
            Text("NepalKit")
        case .day(.supported(let components)):
            Group {
                if dynamicTypeSize.watchLargeTextFallback {
                    Text("\(components.bikramSambatDay) \(components.bikramSambatMonthName)")
                } else {
                    Text("\(components.bikramSambatDay) \(components.bikramSambatMonthName) \(components.bikramSambatYear)\(ComplicationFixtureMarker.suffix)")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ComplicationAccessibility.supportedLabel(components, weekday: false, gregorian: false))
        case .day(.rangeBoundary(let boundary)):
            Text(WatchDayCopy.boundaryCompact)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ComplicationAccessibility.boundaryLabel(boundary))
        case .day(.calculationError(let components)):
            Text(WatchDayCopy.failureCompact)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(components.spokenDescription)
        }
    }
}

struct TodayCircularComplication: View {
    let state: TodayComplicationState

    var body: some View {
        switch state {
        case .placeholder:
            Text("NepalKit")
        case .day(.supported(let components)):
            VStack {
                Text(components.bikramSambatDay)
                    .font(.title3)
                Text(components.bikramSambatMonthName)
                    .font(.caption)
            }
            // Optically centers the stack in the Infograph subdial.
            .padding(.bottom, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ComplicationAccessibility.supportedLabel(components, weekday: false, gregorian: false))
        case .day(.rangeBoundary(let boundary)):
            Text(WatchDayCopy.boundaryCompact)
                .font(.caption)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ComplicationAccessibility.boundaryLabel(boundary))
        case .day(.calculationError(let components)):
            Text(WatchDayCopy.failureCompact)
                .font(.caption)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(components.spokenDescription)
        }
    }
}

struct TodayCornerComplication: View {
    let state: TodayComplicationState

    var body: some View {
        switch state {
        case .placeholder:
            Text("NepalKit")
        case .day(.supported(let components)):
            Text(components.bikramSambatDay)
                .font(.title3)
                .widgetLabel {
                    Text("\(components.bikramSambatMonthName) \(components.bikramSambatYear)")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ComplicationAccessibility.supportedLabel(components, weekday: false, gregorian: false))
        case .day(.rangeBoundary(let boundary)):
            Text(WatchDayCopy.boundaryCompact)
                .font(.caption)
                .widgetLabel {
                    Text("\(boundary.gregorianDay) \(boundary.gregorianMonthName)")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ComplicationAccessibility.boundaryLabel(boundary, gregorian: true))
        case .day(.calculationError(let components)):
            Text(WatchDayCopy.failureCompact)
                .font(.caption)
                .widgetLabel {
                    if let day = components.gregorianDay,
                       let month = components.gregorianMonthName {
                        Text("\(day) \(month)")
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(components.spokenDescription)
        }
    }
}
