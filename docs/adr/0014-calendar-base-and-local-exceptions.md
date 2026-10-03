# One calendar base with explicit local exceptions

Date: 2026-10-03
Status: accepted for source policy; 2084 remains provisional development/testing data

## Decision

Use askbuddie/bikram-sambat's `src/data/days-in-month-mapping.ts`, pinned at
`d3475606084141352d3bf4472c80f9051968551a`, as the sole current historical base
reference. Retain its MIT copyright and permission notice in the shared core
resource bundle. NepalKit code and documentation remain GPL-3.0-or-later.

Retain the existing 14 historical exceptions across 1989, 1993, 2004, 2082 and
2083. Dharan e-BPS converter observations confirm the 1989 and 1993 month
pairs. Preserve evidence limits for the other decisions, including the missing
original rationale for 2004. Record all values and checks in SOURCES.md.

Keep the maintainer's own 2084 projection, unchanged, as a separate provisional
decision. It is not attributed to the base source or described as official
calendar attestation. No dates, anchors or supported bounds change, so the
calendar-data version stays 2.0.1 and the public symbol stays `CalendarDataset.v2`.

## Relationship to earlier decisions

Supersedes ADR-0001's claim of an independently transcribed, wholly verified
Patro table and its rejection of a community base. Refines ADR-0010's
corroboration policy: the current historical base plus explicitly reviewed
exceptions defines the dataset, rather than a multi-source majority vote.
ADR-0010 still records why dataset 2.0.0 narrowed the range; this cleanup does
not undo that cut or rewrite historical provenance.

The 2084 projection still requires official-calendar comparison before public
release acceptance. Its presence is a specific development/testing exception,
not permission to extrapolate future years. Do not extend to 2085 until the
official year's data and boundaries have been checked and the resulting update
has been recorded and versioned under ADR-0002 and ADR-0009.

## Consequences

The automated verifier fetches only askbuddie. A committed baseline retains the
14 historical differences and four projection differences. Other converters
may be consulted as targeted evidence but are not additional base dependencies.
A green baseline proves the observation has not drifted, not official accuracy
or independent authorship. Changing a source label does not by itself settle
copyright questions about earlier work.
