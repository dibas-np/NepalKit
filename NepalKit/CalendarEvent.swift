// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import AppKit
import Foundation
import NepalKitCore

/// An all-day event for one day, handed to the user's calendar app as an
/// iCalendar file.
///
/// A file rather than EventKit: Calendar opens it in its own "add event"
/// window, where the user picks the calendar, adds an alert or cancels. The
/// app never reads or writes a calendar, so it asks for no calendar access
/// and needs no new sandbox entitlement (ADR-0008).
struct CalendarEvent: Equatable {
    let title: String
    let notes: String
    let date: GADay

    /// One identifier per day, so adding the same day twice offers the same
    /// event rather than a second copy of it.
    var uid: String {
        "nepalkit-\(date.year)-\(date.month)-\(date.day)@nepalkit"
    }

    /// The event as an iCalendar (RFC 5545) document: CRLF line endings,
    /// text escaped, long lines folded. `stamp` is the creation time the
    /// format requires; injected so the output is testable.
    func ics(stamp: Date) -> String {
        let lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//NepalKit//NepalKit//EN",
            "BEGIN:VEVENT",
            "UID:\(uid)",
            "DTSTAMP:\(Self.utcStamp(stamp))",
            // No DTEND: an all-day DTSTART alone is exactly one day (RFC 5545
            // 3.6.1), so there is no next-day arithmetic to get wrong.
            "DTSTART;VALUE=DATE:\(Self.basic(date))",
            "SUMMARY:\(Self.escape(title))",
            "DESCRIPTION:\(Self.escape(notes))",
            "TRANSP:TRANSPARENT",
            "END:VEVENT",
            "END:VCALENDAR",
        ]
        return lines.map(Self.fold).joined(separator: "\r\n") + "\r\n"
    }

    /// Writes the file into `directory` and hands it to the default calendar
    /// app. False when the file could not be written or nothing opened it,
    /// so the card can say so rather than leave the click unanswered.
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
        String(format: "%04d%02d%02d", day.year, day.month, day.day)
    }

    /// "20261011T143000Z".
    static func utcStamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d%02d%02dT%02d%02d%02dZ",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
            parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0
        )
    }

    /// RFC 5545 TEXT escaping: backslash, semicolon, comma and newline.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Folds a content line at 75 octets, never inside a character: the
    /// names are Devanagari, three UTF-8 bytes a letter, so counting
    /// characters would overrun the limit.
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
