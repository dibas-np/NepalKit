# Updating the calendar data

[SOURCES.md](../SOURCES.md) records the current month lengths, the askbuddie
pin, the licence notice, and the exceptions.

## Reconcile provisional 2084 first

2084 is a provisional year. Its row in `CalendarDataset.v2` is NepalKit's
365-day projection, not official data.

When the 2084 Nepali Patro is published:

1. Record its exact publication and approval details in SOURCES.md.
2. Compare all twelve month lengths, the New Year, and every month start
   against the current row. A community converter that matches the projection
   is not official approval.
3. Record any disagreement in SOURCES.md, with the evidence that resolved it.
4. Correct the 2084 row in `CalendarDataset.swift` and the fixtures in
   `Projected2084Tests` as needed.
5. When the comparison is complete, remove 2084 from
   `CalendarDataset.v2.provisionalYears`, which drops the app's provisional
   notes. Update `Projected2084Tests` and `ConverterModelTests` to match, and
   describe 2084 as confirmed in SOURCES.md. Do not describe it as confirmed
   before then.

## Add a supported year

1. Get the official month lengths and Gregorian boundaries for the year, with
   publication details that someone else can check. Review the source's reuse
   terms separately.
2. Run `python3 scripts/verify-candidate-year.py 2085` to see the pinned
   askbuddie base's row. To see the differences from a candidate row, pass the
   row as a second argument of twelve comma-separated month lengths. The script
   reports differences. It does not decide whether to adopt the row.
3. If you update the askbuddie pin, inspect that commit's table and licence,
   keep the complete notice, and compare every existing year before you change
   the pin.
4. Add only the reviewed year to `CalendarDataset.swift`. Keep every local
   correction explicit. Do not add a projection rule or automatic fetching.
5. Bump the dataset version. Keep the public major-version symbol, now
   `CalendarDataset.v2`, consistent with the new version. If the evidence no
   longer supports a year, narrow the supported range.
6. Read the new Gregorian bounds from `gregorianStart` and `gregorianEnd` on
   `CalendarDataset`. When the supported range changes, update the boundary
   fixtures, README.md, NepalKitCore/README.md, site/index.html, and
   SOURCES.md.
7. Regenerate the comparison baseline in the same change, then run the checks:

   ```sh
   python3 scripts/verify-data-sources.py --update-baseline
   python3 scripts/verify-data-sources.py --baseline scripts/data-sources-baseline.json
   python3 scripts/test_dataset_parsers.py
   swift test --package-path NepalKitCore
   ./scripts/swiftlint.sh lint --strict
   ```

8. Build the Mac and Watch apps. Check that the Ask Buddie licence resource is
   in the NepalKitCore bundle that each app ships.
9. Run the app and Watch tests that cover the date or range change. If the
   release includes signed builds or a test on a physical Watch, redo them. A
   source comparison does not replace them.
10. In the notes of any release that changes calendar data, say that the Watch app gets the correction only when
    someone rebuilds it from source. Sparkle updates the Mac app, but nothing
    updates a Watch install.

Ship the new year before the dataset's last supported day.

## List festivals and public holidays for a new year

Festivals and public holidays are separate from the month lengths. NepalKit
lists them one year at a time under the selection rule in SOURCES.md, and only
2083 is listed. From 1 Baisakh 2084 (14 April 2027) the month grid shows no
festival marks or red holidays. Instead it says "Festivals and holidays are
listed for 2083 BS only."

1. When the year's Panchanga is published, select its festivals and national
   days under the selection rule into `FestivalsYYYY.swift`, beside
   `Festivals2083.swift`. Pin the PDF's SHA-256 in SOURCES.md.
2. When the Ministry of Home Affairs publishes the year's gazette notice,
   transcribe it into `PublicHolidaysYYYY.swift` and pin it in SOURCES.md the
   same way. The 2083 notice was dated 2082-11-18 (2 March 2026). Add a
   festival-list entry for every day that the notice lists, as SOURCES.md
   describes for 2083.
3. Add the year to `FestivalCalendar.panchanga` and
   `PublicHolidayCalendar.gazette`. The grid's note then lists the new year
   with no other change.
4. Confirm every date and wording with a second, independent read of the page
   images, as for 2083. Then update the counts that
   `PublicHolidayCalendarTests` and `FestivalCalendarTests` check.

## Check the Samiti's notices each month from 1 January 2027

The Nepal Panchanga Nirnayak Samiti's determination of 2084 BS is expected
around Magh 2083 BS (January to February 2027), about three months before 2084
begins on 14 April 2027. Only that Panchanga can confirm the provisional 2084
row or let NepalKit add 2085. Once a month from 1 January 2027, until the
dataset reaches 2085:

1. Read the Samiti's publication notices on `npns.gov.np`. A notice missing in
   January is not evidence of a delay, because 2083 was confirmed in December
   2025.
2. If a Panchanga was published, read the Panchanga itself. Then follow
   [Reconcile provisional 2084 first](#reconcile-provisional-2084-first) and
   [Add a supported year](#add-a-supported-year).
3. Set `last_checked:` below to the date of the check, in the same commit as
   anything the check changed.

If February 2027 ends with no publication, do not wait. Plan for less time
between publication and release.

The `patro-reminder` job in `.github/workflows/data-sources.yml` runs on the
second day of each month and runs `scripts/check-patro-reminder.py`. From
1 January 2027 the job fails when `last_checked:` is `none`, more than 35 days
old, or more than one day in the future. It stops failing once the dataset
reaches 2085. The job checks that a person looked, not what the website says.

Do not rely on the job alone. GitHub disables a public repository's scheduled
workflows after 60 days without activity, so the job may never run. Keep a
reminder for January 2027 outside GitHub too.

last_checked: none
