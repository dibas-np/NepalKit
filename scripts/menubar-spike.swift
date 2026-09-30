#!/usr/bin/env swift
// Rendering spike: verify every possible menu-bar title renders
// with full glyph coverage (no tofu) in the menu-bar font, and report the
// widest string so truncation risk in the status bar can be judged.
// Runs against the real NepalKitCore formatting seam (formatBSShort).
// Usage (repo root): swift build --package-path NepalKitCore && \
//   swift -I NepalKitCore/.build/out/Products/Debug \
//         -L NepalKitCore/.build/out/Products/Debug -lNepalKitCore \
//         scripts/menubar-spike.swift
import AppKit
import CoreText
import Foundation
import NepalKitCore

let font = NSFont.menuBarFont(ofSize: 0)

var widest = (text: "", width: 0.0)
var missing: [String] = []

// Collect every distinct title the pickers can produce across the full
// supported range (the short form is year-independent, so the distinct set
// is small), then measure the distinct set.
var titles = Set<String>()
for year in CalendarDataset.v2.supportedRange {
    guard let lengths = CalendarDataset.v2.monthLengths(for: year) else { continue }
    for month in 1 ... 12 {
        for day in 1 ... lengths[month - 1] {
            let bs = BSDay(year: year, month: month, day: day)
            for digits in [DigitScript.latin, DigitScript.devanagari] as [DigitScript] {
                for style in [MonthNameStyle.transliterated, MonthNameStyle.nepali] as [MonthNameStyle] {
                    titles.insert(formatBSShort(bs, settings: DisplaySettings(digits: digits, monthNames: style)))
                }
            }
        }
    }
}

for text in titles {
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: [.font: font]) as CFAttributedString
    )
    // Cascade-aware tofu check: a laid-out run set in LastResort
    // with glyph 0 means no installed font covers the character.
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    for run in runs {
        let attrs = CTRunGetAttributes(run) as NSDictionary
        let runFont = attrs[kCTFontAttributeName] as! CTFont
        let name = CTFontCopyPostScriptName(runFont) as String
        let glyphCount = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
        CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
        if name.contains("LastResort") && glyphs.contains(0) {
            missing.append(text)
            break
        }
    }
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    if width > widest.width { widest = (text, width) }
}

print("distinct titles measured: \(titles.count)")
print("missing glyphs: \(missing.count)\(missing.isEmpty ? "" : " e.g. \(missing.prefix(3))")")
print(String(format: "widest: \"%@\" at %.1fpt (%@ %@)", widest.text, widest.width, ProcessInfo.processInfo.operatingSystemVersionString, font.fontName))
