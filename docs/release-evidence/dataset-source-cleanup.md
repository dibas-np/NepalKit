# Dataset source cleanup evidence

Date: 2026-10-03
Dataset: 2.0.1, unchanged 1975–2084 Bikram Sambat

The maintainer selected askbuddie as the sole current base, retained all five
historical correction rows, and retained NepalKit's own 2084 projection.
SOURCES.md records the copyright notice, the exact pin and the local decisions.
ADR-0014 supersedes the former sourcing policy without rewriting its history.

## One-time amitgaru comparison

The requested CSV was fetched at commit
`83bb3b2ea62359dd0a63cce68553bcebf94e1ebc`:
[calendar_bs.csv](https://github.com/amitgaru/nepali-datetime/blob/83bb3b2ea62359dd0a63cce68553bcebf94e1ebc/nepali_datetime/data/calendar_bs.csv).
It covers 1975–2100. All 110 NepalKit years were compared, 1,320 month values.
107 years matched exactly. Eight months differed, with identical year totals:

| Year | Month | NepalKit | CSV |
| --- | --- | --- | --- |
| 1989 | Kartik | 30 | 29 |
| 1989 | Mangsir | 29 | 30 |
| 1993 | Ashar | 31 | 32 |
| 1993 | Shrawan | 32 | 31 |
| 2084 | Jestha | 32 | 31 |
| 2084 | Ashar | 31 | 32 |
| 2084 | Shrawan | 32 | 31 |
| 2084 | Magh | 29 | 30 |

The CSV agrees with NepalKit on 2004, 2082 and 2083. It is a one-time comparison,
not a new base or verifier dependency. Agreement does not establish independent
provenance or official attestation.

## Dharan checks

The loaded converter function on the [Dharan e-BPS page](https://ebps.dharan.gov.np/Hom/Converter)
was exercised for ten inputs. Results and method are recorded in SOURCES.md.
The month starts establish 30/29 for Kartik/Mangsir 1989 and 31/32 for
Ashar/Shrawan 1993. These checks use 1932 and 1936 Gregorian, correcting the
inconsistent Gregorian years supplied earlier. No third-party code is vendored.

## Verification

| Check | Result |
| --- | --- |
| Dataset value comparison before/after cleanup | All 1,320 month lengths unchanged |
| Pinned askbuddie comparison, online and cached offline | Baseline holds: 104 exact years, 18 differing months |
| Candidate-year tool, retained 2084 projection | Reports exactly four differences, both rows total 365 days |
| Python dataset parser/gate suite | 27 tests passed |
| Core regression suite, including Dharan month-end fixtures | 93 tests in 19 suites passed |
| Strict SwiftLint | Zero violations in 119 files |
| Mac build through Xcode MCP | Passed, no errors or warnings reported |
| Generic watchOS device build through Xcode MCP | Passed, no errors or warnings reported |
| MIT notice in built Mac app, Watch app and embedded extension | Exact bytes match the retained upstream notice |
| Edited current-document local links and diff whitespace | Passed |

No calendar values or UI behavior changed. Dataset version remains 2.0.1.
The 2084 official-calendar and physical Watch acceptance obligations remain;
this source-policy cleanup does not claim to complete those tasks.
