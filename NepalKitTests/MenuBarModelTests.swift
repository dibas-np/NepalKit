import AppKit
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

struct MidnightFireIntervalTests {
    @Test func intervalSpansTheSixHoursFifteenMinutesToMidnight() throws {
        let interval = MenuBarModel.midnightFireInterval(after: try TestDates.utc(2026, 9, 27, 12, 0))
        #expect(interval == TimeInterval(6 * 3600 + 15 * 60 + 1))
    }

    @Test func intervalOneSecondBeforeMidnightIsTwoSeconds() throws {
        // 18:14:59 UTC: next midnight is 18:15:00, +1s guard makes 2.
        let interval = MenuBarModel.midnightFireInterval(after: try TestDates.utc(2026, 9, 26, 18, 14, 59))
        #expect(interval == 2)
    }

    @Test func intervalAtMidnightTargetsTomorrow() throws {
        let interval = MenuBarModel.midnightFireInterval(after: try TestDates.utc(2026, 9, 26, 18, 15, 0))
        #expect(interval == TimeInterval(24 * 3600 + 1))
    }
}

/// Counts what a model adds and removes, so a leaked observer shows up as an
/// imbalance rather than going unseen. Nonisolated because it overrides
/// nonisolated `NotificationCenter` members; the tests only touch it from the
/// main actor.
nonisolated final class RecordingCenter: NotificationCenter, @unchecked Sendable {
    private(set) var added = 0
    private(set) var removed = 0

    override func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping @Sendable (Notification) -> Void
    ) -> any NSObjectProtocol {
        added += 1
        return super.addObserver(forName: name, object: obj, queue: queue, using: block)
    }

    override func removeObserver(_ observer: Any) {
        removed += 1
        super.removeObserver(observer)
    }
}

/// Timer intervals do not advance while the Mac sleeps, so wake and a system
/// clock change are observed directly. Posted here on private centers, so no
/// test has to sleep the Mac or change its clock.
@MainActor
struct ClockDiscontinuityTests {
    // Before the dataset range ends and long before any run of this suite, so
    // a refresh is visible as `now` moving forward.
    private static func stale() throws -> Date { try TestDates.utc(2026, 9, 27, 12, 0) }

    @Test func refreshAfterClockDiscontinuityRereadsTheClock() throws {
        let stale = try Self.stale()
        let model = MenuBarModel(now: stale, refreshes: false, schedulesMidnightFire: false)

        model.refreshAfterClockDiscontinuity()

        #expect(model.now > stale)
    }

    @Test(arguments: [true, false])
    func wakeRereadsTheClock(schedulesMidnightFire: Bool) throws {
        let stale = try Self.stale()
        let workspace = RecordingCenter()
        let model = MenuBarModel(
            now: stale,
            schedulesMidnightFire: schedulesMidnightFire,
            workspaceNotifications: workspace,
            systemNotifications: RecordingCenter()
        )

        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)

        #expect(model.now > stale)
    }

    @Test func systemClockChangeRereadsTheClock() throws {
        let stale = try Self.stale()
        let system = RecordingCenter()
        let model = MenuBarModel(
            now: stale,
            schedulesMidnightFire: false,
            workspaceNotifications: RecordingCenter(),
            systemNotifications: system
        )

        system.post(name: .NSSystemClockDidChange, object: nil)

        #expect(model.now > stale)
    }

    @Test func systemTimeZoneChangeRereadsTheClock() throws {
        let stale = try Self.stale()
        let system = RecordingCenter()
        let model = MenuBarModel(
            now: stale,
            schedulesMidnightFire: false,
            workspaceNotifications: RecordingCenter(),
            systemNotifications: system
        )

        system.post(name: .NSSystemTimeZoneDidChange, object: nil)

        #expect(model.now > stale)
    }

    @Test func aModelThatDoesNotRefreshAddsNoObservers() throws {
        let stale = try Self.stale()
        let workspace = RecordingCenter()
        let system = RecordingCenter()
        let model = MenuBarModel(
            now: stale,
            refreshes: false,
            schedulesMidnightFire: false,
            workspaceNotifications: workspace,
            systemNotifications: system
        )

        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        system.post(name: .NSSystemClockDidChange, object: nil)

        #expect(workspace.added == 0 && system.added == 0)
        #expect(model.now == stale)
    }

    @Test func releasingTheModelRemovesItsObservers() throws {
        let workspace = RecordingCenter()
        let system = RecordingCenter()
        weak var released: MenuBarModel?
        do {
            let model = MenuBarModel(
                now: try Self.stale(),
                workspaceNotifications: workspace,
                systemNotifications: system
            )
            released = model
            // Wake on the workspace; clock and time zone changes on the system center.
            #expect(workspace.added == 1 && system.added == 2)
        }

        #expect(released == nil)
        #expect(workspace.removed == workspace.added)
        #expect(system.removed == system.added)
        // A post after release reaches no block, and nothing traps.
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        system.post(name: .NSSystemClockDidChange, object: nil)
    }
}

/// The menu bar's timers must keep firing while a menu is tracking, which runs
/// the main run loop in the event-tracking mode rather than the default one.
@MainActor
struct MainActorTimerModeTests {
    @Test func timerFiresInTheEventTrackingMode() {
        // AppKit adds event tracking to the common modes when NSApplication
        // starts; the test process has no NSApplication, so it is added here.
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(RunLoop.Mode.eventTracking.rawValue as CFString))
        var fired = false
        let timer = scheduledMainActorTimer(withTimeInterval: 0.01, repeats: false) {
            fired = true
        }
        defer { timer.invalidate() }

        let deadline = Date.now.addingTimeInterval(2)
        while !fired, Date.now < deadline {
            _ = RunLoop.main.run(mode: .eventTracking, before: Date.now.addingTimeInterval(0.05))
        }

        #expect(fired)
    }
}
