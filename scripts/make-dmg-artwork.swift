#!/usr/bin/env swift

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
//
// Usage:
//   scripts/make-dmg-artwork.swift <output.png> <app name>
//
// Prints:
//   {"contentSize":[w,h], "iconSize":n, "appIconCentre":[x,y],
//    "applicationsIconCentre":[x,y], "windowSize":[w,h]}

import AppKit
import Foundation

let contentWidth: CGFloat = 560

let contentHeight: CGFloat = 300

let iconSize: CGFloat = 96

let appIconCentreX: CGFloat = 160
let applicationsIconCentreX: CGFloat = 400

let arrowInset: CGFloat = 28
let arrowThickness: CGFloat = 2.5
let arrowHeadLength: CGFloat = 13
let arrowHeadHalfWidth: CGFloat = 8

let captionGap: CGFloat = 44
let captionFont = NSFont.systemFont(ofSize: 13, weight: .medium)
let captionColor = NSColor(red: 0.17, green: 0.14, blue: 0.13, alpha: 1)

let arrowColor = NSColor(
    red: (0xDC / 255.0 + 0x7A / 255.0) / 2,
    green: (0x14 / 255.0 + 0x0A / 255.0) / 2,
    blue: (0x3C / 255.0 + 0x26 / 255.0) / 2,
    alpha: 1
)

let backgroundColor = NSColor(red: 0.969, green: 0.953, blue: 0.945, alpha: 1)

let windowBorder: CGFloat = 8
let windowChrome: CGFloat = 64

let scale: CGFloat = 2

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data(
        "usage: make-dmg-artwork.swift <output.png> <app name>\n".utf8
    ))
    exit(2)
}

let outputPath = arguments[1]
let appName = arguments[2]

let centreY = contentHeight / 2

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
    "windowSize": [contentWidth + windowBorder, contentHeight + windowChrome],
]
let json = try JSONSerialization.data(withJSONObject: layout, options: [.sortedKeys])
try FileHandle.standardOutput.write(contentsOf: json)
try FileHandle.standardOutput.write(contentsOf: Data([0x0A]))
