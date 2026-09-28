# The supported range narrows on lost corroboration, not only on new data

**Refines ADR-0001. Applies the versioning separation in ADR-0009.**

ADR-0001 decided that the bundled table holds only verified calendar data, that
nothing is extrapolated, and that its supported range "expands only when new
official Patro data becomes available." The cross-check behind that table found
that the years 1970–1974 were corroborated by no second table: they are the only
years in the range resting on the base source alone. Dataset 1.0.0 shipped them
anyway.

This records narrowing them, and generalises the rule: **the supported range
narrows when the shipped table can no longer be corroborated for part of it, as
well as extending when new Patro data is published.** A range is a statement
about how well the data is supported, so it has to be able to move in the
downward direction. Dataset 2.0.0 ships 1975–2084 BS.

Narrowing the range is a breaking change to the public conversion contract, so
the dataset version takes a major bump, `1.0.0` → `2.0.0`. That the dataset
version moves independently of the application version is ADR-0009's rule, not
ADR-0002's — ADR-0002 records the update *strategy* and says nothing about
version numbers. ADR-0002's "may bundle an expanded dataset" is the half of the
rule that survives here; this record is the other half.

The bundled static is renamed `CalendarDataset.v1` → `CalendarDataset.v2` to
match. The identifier is public API of the core package, and leaving a symbol
named `v1` that declares `"2.0.0"` would be a name that lies about the contract
it names. The rename is the reason this change touches four app sources and
eight test files, and that cost is accepted rather than worked around by leaving
the old name pointing at a different range.

The Gregorian lower bound is not a separate setting. It follows from the table:
1 Baisakh 1975 is 13 April 1918, so the convertible span starts at 1918-04-13
rather than 1913-04-13. `ConverterModel` derives both ends by converting the
first and last days of `supportedRange`, so a future dataset release moves the
Gregorian span on its own and no view or model carries a range literal.

**What this cut does not do.** It does not make the remaining table independently
licensed, and no documentation may say it does. Every year still shipped is
derived from the same base table (`medic/bikram-sambat`, itself a fork of
`alxndrsn/bikram-sambat.js`, which carries no licence file). The cut removes the
five years with the weakest corroboration; it does not resolve the provenance
chain, which is a separate track, tracked outside the engineering tickets.
Stating this honestly is the point of the record — a narrowing presented as a
licence fix would be worse than no cut at all.

## Considered Options

**Ship 1970–1974 as they are, and document the single-source caveat.** Rejected.
The caveat would live in a repository file while the five years remained part of
the public conversion contract, which is the failure mode the provenance track
exists to close.

**Deprecate 1970–1974 before removing them.** Rejected. Deprecation keeps a
second conversion contract alive in the same binary, and nothing needs the old
one: 1913–1917 Gregorian is far outside any plausible use of a menu-bar date
utility.

**Hold the release until the upstream permission request is answered.** Rejected
as sequencing, not as principle. The request is external and unbounded; the five
uncorroborated years are a known, bounded defect that can be closed now, and
closing it does not depend on the request.
