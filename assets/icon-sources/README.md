# NepalKit icon sources

Two-layer icon (Nepal crimson gradient + white calendar page with Devanagari "ने"),
matching the PNGs in `NepalKit/Assets.xcassets/AppIcon.appiconset` (rendered by
`scripts/render-app-icon.swift`).

## Producing the layered `.icon` package (manual, Icon Composer GUI)

`Icon Composer.app` ships with Xcode (Xcode > Open Developer Tool > Icon Composer)
and has no scriptable interface, so this step needs a human:

1. Open Icon Composer, create a new icon named `AppIcon`.
2. Drag in, back to front: `background.svg`, `foreground-page.svg`,
   `foreground-glyph.svg` (convert the glyph text to outlines first —
   SVG does not preserve fonts).
3. Tune Liquid Glass material properties per layer (defaults are a good start:
   background matte, page subtle specular, glyph flat).
4. Save as `NepalKit/AppIcon.icon`, add it to the Xcode project, and
   associate it with the NepalKit target. Adding the `.icon` replaces the
   `AppIcon` asset catalog; Xcode then generates backward-compatible images
   at build time automatically.
