#!/usr/bin/env swift

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
//
// DMG window artwork, and the single source of truth for the Finder window
// layout it has to line up with.
//
// The double-clicked DMG is the app's first impression, and Finder will not
// arrange a drag-install window for you: unscripted it is a default-sized
// window with two icons stacked in the top-left corner and the window
// filename as a caption. That is the surface a user meets before the menu-bar
// date, so it gets the same care as the popover.
//
// The coupling that makes this awkward is that Finder draws the icons and this
// draws everything around them, from two different mechanisms, and the two must
// agree. So the geometry is defined HERE, once, and the packager reads it back
// from stdout instead of restating it: the icon origins it hands to Finder are
// the same numbers the arrow was drawn between. A layout that drifts is a
// layout nobody can reason about, because the two halves are edited in
// different files.
//
// The window is composed in *content* coordinates — origin at the top-left of
// the Finder content area, y down — because that is the coordinate system
// Finder's `position of item` uses. The title bar sits above the content area
// and its height is not knowable from AppleScript, so it is measured by
// `measure-title-bar.swift` and passed in: the packager computes the window
// bounds, and this script draws into the content area the remainder.
//
// Usage:
//   scripts/make-dmg-artwork.swift <output.png> <app name> <content height> <title bar height>
//
// Writes the PNG and prints a JSON layout on stdout:
//   {"contentSize":[w,h], "iconSize":n, "appIconOrigin":[x,y], "applicationsIconOrigin":[x,y], "windowSize":[w,h]}

import AppKit
import Foundation

// MARK: - Layout

/// Content width, in points. Wide enough that the two icons sit apart with the
/// arrow between them rather than crowding it, and narrow enough that the
/// window does not need to be a second display.
let contentWidth: CGFloat = 560

/// Finder's largest icon size. 128 leaves the labels crowded; 64 makes the app
/// the thing the user drags too small to be the obvious target.
let iconSize: CGFloat = 96

let appIconOrigin = CGPoint(x: 112, y: 62)
let applicationsIconOrigin = CGPoint(x: 352, y: 62)

/// The arrow points from the app's trailing edge to the Applications icon's
/// leading edge, inset far enough that it reads as an instruction between two
/// things rather than as decoration touching either of them.
let arrowInset: CGFloat = 24
let arrowThickness: CGFloat = 3
let arrowHeadLength: CGFloat = 14
let arrowHeadHalfWidth: CGFloat = 9

/// Baseline of the single caption line, in content coordinates.
let captionBaseline: CGFloat = 222
let captionFont = NSFont.systemFont(ofSize: 13, weight: .medium)
let captionColor = NSColor(red: 0.17, green: 0.14, blue: 0.13, alpha: 1)

/// The midpoint of the app icon's crimson gradient (`assets/icon-sources/
/// background.svg`, #DC143C to #7A0A26), so the arrow is the brand colour
/// rather than a second, competing one.
let arrowColor = NSColor(
    red: (0xDC / 255.0 + 0x7A / 255.0) / 2,
    green: (0x14 / 255.0 + 0x0A / 255.0) / 2,
    blue: (0x3C / 255.0 + 0x26 / 255.0) / 2,
    alpha: 1
)

/// Warm off-white. Pinned rather than left to the Finder window's own
/// appearance, because the caption and arrow are drawn once, in fixed dark
/// tones: an appearance-dependent background would leave one of them
/// unreadable.
let backgroundColor = NSColor(red: 0.969, green: 0.953, blue: 0.945, alpha: 1)

// MARK: - Arguments

let arguments = CommandLine.arguments
guard arguments.count == 5 else {
    FileHandle.standardError.write(Data(
        "usage: make-dmg-artwork.swift <output.png> <app name> <content height> <title bar height>\n"
            .utf8
    ))
    exit(2)
}

let outputPath = arguments[1]
let appName = arguments[2]
guard let contentHeight = Double(arguments[3]) else {
    FileHandle.standardError.write(Data("content height must be a number\n".utf8))
    exit(2)
}
guard let titleBarHeight = Double(arguments[4]) else {
    FileHandle.standardError.write(Data("title bar height must be a number\n".utf8))
    exit(2)
}

let scale: CGFloat = 2

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

// Drawn at 2x so the caption stays sharp on a Retina display, which is the
// only kind of Mac this app ships to (the deployment floor is macOS 26).
context.scaleBy(x: scale, y: scale)
// CoreGraphics' origin is bottom-left; the layout above is in the y-down
// content coordinates Finder uses for item positions.
context.translateBy(x: 0, y: contentHeight)
context.scaleBy(x: 1, y: -1)

let canvas = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
context.setFillColor(backgroundColor.cgColor)
context.fill(canvas)

func point(_ origin: CGPoint, _ edge: CGPoint) -> CGPoint {
    CGPoint(x: origin.x + edge.x, y: origin.y + edge.y)
}

/// Shaft and head as one stroked-and-filled path, so the joint where they meet
/// cannot show a seam at any size.
func drawArrow() {
    let centerY = appIconOrigin.y + iconSize / 2
    let tail = CGPoint(x: appIconOrigin.x + iconSize + arrowInset, y: centerY)
    let head = CGPoint(x: applicationsIconOrigin.x - arrowInset, y: centerY)

    context.saveGState()
    context.setStrokeColor(arrowColor.cgColor)
    context.setFillColor(arrowColor.cgColor)
    context.setLineWidth(arrowThickness)
    context.setLineCap(.round)
    context.move(to: tail)
    context.addLine(to: head)
    context.strokePath()

    let headTip = CGPoint(x: head.x + arrowHeadLength / 2, y: head.y)
    let headPath = CGMutablePath()
    headPath.move(to: headTip)
    headPath.addLine(to: point(head, CGPoint(x: -arrowHeadLength / 2, y: -arrowHeadHalfWidth)))
    headPath.addLine(to: point(head, CGPoint(x: -arrowHeadLength / 2, y: arrowHeadHalfWidth)))
    headPath.closeSubpath()
    context.addPath(headPath)
    context.fillPath()
    context.restoreGState()
}

drawArrow()

// AppKit's own text drawing, so the caption is set in the system font with
// system shaping, wrapped in the bitmap context rather than reimplemented over
// CoreText.
let caption = "Drag \(appName) into your Applications folder"
let captionSize = (caption as NSString).size(withAttributes: [.font: captionFont])
let captionRect = CGRect(
    x: (contentWidth - captionSize.width) / 2,
    y: captionBaseline - captionSize.height,
    width: captionSize.width,
    height: captionSize.height
)

let appKitContext = NSGraphicsContext(cgContext: context, flipped: true)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = appKitContext
(caption as NSString).draw(
    in: captionRect,
    withAttributes: [.font: captionFont, .foregroundColor: captionColor]
)
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
    "appIconOrigin": [appIconOrigin.x, appIconOrigin.y],
    "applicationsIconOrigin": [applicationsIconOrigin.x, applicationsIconOrigin.y],
    // The window is the content area plus the title bar above it, which Finder
    // draws for itself.
    "windowSize": [contentWidth, contentHeight + titleBarHeight],
]
let json = try JSONSerialization.data(withJSONObject: layout, options: [.sortedKeys])
print(String(decoding: json, as: UTF8.self))
