// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import WidgetKit

#Preview("Rectangular — supported", as: .accessoryRectangular) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.supportedState())
}

#Preview("Rectangular — boundary and error", as: .accessoryRectangular) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.boundaryState())
    TodayComplicationEntry(date: .now, state: ComplicationSamples.errorState())
}

#Preview("Inline — supported", as: .accessoryInline) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.supportedState())
}

#Preview("Inline — boundary and error", as: .accessoryInline) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.boundaryState())
    TodayComplicationEntry(date: .now, state: ComplicationSamples.errorState())
}

#Preview("Circular — supported", as: .accessoryCircular) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.supportedState())
}

#Preview("Circular — boundary and error", as: .accessoryCircular) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.boundaryState())
    TodayComplicationEntry(date: .now, state: ComplicationSamples.errorState())
}

#Preview("Corner — supported", as: .accessoryCorner) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.supportedState())
}

#Preview("Corner — boundary and error", as: .accessoryCorner) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.boundaryState())
    TodayComplicationEntry(date: .now, state: ComplicationSamples.errorState())
}

#Preview("Corner — longest month", as: .accessoryCorner) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.longestMonthState())
}

#Preview("Rectangular — longest month", as: .accessoryRectangular) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.longestMonthState())
}

#Preview("Placeholder", as: .accessoryRectangular) {
    TodayComplication()
} timeline: {
    TodayComplicationEntry(date: .now, state: ComplicationSamples.placeholderState())
}
