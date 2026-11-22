// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing

struct WatchPresentationWiringTests {
    @Test func everySupportedStateCallSiteMatchesTheFamilyThatMakesIt() throws {
        let expected: [String: (weekday: Bool?, gregorian: Bool)] = [
            "TodayRectangularComplication.standard": (true, false),
            "TodayRectangularComplication.largeText": (false, false),
            "TodayInlineComplication.standard": (false, false),
            "TodayCircularComplication": (false, false),
            "TodayCornerComplication": (false, false),
        ]
        var offenders = try ComplicationWiringSource.undeclaredFamilies()
        offenders += ComplicationWiringSource.wiringOffenders(
            label: "supportedLabel",
            expected: expected,
            calls: try ComplicationWiringSource.supportedLabelCalls()
        )

        #expect(offenders.isEmpty, "supported-label wiring drifted:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func everyBoundaryCallSiteMatchesTheFamilyThatMakesIt() throws {
        let expected: [String: (weekday: Bool?, gregorian: Bool)] = [
            "TodayRectangularComplication.standard": (nil, false),
            "TodayInlineComplication.standard": (nil, false),
            "TodayCircularComplication": (nil, false),
            "TodayCornerComplication": (nil, true),
        ]
        let offenders = ComplicationWiringSource.wiringOffenders(
            label: "boundaryLabel",
            expected: expected,
            calls: try ComplicationWiringSource.boundaryLabelCalls()
        )

        #expect(offenders.isEmpty, "boundary-label wiring drifted:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func everyErrorStateAnnouncesItsSpokenDescription() throws {
        let file = ComplicationWiringSource.complicationSource
        var owners: [String: [Int]] = [:]
        for call in try ComplicationWiringSource.spokenDescriptionCalls() {
            owners[call.type, default: []].append(call.line)
        }
        var offenders: [String] = []
        for family in ComplicationWiringSource.families.sorted() {
            guard let lines = owners[family] else {
                offenders.append("\(file) announces no spokenDescription in \(family)")
                continue
            }
            if lines.count > 1 {
                offenders.append("\(file):\(ComplicationWiringSource.locations(lines)) are \(lines.count) spokenDescription calls in \(family); expected one error state")
            }
        }
        for (type, lines) in owners.sorted(by: { $0.key < $1.key })
        where !ComplicationWiringSource.families.contains(type) {
            offenders.append("\(file):\(ComplicationWiringSource.locations(lines)) \(type) announces spokenDescription but is not a declared family")
        }

        #expect(offenders.isEmpty, "error-state labelling drifted:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func bothCopiesOfTheLargeTextThresholdAgree() throws {
        let complication = ComplicationWiringSource.complicationSource
        let today = ComplicationWiringSource.todaySource
        var offenders: [String] = []
        var bodies: [String: String] = [:]
        for file in [complication, today] {
            let found = try ComplicationWiringSource.largeTextThresholdBodies(in: file)
            if found.count != 1 {
                offenders.append("\(file) declares watchLargeTextFallback \(found.count) times; this sweep reads one body per module")
            }
            bodies[file] = found.first
        }
        if bodies[complication] != bodies[today] {
            offenders.append("the two watchLargeTextFallback bodies disagree, so families switch composition at different text sizes:\n  \(complication): \(bodies[complication] ?? "absent")\n  \(today): \(bodies[today] ?? "absent")")
        }

        #expect(offenders.isEmpty, "the duplicated large-text threshold has drifted:\n\(offenders.joined(separator: "\n"))")
    }
}

struct WiringCall {
    let path: String
    let type: String
    let branch: Branch?
    let line: Int
    let weekday: Bool?
    let gregorian: Bool?
    var site: String { "\(path):\(line)" }

    var key: String {
        branch.map { "\(type).\($0.rawValue)" } ?? type
    }
}

enum Branch: String {
    case largeText
    case standard
}

enum ComplicationWiringSource {
    static let complicationSource = "NepalKitComplications/TodayComplicationView.swift"
    static let todaySource = "NepalKitWatch Watch App/TodayView.swift"

    static let families: Set<String> = [
        "TodayRectangularComplication",
        "TodayInlineComplication",
        "TodayCircularComplication",
        "TodayCornerComplication",
    ]
    private static let dispatcher = "TodayComplicationView"
    static let flagShapesTheParserCannotRead: Set<String> = []

    static func undeclaredFamilies() throws -> [String] {
        var offenders: [String] = []
        var found: Set<String> = []
        let lines = try sourceLines(complicationSource)
        for (index, line) in lines.enumerated() {
            guard let name = declaredTypeName(in: line) else { continue }
            found.insert(name)
            if name != dispatcher, !families.contains(name) {
                offenders.append("\(complicationSource):\(index + 1) \(name) is a complication view with no declared expectation; classify it")
            }
        }
        for family in families.sorted() where !found.contains(family) {
            offenders.append("\(complicationSource) declares no \(family); the expectations above are stale")
        }
        return offenders
    }

    static func wiringOffenders(
        label: String,
        expected: [String: (weekday: Bool?, gregorian: Bool)],
        calls: [WiringCall]
    ) -> [String] {
        var offenders: [String] = []
        var found: [String: WiringCall] = [:]
        var collisions: [String: [Int]] = [:]
        for call in calls {
            guard !flagShapesTheParserCannotRead.contains(call.site) else { continue }
            collisions[call.key, default: []].append(call.line)
            found[call.key] = call
            guard let want = expected[call.key] else {
                offenders.append("\(call.site) \(call.key) is a \(label) call site with no declared expectation; classify it")
                continue
            }
            if call.gregorian == nil || (want.weekday != nil && call.weekday == nil) {
                offenders.append("\(call.site) \(call.key) is a \(label) call whose flags this sweep cannot read; classify it")
            } else if want.weekday != call.weekday || want.gregorian != call.gregorian {
                offenders.append("\(call.site) \(call.key) announces\(weekdayFragment(call.weekday)) gregorian: \(flagFragment(call.gregorian)), expected\(weekdayFragment(want.weekday)) gregorian: \(want.gregorian)")
            }
        }
        for key in expected.keys.sorted() where found[key] == nil {
            offenders.append("\(complicationSource) has no \(label) call for \(key); the expectation above is stale")
        }
        for (key, lines) in collisions.sorted(by: { $0.key < $1.key }) where lines.count > 1 {
            offenders.append("\(complicationSource):\(locations(lines)) are \(lines.count) \(label) calls in \(key), which one table entry cannot describe; classify them")
        }
        return offenders
    }

    private static func weekdayFragment(_ value: Bool?) -> String {
        value == nil ? "" : " weekday: \(flagFragment(value)),"
    }

    private static func flagFragment(_ value: Bool?) -> String {
        value.map(String.init) ?? "unreadable"
    }

    static func supportedLabelCalls() throws -> [WiringCall] {
        try calls(marker: "ComplicationAccessibility.supportedLabel(") { arguments in
            let parts = split(arguments)
            guard parts.count == 3,
                  let weekday = boolean(parts[1], named: "weekday"),
                  let gregorian = boolean(parts[2], named: "gregorian")
            else { return (nil, nil) }
            return (weekday, gregorian)
        }
    }

    static func boundaryLabelCalls() throws -> [WiringCall] {
        try calls(marker: "ComplicationAccessibility.boundaryLabel(") { arguments in
            let parts = split(arguments)
            switch parts.count {
            case 1: return (nil, false)
            case 2: return (nil, boolean(parts[1], named: "gregorian"))
            default: return (nil, nil)
            }
        }
    }

    static func spokenDescriptionCalls() throws -> [WiringCall] {
        try calls(marker: ".accessibilityLabel(components.spokenDescription)") { _ in (nil, nil) }
    }

    private static func calls(
        marker: String,
        flags: (String) -> (weekday: Bool?, gregorian: Bool?)
    ) throws -> [WiringCall] {
        let lines = try sourceLines(complicationSource)
        var found: [WiringCall] = []
        for (index, line) in lines.enumerated() {
            guard line.contains(marker), let enclosing = enclosingDeclaration(before: index, in: lines) else { continue }
            let (weekday, gregorian) = flags(arguments(in: line, marker: marker))
            found.append(
                WiringCall(
                    path: complicationSource,
                    type: enclosing.name,
                    branch: branch(before: index, in: lines, downTo: enclosing.index),
                    line: index + 1,
                    weekday: weekday,
                    gregorian: gregorian
                )
            )
        }
        return found
    }

    private static func declaredTypeName(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("struct "), trimmed.contains(": View") else { return nil }
        let name = trimmed.dropFirst("struct ".count).prefix { !$0.isWhitespace && $0 != ":" }
        return name.isEmpty ? nil : String(name)
    }

    private static func enclosingDeclaration(
        before index: Int,
        in lines: [String]
    ) -> (name: String, index: Int)? {
        for offset in stride(from: index - 1, through: 0, by: -1) {
            guard let name = declaredTypeName(in: lines[offset]) else { continue }
            return (name, offset)
        }
        return nil
    }

    private static func branch(before index: Int, in lines: [String], downTo start: Int) -> Branch? {
        for offset in stride(from: index - 1, through: start, by: -1) {
            let line = lines[offset].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("if dynamicTypeSize.watchLargeTextFallback") { return .largeText }
            if line.hasPrefix("} else {") { return .standard }
        }
        return nil
    }

    private static func arguments(in line: String, marker: String) -> String {
        guard !marker.hasSuffix(")") else { return "" }
        guard let opening = line.range(of: marker),
              let closing = line.range(of: ")", range: opening.upperBound ..< line.endIndex)
        else { return "" }
        return String(line[opening.upperBound ..< closing.lowerBound])
    }

    private static func split(_ arguments: String) -> [String] {
        arguments.split(separator: ", ", omittingEmptySubsequences: false).map(String.init)
    }

    private static func boolean(_ argument: String, named name: String) -> Bool? {
        guard argument.hasPrefix("\(name): ") else { return nil }
        switch argument.dropFirst("\(name): ".count) {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    static func locations(_ lines: [Int]) -> String {
        lines.map(String.init).joined(separator: ", ")
    }

    static func largeTextThresholdBodies(in path: String) throws -> [String] {
        let lines = try sourceLines(path)
        var bodies: [String] = []
        for (index, line) in lines.enumerated()
        where line.trimmingCharacters(in: .whitespaces) == "var watchLargeTextFallback: Bool {" {
            guard lines.indices.contains(index + 1) else { continue }
            bodies.append(lines[index + 1].trimmingCharacters(in: .whitespaces))
        }
        return bodies
    }

    private static func sourceLines(_ path: String) throws -> [String] {
        try String(contentsOf: repositoryRoot.appending(path: path), encoding: .utf8)
            .components(separatedBy: "\n")
    }

    private static var repositoryRoot: URL {
        for base in [URL(fileURLWithPath: #filePath), URL(fileURLWithPath: #filePath).standardizedFileURL] {
            var dir = base.deletingLastPathComponent()
            for _ in 0 ..< 10 {
                if FileManager.default.fileExists(atPath: dir.appendingPathComponent("NepalKit.xcodeproj").path) {
                    return dir
                }
                dir = dir.deletingLastPathComponent()
            }
        }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }
}
