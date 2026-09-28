# NepalKit icon sources

Two-layer icon (Nepal crimson gradient + white calendar page with Devanagari "ने").

- `AppIcon.icon` (repo root) is the source of truth: a layered Icon Composer
  package authored from these SVGs (glyph converted to outlines on import),
  wired into the Xcode project as `folder.iconcomposer.icon` in the
  NepalKit target's Resources phase. `actool` compiles it at build time into
  the layered `Assets.car` plus backward-compatible `AppIcon.icns`.
- These SVGs are the artwork provenance: edit them and re-import the changed
  layer(s) into Icon Composer to evolve the icon.
