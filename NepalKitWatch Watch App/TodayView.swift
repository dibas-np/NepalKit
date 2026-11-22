// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import SwiftUI
import NepalKitCore
import NepalKitWatchSupport

struct TodayView: View {
    #if NEPALKIT_WATCH_FIXTURES
    @State private var model = TodayFixtures.makeModel()
    @State private var fixtureNote = TodayFixtures.bannerNote
    #else
    @State private var model = TodayModel()
    #endif

    var body: some View {
        NavigationStack {
            Group {
                #if NEPALKIT_WATCH_FIXTURES
                if let fixtureNote {
                    Text(fixtureNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                #endif
                TodayScreen(model: model)
            }
            .navigationTitle("NepalKit")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct TodayScreen: View {
    let model: TodayModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        // Always On does not re-render ordinary content, so the dimmed screen
        // reads its day from the timeline's date.
        TimelineView(.everyMinute) { context in
            TodayStateView(display: isLuminanceReduced ? model.display(at: context.date) : model.display)
        }
        .task { model.activate() }
        .onChange(of: scenePhase) { _, phase in
            if shouldStayActive(in: phase) {
                model.activate()
            } else {
                model.deactivate()
            }
        }
    }
}

struct TodayStateView: View {
    let display: WatchDayDisplay?

    var body: some View {
        switch display {
        case nil:
            Color.clear
        case .some(.supported(let components)):
            TodaySupportedView(components: components)
        case .some(.rangeBoundary(let boundary)):
            TodayFittingView {
                TodayBoundaryView(boundary: boundary)
            }
        case .some(.calculationError(let components)):
            TodayFittingView {
                TodayErrorView(components: components)
            }
        }
    }
}

struct TodayFittingView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView {
                content
            }
        }
    }
}

/// `.inactive` stays active: an Always On screen is dimmed but still visible
/// and must roll over at Nepal midnight.
func shouldStayActive(in phase: ScenePhase) -> Bool {
    switch phase {
    case .active, .inactive:
        true
    case .background:
        false
    @unknown default:
        false
    }
}

struct TodaySupportedView: View {
    let components: WatchDayComponents

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.watchLargeTextFallback {
            TodayScrollingDateLinesView(components: components)
        } else {
            ViewThatFits(in: .vertical) {
                TodayHeroView(components: components)
                TodayScrollingDateLinesView(components: components)
            }
        }
    }
}

struct TodayHeroView: View {
    let components: WatchDayComponents

    var body: some View {
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
        .accessibilityLabel(components.todaySpokenLabel)
    }
}

struct TodayScrollingDateLinesView: View {
    let components: WatchDayComponents

    var body: some View {
        ScrollView {
            TodayDateLinesView(components: components)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(components.todaySpokenLabel)
        }
    }
}

extension WatchDayComponents {
    var todaySpokenLabel: String {
        ComplicationAccessibility.supportedLabel(self, weekday: true, gregorian: true)
    }
}

extension DynamicTypeSize {
    var watchLargeTextFallback: Bool {
        self >= .xxLarge
    }
}

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
