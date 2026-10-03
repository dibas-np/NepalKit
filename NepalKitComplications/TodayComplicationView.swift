// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import WidgetKit
import NepalKitCore

/// Renders a Today entry in whichever accessory family the face slot asks
/// for, per the accepted Day-first composition. Views render the supplied
/// state only — no clock reads, no date resolution, no color carrying
/// meaning: every state is distinct text, so full-color, accented and
/// redacted rendering modes cannot obscure the distinction and
/// `widgetRenderingMode` needs no branch here.
///
/// The large-text fallbacks swap composition deterministically at
/// accessibility text sizes rather than truncating or shrinking.
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
            // watchOS 10+ accessory widgets must declare their container
            // background; the complication supplies none of its own.
        }
    }
}

/// Rectangular: one weekday and the Bikram Sambat day/month, with the year
/// and the corresponding Gregorian day/month on a secondary line. At
/// accessibility sizes the weekday and Gregorian detail are removed first,
/// preserving day/month then year — and the announced label drops what the
/// visuals dropped.
/// The threshold where Watch compositions switch to their large-text
/// fallbacks. The watchOS Text Size slider's maximum stops below the
/// accessibility size categories, so `isAccessibilitySize` never fires there;
/// xxLarge is the first size at which the default compositions measurably
/// clip. Deliberately duplicated per module: core does not import SwiftUI.
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
                // Two lines are all a real Modular middle slot fits, and
                // the first attempt put the weekday on the day/month line —
                // which truncated the month. The day/month stands alone;
                // the weekday joins the year on the secondary line, and the
                // optional Gregorian piece leaves the visuals entirely.
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(components.bikramSambatDay) \(components.bikramSambatMonthName)")
                        .font(.title3)
                    Text("\(components.weekdayName) · \(components.bikramSambatYear)\(ComplicationFixtureMarker.suffix)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ComplicationAccessibility.supportedLabel(components, weekday: true, gregorian: false))
            }
        case .day(.rangeBoundary(let boundary)):
            VStack(alignment: .leading) {
                Text(WatchDayCopy.boundaryFull)
                    .font(.headline)
                Text(boundary.contextLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(boundary.gregorianDay) \(boundary.gregorianMonthName) \(boundary.gregorianYear)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ComplicationAccessibility.boundaryLabel(boundary, gregorian: true))
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
            .accessibilityLabel(ComplicationAccessibility.errorLabel(components))
        }
    }
}

/// Inline: the full Bikram Sambat day/month/year on one line; at
/// accessibility sizes the year leaves the visuals but stays in speech.
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
                .accessibilityLabel(ComplicationAccessibility.errorLabel(components))
        }
    }
}

/// Circular: the stacked Bikram Sambat day and month; the composition holds
/// at accessibility sizes and the announced year fills the gap.
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
            // The stacked stack renders slightly low in the Infograph inner
            // subdial's optical circle; this small lift centers it.
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
                .accessibilityLabel(ComplicationAccessibility.errorLabel(components))
        }
    }
}

/// Corner: the Bikram Sambat day, with the month/year in the native
/// `widgetLabel` — the family's own supplementary slot, which stays even at
/// accessibility sizes.
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
                .accessibilityLabel(ComplicationAccessibility.errorLabel(components))
        }
    }
}
