# Provisional 2084 dataset update

Date: 2026-10-03
Dataset version: 2.0.1
Status: user-approved temporary projection, not official calendar attestation

## Decision and effects

The user explicitly requested adopting the revised 2084 projection temporarily
and reconciling it when the official calendar is published:

`[31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30]`

Jestha, Ashar, Shrawan and Magh change relative to dataset 2.0.0. The year still
has 365 days, Chaitra has 30, and Bhadra 22 maps to September 8, 2027. The
existing New Year anchor and exact supported interval remain unchanged. No
other year's row changes. Mac and Watch continue to use the same compiled table.

This candidate follows the user-reported birthday/Chaitra recurrence. It is
not an officially attested row, a verified astronomical-model result or a claim
that a four-year rule holds indefinitely. The data-version patch bump records
the changed projection without changing the public major-version symbol.

The projected fixtures have been separated from the published-calendar and
arbitration suites. The new tests assert the selected provisional contract,
not independent correctness. Existing historical anchored checks remain.

The source baseline now records 39 source/month comparison pairs over 25 unique
months. All non-2084 discrepancies are unchanged. The verifier no longer labels
every recorded discrepancy as an arbitration. See [source provenance](../../SOURCES.md)
for the user decision and superseded historical comparison.

## Settings About

The Mac Settings About form now includes a Dataset version row bound directly
to the injected dataset's version. It displays 2.0.1 for the current table. It
uses the existing Strings/form conventions rather than a copied version literal.

## Verification

| Check | Result |
| --- | --- |
| Core regression, including all provisional month starts and birthday mapping | 91 tests, 19 suites passed |
| Watch app/provider/model suite, SE 3 40 mm Simulator on watchOS 26.0 | 49 tests, 7 suites passed |
| Mac app regression harness | 167 tests, 24 suites passed |
| Dataset parser tests | 32 passed |
| Pinned sources | Regenerated from all four pinned sources, then offline baseline check passed |
| Strict lint | Zero violations in 118 files |
| Mac build through Xcode MCP | Passed |
| Release Watch app and embedded extension, generic watchOS device | Passed |
| Release app/extension signatures | Both verified with deep/strict codesign checks |
| Release fixture markers | Zero matches in both binaries using strings/nm |
| Diff whitespace | Passed |

The first Mac regression run identified old 2.0.0/version and Ashar-length
expectations; those were corrected to the new contract and the complete suite
then passed. The month-change test still exercises actual clamping by starting
with valid Jestha day 32 and switching to 31-day Ashar.

An attempted About preview was blocked by an unrelated open ComplicationPreviews
execution point under the Mac scheme. No rendered-preview success is claimed.
The About view compiles in the Mac build and regression harness. The original
Watch scheme and physical destination were restored after verification.

A subsequent native About-page check could not complete: the computer-use tool
timed out twice selecting the built Mac app by its exact path. Selection by
bundle identifier reported multiple installed/build copies and required an exact
path. No native visual-verification success is claimed; the Dataset version row
remains verified by source inspection, compilation and the regression harness.

## Refreshed signed artifact

The updated Release app is at:

`/tmp/nepalkit-watch-refresh-20261003/Build/Products/Release-watchos/NepalKitWatch Watch App.app`

It embeds `PlugIns/NepalKitComplications.appex`. This refresh supersedes the
previous Release executable fingerprints. The older Debug artifact is not
claimed refreshed for dataset 2.0.1. No physical installation was performed.

Build and test logs are under `/tmp/nepalkit-projected2084-*`. The sanitized
signature/fingerprint record is `/tmp/nepalkit-projected2084-signed-inspection.json`.

## Official-calendar follow-up

2084 remains provisional development/testing data. ADR-0001 is unchanged and
final feature acceptance remains blocked. When the official 2084 calendar is
available, compare all twelve months, cross-check New Year/month-start dates
against independent sources, record the evidence and update the shared table
and version as needed. This does not schedule automatic fetching or create
a Watch-specific table. Existing physical-validation obligations remain.

- NepalKitWatch Watch App.app executable SHA-256: `57f8f6a717510bf82347809abf6f87f9c059e3d1652cd3dee6941b1c008a3c76`
- NepalKitComplications.appex executable SHA-256: `8f0c039e1719d5e53682c2caf3de24acf6ea11bfa83d7e0038deb4891b393dec`
