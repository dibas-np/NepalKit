// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import SwiftUI
import Testing
import NepalKitCore
@testable import NepalKitWatchApp

/// Each Today state fits the height it is offered, and keeps its own
/// composition wherever that composition fits.
///
/// The supported day's hero is chosen by text size, at below xxLarge, and that
/// threshold was set when Today had the whole screen. The inline "NepalKit"
/// title now takes a row of it, from every state, so each state also gives way
/// to a scroll view when it does not fit, whatever the text size. Measured in
/// the simulator, the hero at xLarge is 104 pt tall on a 197 pt (40 mm) screen,
/// so on today's devices it fits. The short heights here are below that on
/// purpose, so the test exercises the fallback rather than describing a device.
@MainActor
struct TodayLayoutTests {
    /// Short enough that no state fits, and tall enough that every state does.
    nonisolated private static let cramped = 40.0
    nonisolated private static let roomy = 300.0

    @Test(arguments: [cramped, 90.0, roomy])
    func everyStateRendersWithinTheHeightItIsOffered(height: Double) throws {
        for state in try states() {
            let rendered = try renderedHeight(TodayStateView(display: state.display), proposed: height)
            #expect(rendered <= height, "\(state.name) rendered \(rendered) pt in \(height) pt")
        }
    }

    @Test func everyStateKeepsItsOwnCompositionWhereItFits() throws {
        // A scroll view takes the whole height it is offered; the compositions
        // take only their own. So a state rendered at its own height, not the
        // offered one, is the composition and not the fallback.
        for state in try states() {
            let own = try renderedHeight(state.composition, proposed: nil)
            let rendered = try renderedHeight(TodayStateView(display: state.display), proposed: Self.roomy)
            #expect(own < Self.roomy, "\(state.name) is \(own) pt, so \(Self.roomy) pt proves nothing")
            #expect(rendered == own, "\(state.name) rendered \(rendered) pt, its composition is \(own) pt")
        }
    }

    /// A display state, and the composition it shows wherever that fits.
    private struct State {
        let name: String
        let display: WatchDayDisplay
        let composition: AnyView
    }

    private func renderedHeight(_ view: some View, proposed height: Double?) throws -> CGFloat {
        // xLarge is the largest size below the large-text fallback, so it is the
        // tallest hero the text-size rule alone allows.
        let renderer = ImageRenderer(content: view.environment(\.dynamicTypeSize, .xLarge))
        renderer.proposedSize = ProposedViewSize(width: 162, height: height.map { CGFloat($0) })
        let image = try #require(renderer.cgImage)
        return CGFloat(image.height) / renderer.scale
    }

    /// 17 December 2026 is Thursday 2 Poush 2083, the widest hero among the
    /// weekday and month names measured; 1 January 2030 is past the supported
    /// range; the error carries a resolved Gregorian date, its taller form.
    private func states() throws -> [State] {
        let today = GADay(year: 2026, month: 12, day: 17)
        let past = GADay(year: 2030, month: 1, day: 1)
        guard case .supported(let supported) = watchDayDisplay(for: today, settings: .watch, in: .v2),
              case .rangeBoundary(let boundary) = watchDayDisplay(for: past, settings: .watch, in: .v2),
              case .calculationError(let error) = watchCalculationErrorDisplay(gregorianDay: today, settings: .watch)
        else {
            throw DayResolutionError.datasetAssumptionFailure(today)
        }
        return [
            State(name: "supported", display: .supported(supported),
                  composition: AnyView(TodayHeroView(components: supported))),
            State(name: "boundary", display: .rangeBoundary(boundary),
                  composition: AnyView(TodayBoundaryView(boundary: boundary))),
            State(name: "error", display: .calculationError(error),
                  composition: AnyView(TodayErrorView(components: error))),
        ]
    }
}
