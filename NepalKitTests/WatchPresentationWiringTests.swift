// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing

/// Which weekday and Gregorian detail each complication family announces, and
/// that the two copies of the large-text threshold still agree.
///
/// **Derived from the source, not enumerated.** A hand-written list of the five
/// `supportedLabel` calls pins the wiring reviewed today and says nothing about
/// the call site added tomorrow, which is exactly the gap this closes: flipping
/// rectangular's `weekday: true` to `false` leaves the whole suite green while
/// the one family that shows a weekday stops announcing it. So the call sites
/// are *parsed*, each is classified by the family and large-text side enclosing
/// it, and a site matching no expectation — or colliding with another site under
/// one key — is an offender rather than something that goes unchecked. The shape
/// `SpokenDateTests.stringsConstantsReachingTheSpokenChannel` argues for.
///
/// **What this deliberately does not prove.** The families are SwiftUI `View`s,
/// and nothing can ask a view which arguments it passed a helper without either
/// rendering it or adding a view-inspection dependency. Rendering is
/// unavailable here — this file is read by a SwiftPM harness with no preview or
/// snapshot harness, and `AGENTS.md` forbids a third-party framework without
/// asking — so the claim that the announced detail *matches what is drawn*
/// belongs where it always did: a real device and a real screen reader, recorded
/// at `docs/watch/physical-validation.md:57`. The parser is line-based and
/// follows no indirection; its exemption set covers a shape it cannot read and
/// is empty today, which is the honest way to say "none" while leaving the
/// mechanism in place.
struct WatchPresentationWiringTests {
    @Test func everySupportedStateCallSiteMatchesTheFamilyThatMakesIt() throws {
        // Each family announces the weekday exactly where it draws one.
        // Rectangular's default body puts the weekday on the year line, and its
        // large-text fallback drops it along with the Gregorian detail that body
        // never drew. Inline, circular and corner show neither.
        let expected: [String: (weekday: Bool?, gregorian: Bool)] = [
            "TodayRectangularComplication.standard": (true, false),
            "TodayRectangularComplication.largeText": (false, false),
            "TodayInlineComplication.standard": (false, false),
            "TodayCircularComplication": (false, false),
            "TodayCornerComplication": (false, false),
        ]
        var offenders = try ComplicationWiringSource.undeclaredFamilies()
        offenders += try ComplicationWiringSource.wiringOffenders(
            label: "supportedLabel",
            expected: expected,
            calls: try ComplicationWiringSource.supportedLabelCalls()
        )

        #expect(offenders.isEmpty, "supported-label wiring drifted:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func everyBoundaryCallSiteMatchesTheFamilyThatMakesIt() throws {
        // Past the supported range there is no date to announce, so the boundary
        // label's whole job is the support context: the two families drawing a
        // Gregorian day/month keep it in speech, the two compact families do not.
        let expected: [String: (weekday: Bool?, gregorian: Bool)] = [
            "TodayRectangularComplication.standard": (nil, true),
            "TodayInlineComplication.standard": (nil, false),
            "TodayCircularComplication": (nil, false),
            "TodayCornerComplication": (nil, true),
        ]
        let offenders = try ComplicationWiringSource.wiringOffenders(
            label: "boundaryLabel",
            expected: expected,
            calls: try ComplicationWiringSource.boundaryLabelCalls()
        )

        #expect(offenders.isEmpty, "boundary-label wiring drifted:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func everyErrorStateAnnouncesItsSpokenDescription() throws {
        // The error state is the one a family can lose silently: it carries no
        // flags, just a label, so a family whose error branch stops labelling
        // itself reads out as a bare "Date calculation failed". Every family
        // needs one, and the families are the same set the supported sweep
        // classifies, so a family added tomorrow is checked here too.
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
        // Declared once per module on purpose: the two watchOS products cannot
        // share a framework target, and `NepalKitCore` is Foundation-only. Two
        // copies with nothing between them drift silently, and then every family
        // switches composition at a different text size.
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
        // Both paths are named whether or not they disagree.
        if bodies[complication] != bodies[today] {
            offenders.append("the two watchLargeTextFallback bodies disagree, so families switch composition at different text sizes:\n  \(complication): \(bodies[complication] ?? "absent")\n  \(today): \(bodies[today] ?? "absent")")
        }

        #expect(offenders.isEmpty, "the duplicated large-text threshold has drifted:\n\(offenders.joined(separator: "\n"))")
    }
}

/// One call site read out of `TodayComplicationView.swift`.
struct WiringCall {
    let path: String
    let type: String
    let branch: Branch?
    let line: Int
    let weekday: Bool?
    let gregorian: Bool?
    var site: String { "\(path):\(line)" }

    /// The family, qualified by the large-text side where the family has one. A
    /// family with no conditional keeps the bare name; inline's single label
    /// sits on the `Group` wrapping both of its compositions, so it takes the
    /// side its nearest preceding branch token names.
    var key: String {
        branch.map { "\(type).\($0.rawValue)" } ?? type
    }
}

/// Which side of a family's large-text conditional a call sits on.
enum Branch: String {
    case largeText
    case standard
}

/// Reads the complication wiring out of source, classifying every call site by
/// the family and large-text side that enclose it.
///
/// Line-based, and deliberately so: a call wrapped across lines, or one whose
/// flag comes from a computed variable, is reported as unreadable rather than
/// guessed at, so the shape this cannot follow fails the test instead of being
/// mis-read. `flagShapesTheParserCannotRead` is the exemption mechanism for such
/// a case once someone has judged it; it is empty today, and an empty set is the
/// honest way to say "none" while leaving the mechanism in place.
enum ComplicationWiringSource {
    static let complicationSource = "NepalKitComplications/TodayComplicationView.swift"
    static let todaySource = "NepalKitWatch Watch App/TodayView.swift"

    /// The families `TodayComplicationView` routes to. `TodayComplicationView`
    /// itself is the dispatcher, not a family, so it is excluded when the
    /// declarations are read back.
    static let families: Set<String> = [
        "TodayRectangularComplication",
        "TodayInlineComplication",
        "TodayCircularComplication",
        "TodayCornerComplication",
    ]
    private static let dispatcher = "TodayComplicationView"
    static let flagShapesTheParserCannotRead: Set<String> = []

    /// The families present in the source but not declared here, and the declared
    /// ones no longer present — so a family added or removed tomorrow is caught
    /// rather than leaving the call-site sweeps nothing to hold.
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

    /// Every way a call site's flags disagree with its family's declared
    /// expectation, plus the two ways this sweep could lose a site outright: a
    /// declared expectation with no call behind it, and two sites sharing one key
    /// so that a single entry cannot describe both.
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

    /// The weekday clause of a message, omitted where the call has no such flag.
    private static func weekdayFragment(_ value: Bool?) -> String {
        value == nil ? "" : " weekday: \(flagFragment(value)),"
    }

    private static func flagFragment(_ value: Bool?) -> String {
        value.map(String.init) ?? "unreadable"
    }

    static func supportedLabelCalls() throws -> [WiringCall] {
        try calls(marker: "ComplicationAccessibility.supportedLabel(") { arguments in
            // `components, weekday: <bool>, gregorian: <bool>`. The flags are the
            // point of the assertion, so the receiver's name is deliberately not
            // pinned; the arity and both flag names are.
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
            // The bare form is a real form — `boundaryLabel(boundary)` means no
            // Gregorian context — so a missing flag is `false`, not unreadable.
            // Any third shape is unreadable, so the completeness check fires
            // instead of the sweep silently defaulting it.
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

    /// Every line carrying `marker`, classified by its enclosing
    /// `struct …: View` and by the large-text side within that struct's own body.
    ///
    /// The backward scan is bounded by the enclosing declaration, so a type that
    /// never branches cannot inherit the previous type's `} else {` and file its
    /// call under a key that reads as a branch it does not have.
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

    /// The name and index of the nearest `struct …: View` above `index` — the
    /// family a call site belongs to.
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

    /// The text between a call marker and the parenthesis closing it.
    ///
    /// A marker that is already a whole call — `.accessibilityLabel(x)` — has no
    /// argument list to read. Anything else must close on the same line: a call
    /// wrapped across lines yields an empty string, which the caller's arity
    /// check turns into a named, unreadable site rather than a silent skip.
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

    /// The body of every `watchLargeTextFallback` in `path`, trimmed. A list
    /// rather than a single value, so a second copy in one module is an offender
    /// instead of an arbitrary pick between the two.
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

    /// The repository root, found by searching upward for the project file.
    ///
    /// The same walk `SymbolTests` documents: this test compiles through the
    /// harness at `scripts/apptests/Tests/NepalKitTests/`, so `#filePath` is the
    /// symlinked path at run time and hop-counting lands in `Tests/` instead of
    /// the root. Searching upward from either form cannot depend on which one is
    /// in effect.
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
