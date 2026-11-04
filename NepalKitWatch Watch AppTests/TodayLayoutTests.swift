// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import SwiftUI
import Testing
import NepalKitCore
@testable import NepalKitWatchApp

/// Today's supported day never renders taller than the height it is offered.
///
/// The hero is chosen by text size, at below xxLarge, and that threshold was
/// set when Today had the whole screen. The inline "NepalKit" title now takes a
/// row of it, so the hero also has to give way to the scrolling date lines when
/// it does not fit, whatever the text size. Measured in the simulator, the hero
/// at xLarge is 104 pt tall on a 197 pt (40 mm) screen, so on today's devices
/// it fits. These heights are below that on purpose, so the test exercises the
/// fallback rather than describing a device.
@MainActor
struct TodayLayoutTests {
    @Test(arguments: [60.0, 90.0, 300.0])
    func theSupportedDayNeverRendersTallerThanItsSpace(height: Double) throws {
        // xLarge is the largest size below the large-text fallback, so it is the
        // tallest hero the text-size rule alone allows.
        let renderer = ImageRenderer(
            content: TodaySupportedView(components: try widestComponents())
                .environment(\.dynamicTypeSize, .xLarge)
        )
        renderer.proposedSize = ProposedViewSize(width: 162, height: height)
        let image = try #require(renderer.cgImage)

        #expect(CGFloat(image.height) / renderer.scale <= height)
    }

    /// 17 December 2026 is Thursday 2 Poush 2083, the widest hero the probe
    /// found among the weekday and month names.
    private func widestComponents() throws -> WatchDayComponents {
        let day = GADay(year: 2026, month: 12, day: 17)
        guard case .supported(let components) = watchDayDisplay(for: day, settings: .watch, in: .v2) else {
            throw DayResolutionError.datasetAssumptionFailure(day)
        }
        return components
    }
}
