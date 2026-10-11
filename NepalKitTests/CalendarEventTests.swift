// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

/// "Add to Calendar": the event a day becomes, and the iCalendar file that
/// carries it to the calendar app.
@MainActor
struct CalendarEventTests {
    private let latin = DisplaySettings(digits: .latin, monthNames: .transliterated)
    private let nepali = DisplaySettings(digits: .devanagari, monthNames: .nepali)

    private func kartik2083() throws -> MonthGridModel {
        MonthGridModel(now: try TestDates.utc(2026, 10, 18, 6, 0))
    }

    private func day(_ model: MonthGridModel, _ day: Int) throws -> MonthGridDay {
        try #require(model.weeks.flatMap { $0 }.compactMap { $0 }.first { $0.isInShownMonth && $0.bikramSambat.day == day })
    }

    @Test func aFestivalDayIsTitledByItsFestivals() throws {
        let model = try kartik2083()
        // 4 Kartik 2083: Vijaya Dashami, a Dashain public holiday.
        let event = model.calendarEvent(for: try day(model, 4), settings: latin)
        #expect(event.title.contains("Vijaya Dashami"))
        #expect(event.date == GADay(year: 2026, month: 10, day: 21))
        #expect(event.notes.hasPrefix("4 Kartik 2083 · 21 October 2026"))
        #expect(event.notes.contains("Public holiday"))
    }

    @Test func aPlainDayIsTitledByItsBikramSambatDate() throws {
        let model = try kartik2083()
        // 9 Kartik 2083 has no festival and is a working day.
        let event = model.calendarEvent(for: try day(model, 9), settings: latin)
        #expect(event.title == "9 Kartik 2083")
        #expect(!event.notes.contains("\n"))
    }

    @Test func theEventFollowsTheMonthNameSetting() throws {
        let model = try kartik2083()
        let event = model.calendarEvent(for: try day(model, 9), settings: nepali)
        #expect(event.title == "९ कात्तिक २०८३")
    }

    @Test func theFileIsAnAllDayEventOnTheGregorianDay() throws {
        let event = CalendarEvent(title: "Vijaya Dashami", notes: "4 Kartik 2083", date: GADay(year: 2026, month: 10, day: 21))
        let stamp = try TestDates.utc(2026, 10, 11, 14, 30)
        let ics = event.ics(stamp: stamp)
        #expect(ics.hasPrefix("BEGIN:VCALENDAR\r\n"))
        #expect(ics.hasSuffix("END:VCALENDAR\r\n"))
        #expect(ics.contains("\r\nDTSTART;VALUE=DATE:20261021\r\n"))
        #expect(!ics.contains("DTEND"))
        #expect(ics.contains("\r\nDTSTAMP:20261011T143000Z\r\n"))
        #expect(ics.contains("\r\nUID:nepalkit-2026-10-21@nepalkit\r\n"))
        // Every line ends in CRLF; no bare LF.
        #expect(!ics.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
    }

    @Test func textIsEscaped() {
        #expect(CalendarEvent.escape("a,b;c\\d\ne") == "a\\,b\\;c\\\\d\\ne")
    }

    @Test func longDevanagariLinesFoldWithinSeventyFiveOctets() {
        let line = "SUMMARY:" + String(repeating: "कात्तिक ", count: 20)
        let folded = CalendarEvent.fold(line)
        let parts = folded.components(separatedBy: "\r\n")
        #expect(parts.count > 1)
        #expect(parts.allSatisfy { $0.utf8.count <= 75 })
        #expect(parts.dropFirst().allSatisfy { $0.hasPrefix(" ") })
        // Unfolding restores the line exactly: no character was split.
        #expect(folded.replacingOccurrences(of: "\r\n ", with: "") == line)
    }

    @Test func openingWritesTheFileAndHandsItToTheCalendarApp() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let event = CalendarEvent(title: "t", notes: "n", date: GADay(year: 2026, month: 10, day: 21))
        var opened: URL?
        #expect(event.open(in: directory) { opened = $0; return true })
        let url = try #require(opened)
        #expect(url.lastPathComponent == "NepalKit 20261021.ics")
        #expect(try String(contentsOf: url, encoding: .utf8).contains("DTSTART;VALUE=DATE:20261021"))
    }

    @Test func nothingOpeningItIsAFailure() throws {
        let event = CalendarEvent(title: "t", notes: "n", date: GADay(year: 2026, month: 10, day: 21))
        #expect(!event.open { _ in false })
    }

    @Test func aFileThatCannotBeWrittenIsAFailureAndOpensNothing() {
        let event = CalendarEvent(title: "t", notes: "n", date: GADay(year: 2026, month: 10, day: 21))
        var called = false
        let missing = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")
        #expect(!event.open(in: missing) { _ in called = true; return true })
        #expect(!called)
    }

    @Test func addingADayReportsWhetherTheCalendarAppTookIt() throws {
        let model = try kartik2083()
        let dashami = try day(model, 4)
        var handed: CalendarEvent?
        var announced: [String] = []
        #expect(model.addToCalendar(dashami, settings: latin, open: { handed = $0; return true }, announce: { announced.append($0) }))
        #expect(handed?.date == GADay(year: 2026, month: 10, day: 21))
        #expect(announced.isEmpty)
        #expect(!model.addToCalendar(dashami, settings: latin, open: { _ in false }, announce: { announced.append($0) }))
        #expect(announced == [Strings.addToCalendarFailed])
    }
}
