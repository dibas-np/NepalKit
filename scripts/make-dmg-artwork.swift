#!/usr/bin/env swift

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
//
// DMG window artwork, and the single source of truth for the Finder window
// layout it has to line up with.
//
// The double-clicked DMG is the app's first impression, and Finder will not
// arrange a drag-install window for you: unscripted it is a default-sized
// window with the app and the Applications shortcut stacked in the top-left
// corner. That is the surface a user meets before the menu-bar date, so it
// gets the same care as the popover.
//
// The coupling that makes this awkward is that Finder draws the icons and this
// draws everything around them, from two different mechanisms, and the two must
// agree. So the geometry is defined HERE, once, and the packager reads it back
// from stdout rather than restating it: the icon centres it hands to Finder are
// the numbers the arrow was drawn between. A layout that drifts is a layout
// nobody can reason about, because its halves are edited in different files.
//
// How the two coordinate systems line up, which is the part that is easy to
// get wrong:
//
//   * Finder places an item at a point in the window's *content area*
//     coordinates — origin at its top-left, y down — and that point is the
//     centre of the item's cell, not its corner.
//   * Finder draws the background picture at the image's logical size,
//     centred in that same content area, and does not scale it. A file named
//     `@2x` counts as half its pixel size logically, which is how the artwork
//     stays sharp on a Retina display without being drawn twice as large.
//
// So the image is authored in content coordinates one-to-one, and the arrow
// sits on the icons' shared centre line. That line is also the image's centre,
// and the image is centred in the content area, so it is also the content
// area's centre — which is where the icons are placed too. The composition is
// therefore a single centre line that both halves agree on by construction,
// rather than two sets of numbers that have to be kept in step by hand.
//
// The one thing that can move it is the content area itself not being the size
// the window was sized for. The path bar below the content is a Finder-wide
// user setting with no key in `.DS_Store` and no AppleScript property, so a Mac
// with it turned off gets a taller content area, the image stays centred in it,
// and the icons sit above the arrow by half the difference. Recorded in
// ADR-0013; it is a composition that no longer lines up, not a broken window.
//
// Usage:
//   scripts/make-dmg-artwork.swift <output.png> <app name>
//
// Writes the PNG and prints the layout on stdout:
//   {"contentSize":[w,h], "iconSize":n, "appIconCentre":[x,y],
//    "applicationsIconCentre":[x,y], "windowSize":[w,h]}

import AppKit
import Foundation

// MARK: - Layout

/// Content width, in points. Wide enough that the arrow has room to be an
/// instruction between two things rather than decoration touching either, and
/// narrow enough that the window is not a second display.
let contentWidth: CGFloat = 560

/// Content height. The composition is centred in it, so this is how much air
/// the window has around the icons rather than a position: the icons stay on
/// the centre line whatever this is set to.
let contentHeight: CGFloat = 300

/// Finder's largest icon size is 128, which leaves the labels crowded; 64
/// makes the thing the user has to drag too small to be the obvious target.
let iconSize: CGFloat = 96

/// The two icons are one object centred in the window, not two objects in the
/// left half, so they sit as a pair around the horizontal centre with equal
/// margins either side of their cells, and the arrow fills the gap between.
let appIconCentreX: CGFloat = 160
let applicationsIconCentreX: CGFloat = 400

/// Arrow geometry, relative to the two icons' shared centre line. Kept light:
/// at the size it is drawn, a heavier arrow stops being a pointer between two
/// things and becomes a bar the eye lands on first.
let arrowInset: CGFloat = 28
let arrowThickness: CGFloat = 2.5
let arrowHeadLength: CGFloat = 13
let arrowHeadHalfWidth: CGFloat = 8

/// Gap between the bottom of the icons and the top of the caption, which is
/// what stops the line reading as a label for the app icon.
let captionGap: CGFloat = 44
let captionFont = NSFont.systemFont(ofSize: 13, weight: .medium)
let captionColor = NSColor(red: 0.17, green: 0.14, blue: 0.13, alpha: 1)

/// The midpoint of the app icon's crimson gradient (`assets/icon-sources/
/// background.svg`, #DC143C to #7A0A26), so the arrow is the brand colour
/// rather than a second one competing with it.
let arrowColor = NSColor(
    red: (0xDC / 255.0 + 0x7A / 255.0) / 2,
    green: (0x14 / 255.0 + 0x0A / 255.0) / 2,
    blue: (0x3C / 255.0 + 0x26 / 255.0) / 2,
    alpha: 1
)

/// Warm off-white, pinned rather than left to the window's appearance: the
/// caption and arrow are drawn once in fixed dark tones, and an
/// appearance-dependent background would leave one of them unreadable.
let backgroundColor = NSColor(red: 0.969, green: 0.953, blue: 0.945, alpha: 1)

/// Finder's own window furniture, measured on macOS 26/27 and re-checked
/// whenever the floor moves: a 4pt border down each side of the content area,
/// a 32pt title bar above it, and a 32pt path bar below. The artwork is
/// authored against the content area alone, so these only decide how large a
/// window to ask for — and the path bar is the one of the three the packager
/// cannot rely on being there, which is the drift described at the top.
let windowBorder: CGFloat = 8
let windowChrome: CGFloat = 64

/// Backings store, so the artwork is sharp on the Retina displays this app
/// ships to and the file stays half the size a 1x-at-2x export would.
let scale: CGFloat = 2

// MARK: - Arguments

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data(
        "usage: make-dmg-artwork.swift <output.png> <app name>\n".utf8
    ))
    exit(2)
}

let outputPath = arguments[1]
let appName = arguments[2]

/// The content area's centre line, which is where the icons, the arrow and the
/// image's own centre all have to agree.
let centreY = contentHeight / 2

// MARK: - Drawing

let pixelWidth = Int(contentWidth * scale)
let pixelHeight = Int(contentHeight * scale)

guard let context = CGContext(
    data: nil,
    width: pixelWidth,
    height: pixelHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("could not create a bitmap context\n".utf8))
    exit(1)
}

context.scaleBy(x: scale, y: scale)
// CoreGraphics' origin is bottom-left; the layout above is the y-down content
// coordinate system Finder positions items in.
context.translateBy(x: 0, y: contentHeight)
context.scaleBy(x: 1, y: -1)

context.setFillColor(backgroundColor.cgColor)
context.fill(CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight))

let arrowTail = CGPoint(x: appIconCentreX + iconSize / 2 + arrowInset, y: centreY)
let arrowHead = CGPoint(x: applicationsIconCentreX - iconSize / 2 - arrowInset, y: centreY)

context.saveGState()
context.setStrokeColor(arrowColor.cgColor)
context.setFillColor(arrowColor.cgColor)
context.setLineWidth(arrowThickness)
context.setLineCap(.round)
context.move(to: arrowTail)
context.addLine(to: arrowHead)
context.strokePath()

let headPath = CGMutablePath()
headPath.move(to: CGPoint(x: arrowHead.x + arrowHeadLength / 2, y: arrowHead.y))
headPath.addLine(to: CGPoint(x: arrowHead.x - arrowHeadLength / 2, y: arrowHead.y - arrowHeadHalfWidth))
headPath.addLine(to: CGPoint(x: arrowHead.x - arrowHeadLength / 2, y: arrowHead.y + arrowHeadHalfWidth))
headPath.closeSubpath()
context.addPath(headPath)
context.fillPath()
context.restoreGState()

// AppKit's own text drawing, so the caption is set in the system font with
// system shaping rather than reimplemented over CoreText.
let caption = "Drag \(appName) into your Applications folder"
let captionAttributes: [NSAttributedString.Key: Any] = [
    .font: captionFont,
    .foregroundColor: captionColor,
]
let captionSize = (caption as NSString).size(withAttributes: captionAttributes)
let captionOrigin = CGPoint(x: (contentWidth - captionSize.width) / 2, y: centreY + iconSize / 2 + captionGap)

let appKitContext = NSGraphicsContext(cgContext: context, flipped: true)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = appKitContext
(caption as NSString).draw(at: captionOrigin, withAttributes: captionAttributes)
NSGraphicsContext.restoreGraphicsState()

// MARK: - Output

guard let image = context.makeImage(),
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("could not encode the artwork as PNG\n".utf8))
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write(Data("could not write \(outputPath): \(error)\n".utf8))
    exit(1)
}

let layout: [String: Any] = [
    "contentSize": [contentWidth, contentHeight],
    "iconSize": iconSize,
    "appIconCentre": [appIconCentreX, centreY],
    "applicationsIconCentre": [applicationsIconCentreX, centreY],
    // The content area plus the furniture Finder draws around it. Only the
    // packager needs this: the artwork is authored against the content area.
    "windowSize": [contentWidth + windowBorder, contentHeight + windowChrome],
]
let json = try JSONSerialization.data(withJSONObject: layout, options: [.sortedKeys])
print(String(decoding: json, as: UTF8.self))
