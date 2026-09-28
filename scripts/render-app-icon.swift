#!/usr/bin/env swift
// Renders NepalKit's app icon (1024 master + all AppIcon.appiconset sizes).
// Two-layer design so the system can auto-layer it on macOS 26/27 and so the
// layers map 1:1 onto Icon Composer layers (see Assets/IconSources/README.md):
//   background — Nepal crimson gradient
//   foreground — white calendar page with crimson Devanagari "ने"
// Usage: scripts/render-app-icon.swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // scripts
    .deletingLastPathComponent() // repo root
let setDir = root
    .appendingPathComponent("NepalKit/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

let masterSize: CGFloat = 1024
let image = NSImage(size: NSSize(width: masterSize, height: masterSize))
image.lockFocus()

// Background: Nepal crimson gradient, top to bottom.
let top = NSColor(calibratedRed: 0.86, green: 0.08, blue: 0.24, alpha: 1) // #DC143C
let bottom = NSColor(calibratedRed: 0.48, green: 0.04, blue: 0.15, alpha: 1)
let gradient = NSGradient(starting: top, ending: bottom)!
gradient.draw(in: NSRect(x: 0, y: 0, width: masterSize, height: masterSize), angle: 90)

// Foreground: white calendar page.
let page = NSRect(x: 262, y: 252, width: 500, height: 520)
let pagePath = NSBezierPath(roundedRect: page, xRadius: 64, yRadius: 64)
NSColor.white.setFill()
pagePath.fill()

// Binder rings straddling the page's top edge.
for x in [382, 642] as [CGFloat] {
    let ring = NSRect(x: x - 22, y: 722, width: 44, height: 110)
    let ringPath = NSBezierPath(roundedRect: ring, xRadius: 22, yRadius: 22)
    NSColor.white.setFill()
    ringPath.fill()
}

// Crimson Devanagari "ने" centered on the page.
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let font = NSFont.systemFont(ofSize: 360, weight: .semibold)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedRed: 0.78, green: 0.07, blue: 0.21, alpha: 1),
    .paragraphStyle: paragraph,
]
let glyph = NSString(string: "ने")
let glyphSize = glyph.size(withAttributes: attrs)
glyph.draw(
    at: NSPoint(x: page.midX - glyphSize.width / 2, y: page.midY - glyphSize.height / 2 - 10),
    withAttributes: attrs
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let master = rep.representation(using: .png, properties: [:])
else { fatalError("render failed") }

let masterURL = setDir.appendingPathComponent("icon_512x512@2x.png")
try master.write(to: masterURL)

// Downscale the master to every appiconset slot.
let sizes = [16, 32, 128, 256, 512]
for size in sizes {
    for scale in [1, 2] {
        let pixels = size * scale
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(size)x\(size)\(suffix).png"
        if name == "icon_512x512@2x.png" { continue } // already written
        let out = setDir.appendingPathComponent(name)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        task.arguments = ["-z", "\(pixels)", "\(pixels)", masterURL.path, "--out", out.path]
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { fatalError("sips failed for \(name)") }
    }
}

// Rewrite Contents.json with filenames.
struct Entry: Encodable {
    let idiom: String
    let scale: String
    let size: String
    let filename: String
}
struct Contents: Encodable {
    let images: [Entry]
    let info: [String: String]
}
let entries = sizes.flatMap { size in
    [1, 2].map { scale in
        Entry(
            idiom: "mac",
            scale: "\(scale)x",
            size: "\(size)x\(size)",
            filename: "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        )
    }
}
let data = try JSONEncoder().encode(Contents(images: entries, info: ["author": "xcode", "version": "1"]))
try data.write(to: setDir.appendingPathComponent("Contents.json"))
print("icon written to \(setDir.path)")
