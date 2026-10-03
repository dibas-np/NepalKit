// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore

/// Today, the Watch app's sole destination: the current Bikram Sambat date
/// and its corresponding Gregorian date for the Nepal Time day. Complication
/// taps and app launch both land here; there are no settings, converters or
/// controls.
///
/// The model is owned with `@State`, computes at launch, refreshes at the
/// next Nepal midnight while active, recomputes on reactivation, and follows
/// system clock changes — all lifecycle behavior lives in `TodayModel`; this
/// view only wires the scene phase to it.
struct TodayView: View {
    #if NEPALKIT_WATCH_FIXTURES
    @State private var model = TodayFixtures.makeModel()
    @State private var fixtureNote = TodayFixtures.bannerNote
    #else
    @State private var model = TodayModel()
    #endif

    var body: some View {
        #if NEPALKIT_WATCH_FIXTURES
        Group {
            if let fixtureNote {
                // The active fixture identifies itself on screen.
                Text(fixtureNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            TodayScreen(model: model)
        }
        #else
        TodayScreen(model: model)
        #endif
    }
}

/// The screen itself: renders the model's display state and wires the scene
/// phase to the lifecycle, so activation, the midnight refresh and
/// clock-change handling all follow the app to the foreground and background.
struct TodayScreen: View {
    let model: TodayModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.display {
            case nil:
                // Launch window only: the first activation resolves Today
                // immediately, so there is nothing to promise here yet.
                Text("NepalKit")
            case .some(.supported(let components)):
                TodaySupportedView(components: components)
            case .some(.rangeBoundary(let boundary)):
                TodayBoundaryView(boundary: boundary)
            case .some(.calculationError(let components)):
                TodayErrorView(components: components)
            }
        }
        .task { model.activate() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.activate()
            case .background, .inactive:
                model.deactivate()
            @unknown default:
                model.deactivate()
            }
        }
    }
}

/// The supported day in the accepted Day-first composition: one weekday, a
/// prominent Bikram Sambat day, month and year, and the full corresponding
/// Gregorian date. At accessibility text sizes the hero treatment gives way
/// to full date lines with scrolling, so every part stays readable — the
/// deterministic fallback the accepted presentation selected instead of
/// truncation or shrinking.
struct TodaySupportedView: View {
    let components: WatchDayComponents

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.watchLargeTextFallback {
            ScrollView {
                TodayDateLinesView(components: components)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(spokenLabel)
            }
        } else {
            VStack {
                Text(components.weekdayName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(components.bikramSambatDay)
                    .font(.largeTitle.bold())
                Text("\(components.bikramSambatMonthName) \(components.bikramSambatYear)")
                    .font(.title3)
                Text("\(components.gregorianDay) \(components.gregorianMonthName) \(components.gregorianYear)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(spokenLabel)
        }
    }

    /// Core supplies the spoken pieces: one weekday, the full Bikram Sambat
    /// date with Latin digits, and the Gregorian date presented here.
    private var spokenLabel: String {
        ComplicationAccessibility.supportedLabel(components, weekday: true, gregorian: true)
    }
}

/// The threshold where Today switches to its scrollable full-date-lines
/// fallback; matches the complication threshold (see the extension's
/// DynamicTypeSize extension). Deliberately duplicated per module: core does
/// not import SwiftUI.
extension DynamicTypeSize {
    var watchLargeTextFallback: Bool {
        self >= .xxLarge
    }
}

/// The large-text fallback for Today: full date lines, scrollable, nothing
/// dropped.
struct TodayDateLinesView: View {
    let components: WatchDayComponents

    var body: some View {
        VStack(alignment: .leading) {
            Text(components.weekdayName)
            Text("\(components.bikramSambatDay) \(components.bikramSambatMonthName) \(components.bikramSambatYear)")
            Text("\(components.gregorianDay) \(components.gregorianMonthName) \(components.gregorianYear)")
        }
        .font(.body)
    }
}

/// The expected range boundary: a plain statement that the Bikram Sambat date
/// is unavailable, naming the applicable supported year, beside the Gregorian
/// date that remains answerable.
struct TodayBoundaryView: View {
    let boundary: WatchBoundaryComponents

    var body: some View {
        VStack {
            Text(WatchDayCopy.boundaryFull)
                .font(.headline)
            Text(boundary.contextLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("\(boundary.gregorianDay) \(boundary.gregorianMonthName) \(boundary.gregorianYear)")
                .font(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ComplicationAccessibility.boundaryLabel(boundary, gregorian: true))
    }
}

/// A calculation failure: identified as a defect, never disguised as an
/// ordinary boundary. The Gregorian date appears only when one was actually
/// resolved.
struct TodayErrorView: View {
    let components: WatchErrorComponents

    var body: some View {
        VStack {
            Text(WatchDayCopy.failureFull)
                .font(.headline)
            if let day = components.gregorianDay,
               let month = components.gregorianMonthName,
               let year = components.gregorianYear {
                Text("\(day) \(month) \(year)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(components.spokenDescription)
    }
}
