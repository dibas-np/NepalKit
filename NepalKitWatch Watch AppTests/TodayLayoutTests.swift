// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import SwiftUI
import Testing
import NepalKitCore
import NepalKitWatchSupport
@testable import NepalKitWatchApp

/// Each Today state fits the height it is offered, and keeps its own
/// composition where that fits. The short heights are below any real screen
/// on purpose (the xLarge hero is 104 pt; a 40 mm screen is 197 pt), so the
/// fallback is exercised.
@MainActor
struct TodayLayoutTests {
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
        // A scroll view fills the offered height; a composition takes its own.
        for state in try states() {
            let own = try renderedHeight(state.composition, proposed: nil)
            let rendered = try renderedHeight(TodayStateView(display: state.display), proposed: Self.roomy)
            #expect(own < Self.roomy, "\(state.name) is \(own) pt, so \(Self.roomy) pt proves nothing")
            #expect(rendered == own, "\(state.name) rendered \(rendered) pt, its composition is \(own) pt")
        }
    }

    private struct State {
        let name: String
        let display: WatchDayDisplay
        let composition: AnyView
    }

    private func renderedHeight(_ view: some View, proposed height: Double?) throws -> CGFloat {
        // The largest size below the large-text fallback.
        let renderer = ImageRenderer(content: view.environment(\.dynamicTypeSize, .xLarge))
        renderer.proposedSize = ProposedViewSize(width: 162, height: height.map { CGFloat($0) })
        let image = try #require(renderer.cgImage)
        return CGFloat(image.height) / renderer.scale
    }

    /// The widest hero measured, a day past the range, and an error with its date.
    private func states() throws -> [State] {
        let today = GregorianDate(year: 2026, month: 12, day: 17)
        let past = GregorianDate(year: 2030, month: 1, day: 1)
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
