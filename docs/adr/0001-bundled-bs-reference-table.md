# Bundled static BS reference table

BS month lengths are declared per year with no closed-form algorithm, so NepalKit ships a static conversion table transcribed year-by-year from the officially approved annual Nepali Patro, with New Year and month-start boundary dates cross-checked against two independent converters. This keeps conversion offline-first and deterministic with no network dependency.

The table contains only verified calendar data: no extrapolated or projected years. Its supported BS range is explicitly defined by the dataset itself and expands only when new official Patro data becomes available.

## Considered Options

- **External conversion API**: rejected — adds a network dependency to a menu-bar utility that must work offline and answer instantly.
- **Third-party conversion library/dataset**: rejected — the table is the product's correctness core; owning a verified transcription removes upstream trust and availability risk.
