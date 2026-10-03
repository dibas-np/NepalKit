# Calendar dataset update procedure

Current source policy: [ADR-0014](../adr/0014-calendar-base-and-local-exceptions.md).
Current values, pin, licence notice and exceptions: [SOURCES.md](../../SOURCES.md).

## Reconcile provisional 2084 first

The current 2084 row is NepalKit's own 365-day development/testing projection:

`[31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30]`

When the officially approved annual Nepali Patro is available, record its exact
publication and approval details. Compare all twelve month lengths and New
Year/month-start boundaries against the current row. A community converter's
matching projection does not establish official approval.

Record any disagreement and the evidence used to resolve it in SOURCES.md.
Correct the shared dataset, provisional fixtures and evidence status as needed.
Do not describe 2084 as attested until that comparison is complete.

## Consider a new supported year

1. Obtain the official year's month lengths and Gregorian boundaries with
   checkable publication details. Review the source's reuse terms separately.
2. Run `python3 scripts/verify-candidate-year.py 2085` to see what the pinned
   askbuddie base says. Supply a candidate row as twelve comma-separated values
   to report its differences. This script does not decide whether to adopt it.
3. If updating the askbuddie pin, inspect that commit's table and licence, retain
   the complete notice, and compare every existing year before changing the pin.
4. Add only the reviewed year to the shared table. Keep all local corrections
   explicit. No general projection rule or automatic fetching is introduced.
5. Version the dataset under ADR-0009. Keep the public major-version symbol
   consistent with the data contract; narrow the range when evidence requires
   it, as recorded historically in ADR-0010.
6. Derive the Gregorian bounds through CalendarDataset. Update boundary fixtures,
   README and SOURCES.md when the supported contract changes.
7. Regenerate the comparison baseline deliberately in the same change:

   ```sh
   python3 scripts/verify-data-sources.py --update-baseline
   python3 scripts/verify-data-sources.py --baseline scripts/data-sources-baseline.json
   python3 scripts/test_dataset_parsers.py
   swift test --package-path NepalKitCore
   ./scripts/swiftlint.sh lint --strict
   ```

Build the Mac and Watch consumers and verify the Ask Buddie licence resource is
present in the distributed shared core bundle. Run the app-layer and Watch tests
appropriate to the date or range change. Refresh signed artifacts and physical
Watch validation when those deliverables are in scope; a source comparison does
not substitute for them.

The current last supported Gregorian day is 2028-04-12. An extension should
ship before that boundary. This procedure does not set a publication date or
schedule automatic checks of a third-party website.
