// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Foundation
import NepalKitCore

/// An all-day event handed to the user's calendar app as an iCalendar file.
///
/// A file rather than EventKit: Calendar opens its own "add event" window,
/// and the app needs no calendar access or new sandbox entitlement (ADR-0008).
struct CalendarEvent: Equatable {
    let title: String
    let notes: String
    let date: GADay

    /// One identifier per day, so adding a day twice offers the same event.
    var uid: String {
        "nepalkit-\(date.year)-\(date.month)-\(date.day)@nepalkit"
    }

    /// The event as an RFC 5545 document. `stamp` is the required DTSTAMP,
    /// injected for tests.
    func ics(stamp: Date) -> String {
        let lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//NepalKit//NepalKit//EN",
            "BEGIN:VEVENT",
            "UID:\(uid)",
            "DTSTAMP:\(Self.utcStamp(stamp))",
            // No DTEND: an all-day DTSTART alone is one day (RFC 5545 3.6.1).
            "DTSTART;VALUE=DATE:\(Self.basic(date))",
            "SUMMARY:\(Self.escape(title))",
            "DESCRIPTION:\(Self.escape(notes))",
            "TRANSP:TRANSPARENT",
            "END:VEVENT",
            "END:VCALENDAR",
        ]
        return lines.map(Self.fold).joined(separator: "\r\n") + "\r\n"
    }

    /// Writes the file into `directory` and opens it in the default calendar
    /// app. False when writing or opening failed, so the card can say so.
    func open(
        stamp: Date = .now,
        in directory: URL = FileManager.default.temporaryDirectory,
        opener: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) -> Bool {
        let url = directory.appending(path: "NepalKit \(Self.basic(date)).ics")
        do {
            try ics(stamp: stamp).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return false
        }
        return opener(url)
    }

    // MARK: - Format

    /// "20261018".
    static func basic(_ day: GADay) -> String {
        padded(day.year, 4) + padded(day.month, 2) + padded(day.day, 2)
    }

    /// "20261011T143000Z".
    static func utcStamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return padded(parts.year ?? 0, 4) + padded(parts.month ?? 0, 2) + padded(parts.day ?? 0, 2)
            + "T" + padded(parts.hour ?? 0, 2) + padded(parts.minute ?? 0, 2) + padded(parts.second ?? 0, 2) + "Z"
    }

    /// `value` zero-padded to `width` ASCII digits, whatever the locale.
    private static func padded(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }

    /// RFC 5545 TEXT escaping: backslash, semicolon, comma and newline.
    static func escape(_ text: String) -> String {
        text.replacing("\\", with: "\\\\")
            .replacing(";", with: "\\;")
            .replacing(",", with: "\\,")
            .replacing("\n", with: "\\n")
    }

    /// Folds a content line at 75 octets, never inside a character. Counts
    /// UTF-8 bytes, not characters: Devanagari is three bytes a letter.
    static func fold(_ line: String) -> String {
        var folded = ""
        var width = 0
        for character in line {
            let bytes = String(character).utf8.count
            if width + bytes > 75 {
                folded += "\r\n "
                width = 1
            }
            folded.append(character)
            width += bytes
        }
        return folded
    }
}
